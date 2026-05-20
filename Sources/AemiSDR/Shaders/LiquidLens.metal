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

struct LiquidLensUniforms {
    float2 center;
    float2 textureSize;
    float2 halfSize;
    float strength;
    float lensCurvature;     // pre-clamped to [0, 1] on CPU
    float cornerRadius;
    int falloffType;          // present in uniforms but the shader reads kFalloffType
    float falloffLength;
    float falloffIntensity;
    float chromaticAmount;
    int materialType;
    int overlayMode;          // 1 = transparent outside lens
    float refractiveIndexRed;
    float refractiveIndexGreen;
    float refractiveIndexBlue;
    // η = n_air / n_λ — feeds MSL `refract(I, N, η)` per channel.
    float airOverRed;         // 656.3 nm (Fraunhofer C)
    float airOverGreen;       // 546.1 nm (Fraunhofer e)
    float airOverBlue;        // 486.1 nm (Fraunhofer F)
    // Pixel-space width of the soft transition band across q.x = q.y.
    float diagonalBand;
    // Aspheric profile coefficients. Surface tilt = c·r·(1 + k2·u² + k4·u⁴)
    // where u = c·r. k2=k4=0 ⇒ pure spherical cap.
    float asphericK2;
    float asphericK4;
    // Extra wavelengths sampled in spectral integration mode.
    float spectralAirOver0;   // 440 nm (deep blue)
    float spectralAirOver1;   // 580 nm (yellow)
    // Scalar Snell deviation (radians) at the rim (sinθ = lensCurvature),
    // precomputed CPU-side. Used by the fast chromatic path when
    // `kHighFidelityRefraction` is false — per-fragment displacement is
    // `outwardDir * deviation * displacementScale`. Faster than the 3D
    // `refract()` form (3× ALU savings in chromatic mode) at the cost of
    // first-order accuracy only at large incidence angles.
    float deviationRed;
    float deviationGreen;
    float deviationBlue;
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

/// Unpolarized Fresnel transmission coefficient T = 1 − ½(Rs + Rp) at a
/// dielectric interface with `cosθ_i` and `cosθ_t` known. Returns 1 under
/// TIR (cosθ_t = 0), which gracefully degrades to "no attenuation" rather
/// than a hard zero.
inline float fresnelTransmission(float cosI, float cosT, float n1, float n2) {
    float rs_num = n1 * cosI - n2 * cosT;
    float rs_den = n1 * cosI + n2 * cosT;
    float rp_num = n1 * cosT - n2 * cosI;
    float rp_den = n1 * cosT + n2 * cosI;
    float Rs = (rs_num * rs_num) / max(rs_den * rs_den, 1e-6f);
    float Rp = (rp_num * rp_num) / max(rp_den * rp_den, 1e-6f);
    return clamp(1.0f - 0.5f * (Rs + Rp), 0.0f, 1.0f);
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
    float normalizedRadius = clamp(1.0f - (distFromEdge / minHalf), 0.0f, 1.0f);

    // Artistic falloff envelope on top of the physical angular profile.
    // With the per-fragment `refract()` model, displacement is already 0 at
    // the apex (sinθ=0) and max at the rim (sinθ=lensCurvature) — the
    // angular profile is now physical. The envelope here is a pure artistic
    // amplifier (default = quartic ease-in, concentrating effect at rim).
    const float kInteriorFloor = 0.05f;
    float effectIntensity = 0.0f;
    if (clampedFalloffLength > 0.0f && clampedFalloffIntensity > 0.0f) {
        float activeStart = 1.0f - clampedFalloffLength;
        float t = clamp((normalizedRadius - activeStart) / clampedFalloffLength, 0.0f, 1.0f);
        float edgePeak = applyFalloff(t);
        effectIntensity = mix(kInteriorFloor, 1.0f, edgePeak) * clampedFalloffIntensity;
    }

    if (effectIntensity < 0.0001f) {
        return isOverlay ? half4(0.0h) : sourceTexture.sample(texSampler, in.texCoord);
    }

    float2 outwardDir = computeSDFGradient(toPixel, halfSize, clampedCorner, uniforms.diagonalBand);

    // Build the spherical-cap surface normal at this fragment. sinθ = surface
    // tilt = r·c · (1 + aspheric corrections); cosθ = √(1 − sin²θ).
    float sinTheta = surfaceTilt(normalizedRadius,
                                 uniforms.lensCurvature,
                                 uniforms.asphericK2,
                                 uniforms.asphericK4);
    float cosTheta = sqrt(max(1.0f - sinTheta * sinTheta, 0.0f));

    float signFactor = (uniforms.strength >= 0.0f) ? 1.0f : -1.0f;
    float absStrength = abs(uniforms.strength);
    float displacementScale = minHalf * absStrength * effectIntensity * 2.0f;

    // Fresnel transmission (opt-in). At cosθ_i = cosTheta, cosθ_t derived from
    // green-channel refract. n1 = n_air; n2 = n_air / airOverGreen.
    half fresnelT = 1.0h;
    if (kEnableFresnel) {
        float sinT2 = uniforms.airOverGreen * uniforms.airOverGreen * sinTheta * sinTheta;
        float cosT  = sqrt(max(1.0f - sinT2, 0.0f));
        float n2    = 1.000293f / max(uniforms.airOverGreen, 1e-4f);
        fresnelT = half(fresnelTransmission(cosTheta, cosT, 1.000293f, n2));
    }

    // Non-chromatic specialization: single sample at the green displacement.
    if (!kEnableChromatic) {
        float2 dispG;
        if (kHighFidelityRefraction) {
            dispG = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOverGreen)
                    * displacementScale * signFactor;
        } else {
            // Fast scalar path: per-fragment displacement = outwardDir * (rim deviation).
            dispG = outwardDir * (uniforms.deviationGreen * displacementScale * signFactor);
        }
        float2 uv = (position + dispG) / uniforms.textureSize;
        half4 c = sourceTexture.sample(texSampler, uv);
        return half4(c.rgb * fresnelT, c.a);
    }

    // Spectral integration specialization: 5 wavelengths reconstructed into RGB.
    if (kEnableSpectral) {
        float2 disp[5];
        disp[0] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.spectralAirOver0); // 440
        disp[1] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOverBlue);      // 486
        disp[2] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOverGreen);     // 546
        disp[3] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.spectralAirOver1); // 580
        disp[4] = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOverRed);       // 656

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
        // Normalize by per-channel weight sum (each channel's weights ~sum to 1
        // but normalize defensively to handle any drift).
        half3 rgb = accum / max(wsum, half3(1e-3h));
        half a = sourceTexture.sample(texSampler, (position + dispMid * displacementScale * signFactor) * invSize).a;
        return half4(rgb * fresnelT, a);
    }

    // RGB-discrete chromatic specialization.
    float2 dispR2D, dispG2D, dispB2D;
    if (kHighFidelityRefraction) {
        // Per-fragment 3D refract — accurate at all incidence angles.
        float2 rDir = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOverRed);
        float2 gDir = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOverGreen);
        float2 bDir = refractDisplacement(outwardDir, sinTheta, cosTheta, uniforms.airOverBlue);
        dispR2D = rDir * displacementScale * signFactor;
        dispG2D = gDir * displacementScale * signFactor;
        dispB2D = bDir * displacementScale * signFactor;
    } else {
        // Fast scalar path: rim deviation × outwardDir. ~3× less ALU than the
        // refract() path; the chromatic mix below stretches the per-channel
        // displacement in the same direction as the original implementation.
        float dispGreenScalar = uniforms.deviationGreen * displacementScale * signFactor;
        float dispRedScalar   = uniforms.deviationRed   * displacementScale * signFactor;
        float dispBlueScalar  = uniforms.deviationBlue  * displacementScale * signFactor;
        dispG2D = outwardDir * dispGreenScalar;
        dispR2D = outwardDir * dispRedScalar;
        dispB2D = outwardDir * dispBlueScalar;
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
