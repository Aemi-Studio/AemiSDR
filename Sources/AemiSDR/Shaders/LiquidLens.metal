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
//   - Falloff controls effect intensity from center to edge
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
    int useRadialDirection;
    int overlayMode;  // 1 = transparent outside lens (for overlay on live content)
    float refractiveIndexRed;
    float refractiveIndexGreen;
    float refractiveIndexBlue;
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

// Refractive index of air at standard conditions
constant float kAirRefractiveIndex = 1.000293;

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

// MARK: - Outward Direction Functions

inline float2 computeRadialDirection(float2 p) {
    float len = length(p);
    if (len < 0.0001f) {
        return float2(1.0f, 0.0f);
    }
    return p / len;
}

inline float2 computeSDFGradient(float2 p, float2 halfSize, float cornerRadius) {
    float corner = clamp(cornerRadius, 0.0f, min(halfSize.x, halfSize.y));
    float2 absP = abs(p);
    float2 signP = float2(p.x >= 0.0f ? 1.0f : -1.0f, p.y >= 0.0f ? 1.0f : -1.0f);

    // Rounded-rectangle corner frame in the first quadrant.
    float2 inner = halfSize - corner;
    float2 q = absP - inner;
    float2 qp = max(q, float2(0.0f));

    float2 gradLocal;
    if (corner > 0.0001f && qp.x > 0.0f && qp.y > 0.0f) {
        // Exact corner arc normal for SDF in corner sectors.
        float qLen = length(qp);
        gradLocal = (qLen > 0.0001f) ? (qp / qLen) : float2(0.707107f, 0.707107f);
    } else {
        // Exact nearest straight-edge normal for non-corner sectors.
        float dx = max(halfSize.x - absP.x, 0.0f);
        float dy = max(halfSize.y - absP.y, 0.0f);
        gradLocal = (dx <= dy) ? float2(1.0f, 0.0f) : float2(0.0f, 1.0f);
    }

    return gradLocal * signP;
}

inline float2 computeShapeAwareDirection(float2 p, float2 halfSize, float cornerRadius) {
    return computeSDFGradient(p, halfSize, cornerRadius);
}

inline float2 safeNormalize(float2 v, float2 fallback) {
    float len = length(v);
    if (len > 0.0001f) {
        return v / len;
    }
    return fallback;
}

inline float cornerRadialBlendFactor(float2 p, float2 halfSize, float cornerRadius) {
    float corner = clamp(cornerRadius, 0.0f, min(halfSize.x, halfSize.y));
    if (corner <= 0.0001f) {
        return 0.0f;
    }

    float2 inner = halfSize - corner;
    float2 q = abs(p) - inner;
    float2 qp = max(q, float2(0.0f));

    // Keep straight edges shape-aware. Radial contribution is only for rounded corners.
    if (qp.x <= 0.0f || qp.y <= 0.0f) {
        return 0.0f;
    }

    float cornerRadiusLocal = length(qp);
    if (cornerRadiusLocal <= 0.0001f) {
        return 0.0f;
    }

    // Angular term: sin(2*theta) = 2*sin(theta)*cos(theta), zero on straight-edge tangents.
    float2 cornerUnit = qp / cornerRadiusLocal;
    float angularBlend = clamp(2.0f * cornerUnit.x * cornerUnit.y, 0.0f, 1.0f);

    // Radial term: increases from inner-corner start to the outer corner arc.
    float radialBlend = clamp(cornerRadiusLocal / corner, 0.0f, 1.0f);

    return smoothstep(0.0f, 1.0f, radialBlend) * smoothstep(0.0f, 1.0f, angularBlend);
}

inline float2 computeHybridDirection(
    float2 p,
    float2 halfSize,
    float cornerRadius,
    float radialBoost
) {
    float2 radialDir = computeRadialDirection(p);
    float2 shapeDir = safeNormalize(
        computeShapeAwareDirection(p, halfSize, cornerRadius),
        radialDir
    );
    float cornerBlend = cornerRadialBlendFactor(p, halfSize, cornerRadius) * radialBoost;
    return safeNormalize(mix(shapeDir, radialDir, cornerBlend), shapeDir);
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

    // Clamp parameters
    float clampedCorner = clamp(uniforms.cornerRadius, 0.0f, minHalf);
    float clampedCurvature = clamp(uniforms.lensCurvature, 0.0f, 1.0f);
    float clampedFalloffLength = clamp(uniforms.falloffLength, 0.01f, 1.0f);
    float clampedFalloffIntensity = clamp(uniforms.falloffIntensity, 0.0f, 1.0f);
    float clampedChromatic = clamp(uniforms.chromaticAmount, 0.0f, 10.0f);
    int falloffCurve = uniforms.falloffType;
    bool radialMode = uniforms.useRadialDirection != 0;

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

    float innerBoundary = 1.0f - clampedFalloffLength;

    // Inside the no-effect zone
    if (normalizedRadius < innerBoundary && clampedFalloffIntensity > 0.0f) {
        return isOverlay ? half4(0.0h) : sourceTexture.sample(texSampler, in.texCoord);
    }

    // Remap normalizedRadius to falloff range [0, 1]
    float falloffT = (normalizedRadius - innerBoundary) / clampedFalloffLength;
    falloffT = clamp(falloffT, 0.0f, 1.0f);

    float falloffValue = applyFalloff(falloffT, falloffCurve);
    float effectIntensity = mix(1.0f, falloffValue, clampedFalloffIntensity);

    float surfaceAngle = sphericalSurfaceAngle(normalizedRadius, clampedCurvature);

    if (surfaceAngle < 0.0001f || effectIntensity < 0.0001f) {
        return isOverlay ? half4(0.0h) : sourceTexture.sample(texSampler, in.texCoord);
    }

    // Hybrid direction field:
    // - shape-aware normal on straight edges (uniform edge response),
    // - radial influence in rounded-corner sectors,
    // - smooth geometric blend from tangent lines to corner arcs.
    float radialBoost = radialMode ? 1.0f : 0.75f;
    float2 outwardDir = computeHybridDirection(toPixel, halfSize, clampedCorner, radialBoost);

    // Calculate refraction deviation using precomputed refractive indices.
    // These values are computed on CPU and passed in uniforms to avoid
    // repeated Sellmeier evaluation per fragment.
    float signFactor = (uniforms.strength >= 0.0f) ? 1.0f : -1.0f;
    float absStrength = abs(uniforms.strength);

    float deviationGreen = snellDeviation(
        surfaceAngle,
        kAirRefractiveIndex,
        uniforms.refractiveIndexGreen
    );

    // Convert angular deviation to pixel displacement
    float displacementScale = minHalf * absStrength * effectIntensity * 2.0f;

    float dispGreen = deviationGreen * displacementScale * signFactor;

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

    float deviationRed = snellDeviation(
        surfaceAngle,
        kAirRefractiveIndex,
        uniforms.refractiveIndexRed
    );
    float deviationBlue = snellDeviation(
        surfaceAngle,
        kAirRefractiveIndex,
        uniforms.refractiveIndexBlue
    );

    float dispRed   = mix(dispGreen, deviationRed * displacementScale * signFactor, clampedChromatic);
    float dispBlue  = mix(dispGreen, deviationBlue * displacementScale * signFactor, clampedChromatic);

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
