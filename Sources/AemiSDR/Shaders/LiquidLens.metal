//===----------------------------------------------------------------------===//
// LiquidLens.metal
// AemiSDR
//
// Physics-based liquid lens distortion with real chromatic aberration.
// Uses Sellmeier dispersion equations for wavelength-dependent refraction.
//
// Ported from LiquidOK's stitchable SwiftUI shader to a standard Metal
// vertex/fragment pipeline for CAMetalLayer rendering.
//
// Physical Model:
//   - Lens surface modeled as spherical cap with configurable curvature
//   - Chromatic aberration from wavelength-dependent refractive index
//   - Snell's law applied at each point based on local surface normal
//   - Falloff controls edge fade from full effect to transparent
//
// Dispersion Reference: Sellmeier equation (1871)
//   n²(λ) = 1 + Σ(Bᵢ·λ²)/(λ² - Cᵢ)
//
// SDF Reference: Inigo Quilez - iquilezles.org/articles/distfunctions2d/
//===----------------------------------------------------------------------===//

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms

struct LiquidLensUniforms {
    float2 center;
    float2 textureSize;
    float2 halfSize;
    float strength;
    float lensCurvature;
    float cornerRadius;
    int falloffType;
    float falloffLength;
    float falloffIntensity;
    float chromaticAmount;
    int materialType;
    int overlayMode;  // 1 = transparent outside lens (for overlay on live content)
    float refractiveIndexRed;
    float refractiveIndexGreen;
    float refractiveIndexBlue;
    // Snell deviations precomputed CPU-side (radians). These depend only on
    // lensCurvature and refractive indices — all uniform across the lens — so
    // computing them per fragment wasted 6 transcendentals (sin/asin) per
    // chromatic pixel.
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

// MARK: - Physical Constants
//
// Refractive index of air (`1.000293`) and Sellmeier coefficients are no longer
// referenced from the fragment shader — the Snell deviations they would feed are
// precomputed CPU-side in `LiquidLensConfiguration.toUniforms`. The CPU
// equivalents live in `LiquidLensConfiguration.swift`.

// MARK: - Sellmeier Coefficients

// BK7 Crown Glass - low dispersion, common optical glass
constant float kBK7_B1 = 1.03961212;
constant float kBK7_B2 = 0.231792344;
constant float kBK7_B3 = 1.01046945;
constant float kBK7_C1 = 0.00600069867;
constant float kBK7_C2 = 0.0200179144;
constant float kBK7_C3 = 103.560653;

// SF11 Flint Glass - high dispersion, used in prisms
constant float kSF11_B1 = 1.73759695;
constant float kSF11_B2 = 0.313747346;
constant float kSF11_B3 = 1.89878101;
constant float kSF11_C1 = 0.013188707;
constant float kSF11_C2 = 0.0623068142;
constant float kSF11_C3 = 155.23629;

// Water at 20°C
constant float kWater_B1 = 0.5684027565;
constant float kWater_B2 = 0.1726177391;
constant float kWater_B3 = 0.02086189578;
constant float kWater_C1 = 0.005101829712;
constant float kWater_C2 = 0.01821153936;
constant float kWater_C3 = 0.02620722293;

// PMMA (Acrylic/Plexiglass)
constant float kPMMA_B1 = 0.99654;
constant float kPMMA_B2 = 0.18964;
constant float kPMMA_B3 = 0.00411;
constant float kPMMA_C1 = 0.00787;
constant float kPMMA_C2 = 0.02191;
constant float kPMMA_C3 = 3.85727;

// Diamond
constant float kDiamond_B1 = 0.3306;
constant float kDiamond_B2 = 4.3356;
constant float kDiamond_B3 = 0.0;
constant float kDiamond_C1 = 0.0;
constant float kDiamond_C2 = 0.1060;
constant float kDiamond_C3 = 0.0;

// MARK: - Sellmeier Dispersion

inline float sellmeierIndex(float wavelength,
                            float B1, float B2, float B3,
                            float C1, float C2, float C3) {
    float l2 = wavelength * wavelength;
    float n2 = 1.0f
        + (B1 * l2) / (l2 - C1)
        + (B2 * l2) / (l2 - C2)
        + (B3 * l2) / (l2 - C3);
    return sqrt(max(n2, 1.0f));
}

inline float getRefractiveIndex(float wavelength, int materialType) {
    switch (materialType) {
        case 0: return sellmeierIndex(wavelength, kBK7_B1, kBK7_B2, kBK7_B3, kBK7_C1, kBK7_C2, kBK7_C3);
        case 1: return sellmeierIndex(wavelength, kSF11_B1, kSF11_B2, kSF11_B3, kSF11_C1, kSF11_C2, kSF11_C3);
        case 2: return sellmeierIndex(wavelength, kWater_B1, kWater_B2, kWater_B3, kWater_C1, kWater_C2, kWater_C3);
        case 3: return sellmeierIndex(wavelength, kPMMA_B1, kPMMA_B2, kPMMA_B3, kPMMA_C1, kPMMA_C2, kPMMA_C3);
        case 4: return sellmeierIndex(wavelength, kDiamond_B1, kDiamond_B2, kDiamond_B3, kDiamond_C1, kDiamond_C2, kDiamond_C3);
        default: return sellmeierIndex(wavelength, kBK7_B1, kBK7_B2, kBK7_B3, kBK7_C1, kBK7_C2, kBK7_C3);
    }
}

// MARK: - Falloff Transition Functions

inline float falloffLinear(float t) {
    return t;
}

inline float falloffEaseIn(float t) {
    return t * t;
}

inline float falloffEaseOut(float t) {
    float u = 1.0f - t;
    return 1.0f - u * u;
}

inline float falloffEaseInOut(float t) {
    return t * t * (3.0f - 2.0f * t);
}

inline float falloffCubic(float t) {
    return t * t * t;
}

inline float falloffExponential(float t) {
    return t * t * t * t;
}

inline float applyFalloff(float t, int falloffType) {
    t = clamp(t, 0.0f, 1.0f);
    switch (falloffType) {
        case 0: return falloffLinear(t);
        case 1: return falloffEaseIn(t);
        case 2: return falloffEaseOut(t);
        case 3: return falloffEaseInOut(t);
        case 4: return falloffCubic(t);
        case 5: return falloffExponential(t);
        default: return falloffLinear(t);
    }
}

// MARK: - Lens Surface Geometry

// `sphericalSurfaceAngle` and `snellDeviation` are no longer called from the
// fragment shader (since the Snell deviations are precomputed CPU-side in
// `LiquidLensConfiguration.toUniforms` to save six per-fragment transcendentals
// in chromatic mode). Kept here as documentation of the CPU equivalent — the
// Metal compiler dead-code-eliminates them from the metallib.

inline float sphericalSurfaceAngle(float normalizedRadius, float curvature) {
    float r = clamp(normalizedRadius, 0.0f, 1.0f);
    float c = clamp(curvature, 0.0f, 1.0f);
    float sinTheta = r * c;
    return asin(clamp(sinTheta, 0.0f, 1.0f));
}

inline float snellDeviation(float incidentAngle, float n1, float n2) {
    float sinIncident = sin(incidentAngle);
    float sinRefracted = (n1 / n2) * sinIncident;

    if (abs(sinRefracted) >= 1.0f) {
        return 0.0f;  // Total internal reflection
    }

    float refractedAngle = asin(sinRefracted);
    return refractedAngle - incidentAngle;
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
// The SDF gradient is the physically correct refraction direction for a glass
// pane whose cross-section follows the SDF contour. At flat edges it points
// perpendicular to the edge; at rounded corners it points radially from the
// arc center. This is used directly as the displacement direction — no hybrid
// blending needed.

inline float2 computeSDFGradient(float2 p, float2 halfSize, float cornerRadius) {
    float corner = clamp(cornerRadius, 0.0f, min(halfSize.x, halfSize.y));
    float2 absP = abs(p);

    // Smoothed sign: tapers each gradient component from zero at the
    // shape's medial axis (p.x = 0 or p.y = 0) up to ±1 at the closest
    // boundary along that axis. The transition spans the SHORT dimension
    // of the shape so wide capsules / tall pills get a wide soft band
    // around the medial axis (where the gradient direction is
    // mathematically ambiguous) while square / circular lenses see only
    // the natural center-to-edge ramp.
    //
    // Without this, a hard `sign()` produces an instantaneous flip across
    // the medial axis. For elongated shapes that materialises as either a
    // visible seam (when intensity is non-zero at the axis) or a mirrored
    // double image (when the upper and lower halves refract at full
    // magnitude in opposite directions). Tapering the gradient magnitude
    // across the short dimension eliminates both: at the medial axis the
    // displacement is exactly zero, and neighbouring pixels smoothly
    // transition into the rim's refraction.
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
        // Interior region (both inside inner frame).
        // The true SDF gradient is discontinuous along q.x = q.y (the medial
        // axis between two equidistant edges). Smooth the transition with a
        // scaled smoothstep so the displacement field has no visible seam.
        float diff = q.x - q.y;
        float sharpness = 1.0f / max(corner, 1.0f);
        float blend = clamp(0.5f + diff * sharpness, 0.0f, 1.0f);
        blend = blend * blend * (3.0f - 2.0f * blend);
        gradLocal = normalize(float2(blend, 1.0f - blend));
    } else {
        // Flat-edge region: one component past the inner frame, the other not.
        // Direction is unambiguously toward the closer boundary.
        gradLocal = (q.y > q.x) ? float2(0.0f, 1.0f) : float2(1.0f, 0.0f);
    }

    return gradLocal * signP;
}

// MARK: - Fragment Shader

constant bool kEnableChromatic [[function_constant(0)]];

fragment half4 liquidLensFragment(
    VertexOut in [[stage_in]],
    texture2d<half> sourceTexture [[texture(0)]],
    constant LiquidLensUniforms& uniforms [[buffer(0)]]
) {
    constexpr sampler texSampler(filter::linear, address::clamp_to_edge);

    // Convert normalized texCoord to pixel coordinates for physics calculations
    float2 position = in.texCoord * uniforms.textureSize;
    float2 toPixel = position - uniforms.center;
    float2 halfSize = uniforms.halfSize;
    float minHalf = min(halfSize.x, halfSize.y);

    bool isOverlay = uniforms.overlayMode != 0;

    // Early exit for zero-size lens
    if (minHalf <= 0.0f) {
        return isOverlay ? half4(0.0h) : sourceTexture.sample(texSampler, in.texCoord);
    }

    // Clamp parameters. `lensCurvature` is no longer referenced in-shader
    // (the Snell deviations it would drive are precomputed CPU-side and read
    // out of `uniforms.deviation{Red,Green,Blue}`), so no clamped form is
    // needed here.
    float clampedCorner = clamp(uniforms.cornerRadius, 0.0f, minHalf);
    float clampedFalloffLength = clamp(uniforms.falloffLength, 0.01f, 1.0f);
    float clampedFalloffIntensity = clamp(uniforms.falloffIntensity, 0.0f, 1.0f);
    // chromaticAmount is an artistic amplifier multiplied into the
    // `mix(green, channel, t)` extrapolation: 0 disables chromatic
    // separation; ~1–4 maps to the subtle fringing seen on iOS 26 Liquid
    // Glass; higher values extrapolate beyond physical correctness for
    // stylistic emphasis, with visible color bands above ~10.
    float clampedChromatic = clamp(uniforms.chromaticAmount, 0.0f, 30.0f);
    int falloffCurve = uniforms.falloffType;

    // Calculate distance to outer boundary
    float dOuter = sdRoundedRect(toPixel, halfSize, clampedCorner);

    // Outside the lens shape
    if (dOuter >= 0.0f) {
        return isOverlay ? half4(0.0h) : sourceTexture.sample(texSampler, in.texCoord);
    }

    // Calculate normalized radial position (0 at center, 1 at edge)
    float distFromEdge = -dOuter;
    float normalizedRadius = 1.0f - (distFromEdge / minHalf);
    normalizedRadius = clamp(normalizedRadius, 0.0f, 1.0f);

    // Edge-concentrated effect: intensity ramps from 0 at the centre up to
    // the curve-shaped peak at the rim. The visible "rectangle" boundary
    // that this model produced on its own (the inner pass-through region
    // meeting the refracting rim) is eliminated by the medial-axis
    // smoothstep in `computeSDFGradient`: the gradient magnitude itself
    // tapers from 0 at the centre to 1 at the rim across the short
    // dimension, so the displacement field has no sharp transition.
    //
    // Combined: both intensity AND gradient magnitude ramp smoothly across
    // the lens body. The medial-axis seam and the mirrored double-image
    // disappear because adjacent pixels in the interior see near-zero
    // displacement regardless of which half of the lens they sit in.
    //
    //   falloffLength    = width of the active zone as a fraction of the
    //                       lens radius. 1.0 = ramp spans the entire lens
    //                       (default); 0.3 = only the outer 30 % carries
    //                       the effect.
    //   falloff curve    = shape of the 0→1 ramp within the active zone.
    //   falloffIntensity = overall [0, 1] multiplier on the peak.
    float effectIntensity = 0.0f;
    if (clampedFalloffLength > 0.0f && clampedFalloffIntensity > 0.0f) {
        float activeStart = 1.0f - clampedFalloffLength;
        float t = clamp((normalizedRadius - activeStart) / clampedFalloffLength, 0.0f, 1.0f);
        effectIntensity = applyFalloff(t, falloffCurve) * clampedFalloffIntensity;
    }

    // Anti-alias at the SDF boundary (1.5 px soft edge) — prevents the
    // peak refraction at the outermost pixel from sampling outside the
    // lens shape.
    effectIntensity *= clamp(-dOuter, 0.0f, 1.5f) / 1.5f;

    if (effectIntensity < 0.0001f) {
        return isOverlay ? half4(0.0h) : sourceTexture.sample(texSampler, in.texCoord);
    }

    // SDF gradient as refraction direction — physically correct for a glass pane
    // whose cross-section follows the SDF contour.
    float2 outwardDir = computeSDFGradient(toPixel, halfSize, clampedCorner);

    // Snell deviations and surfaceAngle are uniform across the lens; precomputed
    // CPU-side in `LiquidLensConfiguration.toUniforms`. When `lensCurvature` is
    // ~0 the CPU passes deviations near zero, so displacement vanishes naturally
    // without a per-pixel early-out branch.
    float signFactor = (uniforms.strength >= 0.0f) ? 1.0f : -1.0f;
    float absStrength = abs(uniforms.strength);

    // Convert angular deviation to pixel displacement
    float displacementScale = minHalf * absStrength * effectIntensity * 2.0f;

    float dispGreen = uniforms.deviationGreen * displacementScale * signFactor;

    // Non-chromatic specialization path (function constant = false).
    if (!kEnableChromatic) {
        float2 uv = (position + outwardDir * dispGreen) / uniforms.textureSize;
        return sourceTexture.sample(texSampler, uv);
    }

    // Fast path: when chromatic aberration is zero, all channels share the same displacement.
    if (clampedChromatic < 0.0001f) {
        float2 uv = (position + outwardDir * dispGreen) / uniforms.textureSize;
        return sourceTexture.sample(texSampler, uv);
    }

    float dispRed   = mix(dispGreen, uniforms.deviationRed * displacementScale * signFactor, clampedChromatic);
    float dispBlue  = mix(dispGreen, uniforms.deviationBlue * displacementScale * signFactor, clampedChromatic);

    // Calculate sample positions in pixel space, then convert to normalized UV
    float2 invSize = 1.0f / uniforms.textureSize;
    float2 redUV   = (position + outwardDir * dispRed)   * invSize;
    float2 greenUV = (position + outwardDir * dispGreen) * invSize;
    float2 blueUV  = (position + outwardDir * dispBlue)  * invSize;

    // Sample each color channel at its wavelength-specific position
    half4 redSample   = sourceTexture.sample(texSampler, redUV);
    half4 greenSample = sourceTexture.sample(texSampler, greenUV);
    half4 blueSample  = sourceTexture.sample(texSampler, blueUV);

    // Compose final color
    half4 result;
    result.r = redSample.r;
    result.g = greenSample.g;
    result.b = blueSample.b;
    result.a = greenSample.a;

    return result;
}
