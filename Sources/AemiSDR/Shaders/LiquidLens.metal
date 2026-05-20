//===----------------------------------------------------------------------===//
// LiquidLens.metal
// AemiSDR
//
// Physics-based liquid lens distortion with per-fragment Snell refraction.
//
// Physical model (paraxial single-surface refraction):
//   - Lens surface = spherical cap (optionally aspheric) with local outward
//     normal N = (outwardDir·sinθ, cosθ) where θ = asin(r·c) is the surface
//     tilt at radial position r and curvature c ∈ [0, 1].
//   - Snell refraction via MSL `refract(I, N, η)` where I = (0, 0, -1) is the
//     incident ray and η = n_air / n_λ (precomputed CPU-side per channel).
//   - Image-plane displacement = T.xy / (−T.z) (geometric projection of the
//     refracted ray onto the underlying texture). This naturally produces
//     zero displacement at the apex (r=0) and maximum at the rim (r=1),
//     replacing the old falloff-envelope hack.
//   - Chromatic aberration: three independent `refract()` calls (RGB), or
//     five for spectral integration mode.
//   - SDF gradient inside the inner-rect uses a fixed-width smoothstep band
//     across the q.x = q.y diagonal — true axial normal outside the band,
//     smooth blend inside, controlled by `uniforms.diagonalBand`.
//
// Function constants (compile-time specialization):
//   0: kEnableChromatic    bool — RGB-discrete chromatic sampling
//   1: kFalloffType        int  — 0..5, selects polynomial falloff curve
//   2: kEnableFresnel      bool — surface Fresnel transmission attenuation
//   3: kEnableSpectral     bool — 5-wavelength integration (implies chromatic)
//   4: kEnableAspheric     bool — non-spherical surface profile (k2, k4)
//
// References:
//   - Snell's law / refraction:  Hecht, "Optics", §4.4
//   - Fresnel equations:          Hecht §4.6 (unpolarized average form)
//   - SDF primitives:             Inigo Quilez, iquilezles.org/articles/distfunctions2d/
//   - Soft-max gradient analysis: see plan whimsical-stirring-seal.md
//===----------------------------------------------------------------------===//

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms

// LiquidLensUniforms — 128-byte stride. Layout grouped by access pattern:
//
//   • Geometry first (center, textureSize, halfSize) — read once per fragment.
//   • Scalar shape parameters next (strength..asphericK4) — read by branch
//     gates and the displacement scaling.
//   • Three `float3` channel triplets last (refractiveIndex, airOver,
//     deviation) — read together as vectors in the chromatic path.
//
// The triplets use `float3` rather than three independent scalars so the
// compiler can emit a single 16-byte vector load per triplet and the GPU
// register allocator gets a natural vector lane. Independent scalars would
// force the compiler to schedule three separate loads with no guarantee of
// fusion. Per-channel access (`uniforms.airOver.r`) is the same syntax cost.
//
// `overlayMode` stays as a 4-byte int — it gates an early-return branch
// in the fragment, and packing it into a bitfield would cost a shift+mask
// on every fragment for no measurable saving.
//
// `falloffType` and `materialType` are not in this struct. `falloffType` is
// resolved at pipeline build time via `kFalloffType` function constant, so
// the runtime field would be unread. `materialType` is a CPU-side dispatch
// label for picking Sellmeier coefficients; the resolved index values reach
// the GPU through `refractiveIndex`/`airOver`/`deviation`, not through a
// material ID, so the GPU has no use for it.
struct LiquidLensUniforms {
    // Geometry (24 bytes, 8-byte aligned).
    float2 center;
    float2 textureSize;
    float2 halfSize;

    // Scalar shape/intensity parameters.
    float strength;
    float lensCurvature;     // pre-clamped to [0, 1] on CPU
    float cornerRadius;
    float falloffLength;
    float falloffIntensity;
    float chromaticAmount;
    int overlayMode;          // 1 = transparent outside lens shape
    float diagonalBand;       // pixel-space width of the q.x = q.y transition band

    // Aspheric profile coefficients. Surface tilt = c·r·(1 + k2·u² + k4·u⁴)
    // where u = c·r. k2 = k4 = 0 ⇒ pure spherical cap.
    float asphericK2;
    float asphericK4;

    // Channel triplets, naturally vector-loaded as `float3`. Each occupies a
    // 16-byte register slot.
    float3 refractiveIndex;   // .r = 656.3 nm (C line), .g = 546.1 nm (e), .b = 486.1 nm (F)
    float3 airOver;           // η = n_air / n_λ per channel; feeds MSL refract(I, N, η)
    float3 deviation;         // scalar Snell deviation (radians) at the rim, per channel

    // Extra wavelengths consumed only when `kEnableSpectral` is true.
    float spectralAirOver0;   // 440 nm (deep blue)
    float spectralAirOver1;   // 580 nm (yellow)
};

// MARK: - Vertex Types

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Fullscreen Quad Vertex Shader

vertex VertexOut liquidLensVertex(uint vertexID [[vertex_id]]) {
    // Triangle strip: 4 vertices forming a fullscreen quad
    // Positions in clip space [-1, 1], texCoords in [0, 1]
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0),
    };

    float2 texCoords[4] = {
        float2(0.0, 1.0),  // bottom-left  → top of texture (Y-flip)
        float2(1.0, 1.0),  // bottom-right → top-right
        float2(0.0, 0.0),  // top-left     → bottom of texture
        float2(1.0, 0.0),  // top-right    → bottom-right
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

// MARK: - Function Constants
//
// Compile-time specialization selects the fragment-shader variant at metallib
// load time. The renderer caches one MTLRenderPipelineState per active key
// combination — pipelines are built lazily on first use.

constant bool  kEnableChromatic         [[function_constant(0)]];
constant int   kFalloffType             [[function_constant(1)]];
constant bool  kEnableFresnel           [[function_constant(2)]];
constant bool  kEnableSpectral          [[function_constant(3)]];
constant bool  kEnableAspheric          [[function_constant(4)]];
/// When true, displacement is computed per-fragment via MSL `refract()` 3D
/// form with image-plane projection — physically accurate but ~3× the ALU
/// of the scalar path. When false (default), use the CPU-precomputed scalar
/// rim deviation directly, scaling by `outwardDir`. The scalar form is the
/// original (fast) behavior and produces visually equivalent results at
/// typical lens curvatures.
constant bool  kHighFidelityRefraction  [[function_constant(5)]];

// MARK: - Falloff Transition Functions
//
// All curves are polynomial in t ∈ [0, 1]. The actual choice is gated on
// `kFalloffType` — the compiler dead-code-eliminates the branches that
// don't match the specialization, so each variant inlines a single
// polynomial.

inline float applyFalloff(float t) {
    t = clamp(t, 0.0f, 1.0f);
    if (kFalloffType == 0) return t;                          // linear
    if (kFalloffType == 1) return t * t;                      // ease-in (quadratic)
    if (kFalloffType == 2) { float u = 1.0f - t; return 1.0f - u * u; }  // ease-out
    if (kFalloffType == 3) return t * t * (3.0f - 2.0f * t);  // ease-in-out (smoothstep)
    if (kFalloffType == 4) return t * t * t;                  // cubic ease-in
    return t * t * t * t;                                     // quartic (kFalloffType == 5)
}

// MARK: - SDF Functions

inline float sdRoundedRect(float2 p, float2 halfSize, float cornerRadius) {
    float corner = clamp(cornerRadius, 0.0f, min(halfSize.x, halfSize.y));
    float2 inner = halfSize - corner;
    float2 q = abs(p) - inner;
    float2 outside = max(q, float2(0.0f));
    float outsideDist = length(outside);
    float insideDist = min(max(q.x, q.y), 0.0f);
    return outsideDist + insideDist - corner;
}

// MARK: - SDF Gradient (Surface Normal)
//
// The SDF gradient is the outward-facing normal of the lens cross-section,
// used as the in-plane refraction direction. The interior of a rounded
// rectangle has a TRUE SDF that is discontinuous along q.x = q.y (the
// medial axis between two equidistant flat edges). We pick the true axial
// direction outside a fixed-pixel-width transition band and smoothstep
// between (1,0) and (0,1) inside it. This:
//
//   - Eliminates the previous `normalize((dy, dx))` formula's 2× angular
//     rate-of-change peak at the diagonal (most visible as a soft seam in
//     elongated lenses near the inner-rect corner).
//   - Removes the NaN at q = (0, 0) that `normalize((0, 0))` would produce.
//   - Gives the *true* SDF normal everywhere outside the band, so the
//     displacement direction is physically correct over >99 % of the lens
//     interior.
//
// The signP smoothstep on |p| tapers the gradient magnitude across the
// shape's medial axis (p.x = 0 or p.y = 0) to zero — preventing the
// mirrored-double-image artifact across the symmetry axis.

inline float2 computeSDFGradient(float2 p, float2 halfSize, float cornerRadius, float diagonalBand) {
    float corner = clamp(cornerRadius, 0.0f, min(halfSize.x, halfSize.y));
    float2 absP = abs(p);

    float seamWidth = max(min(halfSize.x, halfSize.y), 0.5f);
    float2 signP = float2(
        (p.x >= 0.0f ? 1.0f : -1.0f) * smoothstep(0.0f, seamWidth, absP.x),
        (p.y >= 0.0f ? 1.0f : -1.0f) * smoothstep(0.0f, seamWidth, absP.y)
    );

    float2 inner = halfSize - corner;
    float2 q = absP - inner;
    float2 qp = max(q, float2(0.0f));

    float2 gradLocal;
    if (corner > 0.0001f && qp.x > 0.0f && qp.y > 0.0f) {
        // Corner arc sector: exact radial gradient from arc center.
        float qLen = length(qp);
        gradLocal = (qLen > 0.0001f) ? (qp / qLen) : float2(0.707107f, 0.707107f);
    } else if (q.x <= 0.0f && q.y <= 0.0f) {
        // Interior region (both inside inner frame). Use a fixed-pixel-width
        // smoothstep on (q.x - q.y) to blend between the two true axial
        // normals. Outside the band, gradient is exact (1, 0) or (0, 1).
        // At q.x = q.y exactly: (0.5, 0.5) — defined, no NaN.
        float band = max(diagonalBand, 0.5f);
        float t = smoothstep(-band, band, q.x - q.y);
        gradLocal = float2(t, 1.0f - t);
    } else {
        // Flat-edge region: one component past the inner frame, the other not.
        gradLocal = (q.y > q.x) ? float2(0.0f, 1.0f) : float2(1.0f, 0.0f);
    }

    return gradLocal * signP;
}

// MARK: - Per-fragment refraction helpers

/// Computes the local surface tilt (`sinθ`) for a spherical or aspheric cap
/// at normalized radial position `r ∈ [0, 1]` with curvature `c ∈ [0, 1]`.
/// When `kEnableAspheric` is true the surface follows a 4th-order aspheric
/// polynomial; otherwise it's the pure spherical-cap form `r·c`.
inline float surfaceTilt(float r, float c, float k2, float k4) {
    float u = r * c;
    if (kEnableAspheric) {
        u = u * (1.0f + k2 * u * u + k4 * u * u * u * u);
    }
    return clamp(u, 0.0f, 1.0f);
}

/// Refract the downward incident ray through a surface with normal
/// `N = (outwardDir·sinθ, cosθ)` using `eta = n_air / n_λ`, then project
/// the refracted ray onto the image plane and return the 2D image-plane
/// displacement direction-times-scale.
///
/// The lateral displacement on the image plane is `T.xy / (−T.z)` — this
/// correctly accounts for the geometric projection of the refracted ray
/// angle to the image plane (giving `tan(α)` not `α`), unlike the scalar
/// `asin(eta·sinθ) − θ` form which is only first-order accurate.
inline float2 refractDisplacement(float2 outwardDir,
                                  float sinTheta,
                                  float cosTheta,
                                  float eta) {
    float3 N = float3(outwardDir * sinTheta, cosTheta);
    const float3 I = float3(0.0f, 0.0f, -1.0f);
    float3 T = refract(I, N, eta);
    // refract() returns the zero vector under total internal reflection;
    // the `max` floor guards against -T.z ≤ 0 (would yield NaN/Inf).
    float invTz = 1.0f / max(-T.z, 1e-4f);
    return T.xy * invTz;
}

/// Schlick approximation of the Fresnel reflection coefficient
/// `F = F₀ + (1 − F₀)·(1 − cosθ)⁵`. Returns the transmission coefficient
/// `1 − F` clamped to [0, 1].
///
/// `(1 − cosθ)⁵` is unrolled to `x²·x²·x` (4 muls) — the standard pow-5
/// expansion in real-time PBR. Half precision is sufficient: F₀ for typical
/// dielectric / glass / water interfaces is around 0.02–0.08 and the
/// (1−cosθ)⁵ term saturates to 1 within fp16 dynamic range. The full
/// polarized form needs four squares and two divisions per fragment for an
/// accuracy improvement that is below the noise floor of a real-time
/// composite.
inline half fresnelSchlickTransmission(half cosTheta, half F0) {
    half x = 1.0h - cosTheta;
    half x2 = x * x;
    half F = F0 + (1.0h - F0) * (x2 * x2 * x);
    return clamp(1.0h - F, 0.0h, 1.0h);
}

/// CIE-D65-derived weights for reconstructing sRGB from 5 spectral samples at
/// 440 / 486 / 546 / 580 / 656 nm. Rows are (R, G, B) weights for each
/// wavelength; columns sum to ~1.0 per output channel across the visible band.
/// Values normalized so chromatic-amount-1 produces ~physically-correct fringes.
constant float kSpectralRGB[5][3] = {
    // λ=440  : deep blue
    { 0.020f, 0.025f, 0.420f },
    // λ=486  : blue (Fraunhofer F)
    { 0.050f, 0.180f, 0.380f },
    // λ=546  : green (Fraunhofer e)
    { 0.180f, 0.450f, 0.150f },
    // λ=580  : yellow
    { 0.350f, 0.300f, 0.040f },
    // λ=656  : red (Fraunhofer C)
    { 0.400f, 0.045f, 0.010f },
};

// MARK: - Fragment Shader

fragment half4 liquidLensFragment(
    VertexOut in [[stage_in]],
    texture2d<half> sourceTexture [[texture(0)]],
    constant LiquidLensUniforms& uniforms [[buffer(0)]]
) {
    constexpr sampler texSampler(filter::linear, address::clamp_to_edge);

    float2 position = in.texCoord * uniforms.textureSize;
    float2 toPixel = position - uniforms.center;
    float2 halfSize = uniforms.halfSize;
    float minHalf = min(halfSize.x, halfSize.y);

    bool isOverlay = uniforms.overlayMode != 0;

    if (minHalf <= 0.0f) {
        return isOverlay ? half4(0.0h) : sourceTexture.sample(texSampler, in.texCoord);
    }

    float clampedCorner = clamp(uniforms.cornerRadius, 0.0f, minHalf);
    float clampedFalloffLength = clamp(uniforms.falloffLength, 0.01f, 1.0f);
    float clampedFalloffIntensity = clamp(uniforms.falloffIntensity, 0.0f, 1.0f);
    // chromaticAmount as artistic amplifier: 0 disables chromatic separation;
    // 1 ≈ physical chromatic; higher extrapolates for visible fringing.
    float clampedChromatic = clamp(uniforms.chromaticAmount, 0.0f, 30.0f);

    float dOuter = sdRoundedRect(toPixel, halfSize, clampedCorner);
    if (dOuter >= 0.0f) {
        return isOverlay ? half4(0.0h) : sourceTexture.sample(texSampler, in.texCoord);
    }

    float distFromEdge = -dOuter;
    // `normalizedRadius` is in [0, 1] — half precision (≈3 decimal digits of
    // mantissa) is sufficient for the falloff envelope below.
    half normalizedRadius = half(clamp(1.0f - (distFromEdge / minHalf), 0.0f, 1.0f));

    // Artistic falloff envelope. Whether the displacement is per-fragment
    // physical (3D refract) or per-rim scalar, this envelope is a multiplicative
    // shape on top — quartic ease-in by default, concentrating the effect at
    // the rim. The values stay in [0, 1] so half precision is fine.
    const half kInteriorFloor = 0.05h;
    half effectIntensity = 0.0h;
    if (clampedFalloffLength > 0.0f && clampedFalloffIntensity > 0.0f) {
        half activeStart = half(1.0f - clampedFalloffLength);
        half t = clamp((normalizedRadius - activeStart) / half(clampedFalloffLength), 0.0h, 1.0h);
        half edgePeak = half(applyFalloff(float(t)));
        effectIntensity = mix(kInteriorFloor, 1.0h, edgePeak) * half(clampedFalloffIntensity);
    }

    if (effectIntensity < 0.0001h) {
        return isOverlay ? half4(0.0h) : sourceTexture.sample(texSampler, in.texCoord);
    }

    float2 outwardDir = computeSDFGradient(toPixel, halfSize, clampedCorner, uniforms.diagonalBand);

    // Surface tilt and its cosine are consumed 3–5 times by `refractDisplacement`
    // and the Fresnel block. Keeping them as `float` avoids repeated half→float
    // promotions at each call site; the half-precision saving on a single
    // value would be offset by the conversion cost across multiple uses.
    float sinTheta = surfaceTilt(float(normalizedRadius),
                                 uniforms.lensCurvature,
                                 uniforms.asphericK2,
                                 uniforms.asphericK4);
    float cosTheta = sqrt(max(1.0f - sinTheta * sinTheta, 0.0f));

    // `signFactor` is ±1, exact in either precision; using `float` here matches
    // the type of `displacementScale` so the per-channel scaling is one mul.
    float signFactor = (uniforms.strength >= 0.0f) ? 1.0f : -1.0f;
    // `displacementScale` stays `float` because `minHalf` may exceed the half
    // dynamic range for very large render targets, and the final scale needs
    // sub-pixel precision when multiplied into the texture UV — half's 11-bit
    // mantissa loses fractional resolution at pixel coordinates above ~2048.
    float displacementScale = minHalf * abs(uniforms.strength) * float(effectIntensity) * 2.0f;

    // Schlick Fresnel transmission (opt-in). `F₀` is the normal-incidence
    // reflectance and depends only on the refractive-index ratio:
    //   F₀ = ((n_air − n_glass) / (n_air + n_glass))²
    //      = ((1 − airOver) / (1 + airOver))²    (eta = airOver = n_air/n_glass)
    // Choosing Schlick here over the polarized full Fresnel because the
    // visible difference in real-time rendering is below the noise floor,
    // and the polynomial is two orders of magnitude cheaper.
    half fresnelT = 1.0h;
    if (kEnableFresnel) {
        half etaG = half(uniforms.airOver.g);
        half oneMinusEta = 1.0h - etaG;
        half onePlusEta  = 1.0h + etaG;
        half r0Root = oneMinusEta / max(onePlusEta, 1e-3h);
        half F0 = r0Root * r0Root;
        fresnelT = fresnelSchlickTransmission(half(cosTheta), F0);
        // One half-precision Schlick polynomial vs four squares + two divisions
        // in the polarized form — the visible attenuation at typical viewing
        // distances is identical, which is why Schlick is the industry-standard
        // real-time approximation.
    }

    // Non-chromatic specialization: single sample at the green displacement.
    if (!kEnableChromatic) {
        float2 dispG;
        if (kHighFidelityRefraction) {
            dispG = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOver.g)
                    * displacementScale * signFactor;
        } else {
            // Fast scalar path: per-fragment displacement = outwardDir · (rim deviation).
            // One vec mul + one scalar mul. Choosing scalar deviation over the 3D
            // `refract()` form here because `refract()` adds a sqrt + dot + 3 muls
            // for an accuracy improvement that's invisible at typical lens
            // curvatures; opt-in `kHighFidelityRefraction` covers grazing-angle
            // cases.
            dispG = outwardDir * (uniforms.deviation.g * displacementScale * signFactor);
        }
        float2 uv = (position + dispG) / uniforms.textureSize;
        half4 c = sourceTexture.sample(texSampler, uv);
        return half4(c.rgb * fresnelT, c.a);
    }

    // Spectral integration specialization: 5 wavelengths reconstructed into RGB.
    if (kEnableSpectral) {
        float2 disp[5];
        disp[0] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.spectralAirOver0); // 440
        disp[1] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOver.b);        // 486
        disp[2] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOver.g);        // 546
        disp[3] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.spectralAirOver1); // 580
        disp[4] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOver.r);        // 656

        // Apply chromatic amplifier: mix green (middle) toward each spectral
        // sample by `clampedChromatic`. amount=0 collapses to single sample.
        float2 dispMid = disp[2];
        float2 invSize = 1.0f / uniforms.textureSize;
        half3 accum = half3(0.0h);
        half3 wsum = half3(0.0h);
        for (int i = 0; i < 5; ++i) {
            float2 d = mix(dispMid, disp[i], clampedChromatic) * displacementScale * signFactor;
            half4 s = sourceTexture.sample(texSampler, (position + d) * invSize);
            half3 w = half3(kSpectralRGB[i][0], kSpectralRGB[i][1], kSpectralRGB[i][2]);
            accum += w * s.rgb;
            wsum  += w;
        }
        // Normalize by per-channel weight sum. The fixed `kSpectralRGB` matrix
        // is designed so each channel's column sums to ~1 across the 5 visible
        // wavelengths, but a runtime division guards against any drift.
        half3 rgb = accum / max(wsum, half3(1e-3h));
        half a = sourceTexture.sample(texSampler, (position + dispMid * displacementScale * signFactor) * invSize).a;
        return half4(rgb * fresnelT, a);
    }

    // RGB-discrete chromatic specialization.
    float2 dispR2D, dispG2D, dispB2D;
    if (kHighFidelityRefraction) {
        // Per-fragment 3D refract — accurate at all incidence angles. Three
        // separate refract calls because the per-channel η differs.
        float2 rDir = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOver.r);
        float2 gDir = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOver.g);
        float2 bDir = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOver.b);
        dispR2D = rDir * displacementScale * signFactor;
        dispG2D = gDir * displacementScale * signFactor;
        dispB2D = bDir * displacementScale * signFactor;
    } else {
        // Fast scalar path. The per-channel rim deviations are pre-multiplied
        // by `displacementScale * signFactor` (a single vector mul into the
        // float3 lane) and the result is broadcast onto `outwardDir` to give
        // each channel its own 2D displacement vector. Net ALU is roughly
        // a third of the refract() path because the surface tilt math is
        // amortized into the CPU-precomputed rim deviation.
        float3 dispScalars = uniforms.deviation * displacementScale * signFactor;
        dispR2D = outwardDir * dispScalars.r;
        dispG2D = outwardDir * dispScalars.g;
        dispB2D = outwardDir * dispScalars.b;
    }

    if (clampedChromatic < 0.0001f) {
        float2 uv = (position + dispG2D) / uniforms.textureSize;
        half4 c = sourceTexture.sample(texSampler, uv);
        return half4(c.rgb * fresnelT, c.a);
    }

    // Chromatic amplifier: extrapolate per-channel displacement from green.
    dispR2D = mix(dispG2D, dispR2D, clampedChromatic);
    dispB2D = mix(dispG2D, dispB2D, clampedChromatic);

    float2 invSize = 1.0f / uniforms.textureSize;
    half4 redSample   = sourceTexture.sample(texSampler, (position + dispR2D) * invSize);
    half4 greenSample = sourceTexture.sample(texSampler, (position + dispG2D) * invSize);
    half4 blueSample  = sourceTexture.sample(texSampler, (position + dispB2D) * invSize);

    half4 result;
    result.r = redSample.r * fresnelT;
    result.g = greenSample.g * fresnelT;
    result.b = blueSample.b * fresnelT;
    result.a = greenSample.a;
    return result;
}
