//
//  ClearGlass.metal
//  AemiSDR
//
//  Clear glass: the backdrop seen through a thin glass body of any shape.
//
//  The look, as measured on native Liquid Glass (clear), is three things:
//    1. a soft Gaussian blur of the whole interior (sigma about 0.94 pt),
//    2. an additive lift that fades with the luminance of what is behind it,
//    3. a rim band where the backdrop is pulled from further inside the shape, by an amount that falls off as a
//       Gaussian of the distance from the edge (about 28 pt at the edge, 9 pt wide).
//
//  Everything depends on the shape only through a signed distance and its gradient. The shape is either analytic (a
//  rounded rectangle with a radius per corner and a continuous or circular curve) or an arbitrary one read from a
//  distance-field texture built from a path. Pixel units throughout: the drawable's pixels, origin top left.
//
//  The analytic distance is the one verified against Apple's own shader (AppleGlassOracleTests, ADR-0007).
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Shape

constant float kContinuousExtent = 1.52866495f;

/// Distance and unit gradient of one rounded corner. `p` lies in the quadrant that owns the corner; `k` is the corner
/// radius (its sign is read by the caller, the magnitude here); `m` blends the continuous curve (0) with a circle (1).
inline float3 cornerDistance(float2 p, float2 b, float k, float2 m) {
    float r = fabs(k);
    float R = r * kContinuousExtent;
    float inner = mix(R, r, max(m.x, m.y));
    float2 q = p - b;
    float2 cc = q + inner;
    float2 w = fabs(max(float2(0.0f), (q + R) / R));
    float len = sqrt(dot(w, w));
    float hi = max(w.x, w.y), lo = min(w.x, w.y);
    float t = (hi == 0.0f) ? 0.0f : saturate(lo / hi);
    float fit = (((-0.926054001f * t + 3.15600991f) * t - 3.64122009f) * t + 1.26803005f) * t + 0.268530995f;
    float squircle = (len + 1.0f) - 1.0f / (1.0f - t * t * saturate(len) * fit);
    float2 wc = max(float2(0.0f), w * kContinuousExtent - 0.528665006f);
    float circle = sqrt(dot(wc, wc)) * 0.654165566f + 0.345834434f;
    float onX = mix(squircle, circle, m.x);
    float onY = mix(squircle, circle, m.y);
    float s = (w.y > w.x) ? 1.0f : -1.0f;
    float f = mix(onX, onY, saturate(0.5f - s + s * t)) - 1.0f;
    // The corner term is rounded to half precision before it is scaled, as in the reference.
    half rounded = half(f);
    float2 outside = max(float2(0.0f), cc);
    float2 n = outside * rsqrt(dot(outside, outside));
    float2 axis = (cc.x > cc.y) ? float2(1.0f, 0.0f) : float2(0.0f, 1.0f);
    float2 g = (n.x + n.y > 0.0f) ? n : axis;
    return float3(min(max(cc.x, cc.y), 0.0f) + R * float(rounded), g);
}

/// Distance (negative inside) and unit outward gradient of a rounded rectangle centred on the origin.
/// `radii` is (topLeft, topRight, bottomLeft, bottomRight) in pixels; a negative radius asks for the continuous curve.
/// A radius of zero is a sharp corner: it is evaluated as a plain box so the corner term never divides by zero.
inline float3 roundedRectField(float2 p, float2 halfSize, float4 radii) {
    // Screen space has y down: (+x,+y) is bottom-right, (-x,-y) is top-left.
    float tl = radii.x, tr = radii.y, bl = radii.z, br = radii.w;
    if (all(radii == 0.0f)) {
        float2 q = fabs(p) - halfSize;
        float outside = length(max(q, float2(0.0f)));
        float d = outside + min(max(q.x, q.y), 0.0f);
        float2 sgn = float2(p.x >= 0.0f ? 1.0f : -1.0f, p.y >= 0.0f ? 1.0f : -1.0f);
        float2 g = (outside > 0.0f) ? normalize(max(q, float2(0.0f))) : ((q.x > q.y) ? float2(1.0f, 0.0f) : float2(0.0f, 1.0f));
        return float3(d, g * sgn);
    }
    // Edge by edge, the continuity of the curve is set by how the corner radius compares with the edge it sits on.
    float4 edge = float4(bl + br, bl + tl, tl + tr, br + tr) * 0.5f;       // bottom, left, top, right
    float4 ratio = halfSize.xyxy / edge;
    float4 mm = saturate((-kContinuousExtent - ratio) * -1.89155722f);
    mm = select(float4(1.0f), mm, edge < 0.0f);
    float3 best = cornerDistance(p, halfSize, br, float2(mm.x, mm.w));
    float3 c2 = cornerDistance(float2(-p.x, p.y), halfSize, bl, float2(mm.x, mm.y));
    if (c2.x > best.x) best = float3(c2.x, -c2.y, c2.z);
    float3 c3 = cornerDistance(float2(p.x, -p.y), halfSize, tr, float2(mm.z, mm.w));
    if (c3.x > best.x) best = float3(c3.x, c3.y, -c3.z);
    float3 c4 = cornerDistance(float2(-p.x, -p.y), halfSize, tl, float2(mm.z, mm.y));
    if (c4.x > best.x) best = float3(c4.x, -c4.y, -c4.z);
    return best;
}

// MARK: - Uniforms

struct ClearGlassUniforms {
    float2 viewSize;        // the target, in pixels
    float2 sourceOrigin;    // where the target's top-left sits inside the source texture, in pixels
    float2 sourceSize;      // the source texture, in pixels
    float2 halfSize;        // analytic shape: half extents, centred in the view
    float4 radii;           // analytic shape: (tl, tr, bl, br) corner radii, negative = continuous
    float4 sdfRect;         // path shape: x, y, width, height of the distance texture inside the view
    float rimDepth;         // displacement at the very edge, in pixels
    float rimWidth;         // width of the Gaussian falloff of that displacement, in pixels
    float lift;             // additive lift over black, 0...1
    float lumaFalloff;      // how fast the lift fades with the luminance of the backdrop
    float edge;             // antialiasing half-width of the outline, in pixels
    float outline;          // strength of the dark ring just outside the shape, 0...1 (0 turns it off)
    float outlineReach;     // how far outside the edge the ring reaches, in pixels
    float pad2;             // explicit padding: a float3 here would be 16-byte aligned and move the stride
};

constant bool kShapeFromTexture [[function_constant(0)]];
constant bool useTexture = is_function_constant_defined(kShapeFromTexture) ? kShapeFromTexture : false;

struct VertexOut {
    float4 position [[position]];
    float2 pixel;           // position in the target, in pixels
};

vertex VertexOut clearGlassVertex(uint vertexID [[vertex_id]], constant float2 &viewSize [[buffer(0)]]) {
    float2 corners[4] = { float2(0, 0), float2(1, 0), float2(0, 1), float2(1, 1) };
    float2 c = corners[vertexID];
    VertexOut out;
    out.position = float4(c.x * 2.0f - 1.0f, 1.0f - c.y * 2.0f, 0.0f, 1.0f);
    out.pixel = c * viewSize;
    return out;
}

// MARK: - Blur

/// The blur is the sum of two isotropic Gaussians: a tight core and a wide halo, mixed by `mixA`. Each Gaussian is
/// separable, so each is two passes; the first pass computes both horizontal blurs at once into two targets and the
/// second computes both vertical blurs and mixes them. (A separable product of the mixed kernel would not do: its cross
/// terms are wide in one direction and narrow in the other and streak along the axes.)
///
/// Each kernel arrives as paired taps: element 0 is the centre (weight in `.y`), every other element is a fetch at
/// `.x` texels from the centre, weighted `.y`, taken on both sides. A fetch between two texels is the bilinear blend of
/// both, so one fetch applies the weights of two neighbouring taps.
struct BlurUniforms {
    float2 step;            // one texel, in texture coordinates: (1/width, 0) or (0, 1/height)
    int tapsA;              // paired taps after the centre, kernel A
    int tapsB;              // the same for kernel B
    float mixA;             // weight of kernel A in the result; B takes the rest
    float pad;
};

struct BlurPair {
    float4 a [[color(0)]];
    float4 b [[color(1)]];
};

/// First pass: both horizontal Gaussians of the source.
fragment BlurPair clearGlassBlurHorizontal(
    VertexOut in [[stage_in]], texture2d<float> source [[texture(0)]], constant float2 &viewSize [[buffer(0)]],
    constant BlurUniforms &u [[buffer(1)]], constant float2 *ka [[buffer(2)]], constant float2 *kb [[buffer(3)]]
) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    float2 uv = in.pixel / viewSize;
    float4 centre = source.sample(smp, uv);
    float4 sumA = centre * ka[0].y;
    float4 sumB = centre * kb[0].y;
    int reach = max(u.tapsA, u.tapsB);
    for (int i = 1; i <= reach; i++) {
        if (i <= u.tapsA) {
            float2 offset = u.step * ka[i].x;
            sumA += (source.sample(smp, uv + offset) + source.sample(smp, uv - offset)) * ka[i].y;
        }
        if (i <= u.tapsB) {
            float2 offset = u.step * kb[i].x;
            sumB += (source.sample(smp, uv + offset) + source.sample(smp, uv - offset)) * kb[i].y;
        }
    }
    BlurPair out;
    out.a = sumA;
    out.b = sumB;
    return out;
}

/// Second pass: both vertical Gaussians of the two horizontal results, mixed.
fragment float4 clearGlassBlurVertical(
    VertexOut in [[stage_in]], texture2d<float> horizontalA [[texture(0)]], texture2d<float> horizontalB [[texture(1)]],
    constant float2 &viewSize [[buffer(0)]], constant BlurUniforms &u [[buffer(1)]], constant float2 *ka [[buffer(2)]],
    constant float2 *kb [[buffer(3)]]
) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    float2 uv = in.pixel / viewSize;
    float4 sumA = horizontalA.sample(smp, uv) * ka[0].y;
    float4 sumB = horizontalB.sample(smp, uv) * kb[0].y;
    int reach = max(u.tapsA, u.tapsB);
    for (int i = 1; i <= reach; i++) {
        if (i <= u.tapsA) {
            float2 offset = u.step * ka[i].x;
            sumA += (horizontalA.sample(smp, uv + offset) + horizontalA.sample(smp, uv - offset)) * ka[i].y;
        }
        if (i <= u.tapsB) {
            float2 offset = u.step * kb[i].x;
            sumB += (horizontalB.sample(smp, uv + offset) + horizontalB.sample(smp, uv - offset)) * kb[i].y;
        }
    }
    return mix(sumB, sumA, u.mixA);
}

// MARK: - Glass

/// Signed distance and gradient at a pixel of the target, from the shape.
inline float3 shapeAt(float2 pixel, constant ClearGlassUniforms &u, texture2d<float> field) {
    if (useTexture) {
        constexpr sampler smp(filter::linear, address::clamp_to_edge);
        float2 local = (pixel - u.sdfRect.xy) / u.sdfRect.zw;
        // Outside the texture the shape is absent: a large positive distance.
        if (any(local < 0.0f) || any(local > 1.0f)) return float3(1.0e4f, 0.0f, 0.0f);
        float2 texel = 1.0f / u.sdfRect.zw;
        float d = field.sample(smp, local).r;
        float dx = field.sample(smp, local + float2(texel.x, 0.0f)).r - field.sample(smp, local - float2(texel.x, 0.0f)).r;
        float dy = field.sample(smp, local + float2(0.0f, texel.y)).r - field.sample(smp, local - float2(0.0f, texel.y)).r;
        float2 g = float2(dx, dy);
        float len = length(g);
        return float3(d, len > 1.0e-5f ? g / len : float2(0.0f, 0.0f));
    }
    return roundedRectField(pixel - u.viewSize * 0.5f, u.halfSize, u.radii);
}

inline float srgbToLinear(float c) { return c <= 0.04045f ? c * (1.0f / 12.92f) : pow((c + 0.055f) * (1.0f / 1.055f), 2.4f); }

/// The additive lift: strongest over black, fading with the linear luminance of the (blurred) backdrop behind it.
inline float3 clearTone(float3 rgb, float lift, float falloff) {
    float L = 0.2126f * srgbToLinear(rgb.r) + 0.7152f * srgbToLinear(rgb.g) + 0.0722f * srgbToLinear(rgb.b);
    return saturate(rgb + lift * (1.0f - falloff * L));
}

fragment float4 clearGlassFragment(
    VertexOut in [[stage_in]], texture2d<float> blurred [[texture(0)]], texture2d<float> original [[texture(1)]],
    texture2d<float> field [[texture(2)]], constant ClearGlassUniforms &u [[buffer(1)]]
) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    float3 shape = shapeAt(in.pixel, u, field);
    float d = shape.x;
    // Outline coverage: one pixel of antialiasing centred on the edge.
    float coverage = saturate(0.5f - d / max(u.edge, 1.0e-3f));
    // The ring outside the edge: native glass darkens what is just beyond it by a constant that falls off linearly.
    bool ring = u.outline > 0.0f && d > 0.0f && d < u.outlineReach + 1.0f;
    if (coverage <= 0.0f && !ring) return float4(0.0f);

    float2 sourcePixel = in.pixel + u.sourceOrigin;
    float3 rgb = float3(0.0f);
    if (coverage > 0.0f) {
        float depth = max(-d, 0.0f);
        float pull = u.rimDepth * exp(-(depth * depth) / (u.rimWidth * u.rimWidth));
        // Inward is against the outward gradient: the glass shows what lies further inside.
        float2 position = sourcePixel - shape.yz * pull;
        rgb = clearTone(blurred.sample(smp, position / u.sourceSize).rgb, u.lift, u.lumaFalloff);
    }
    float alpha = coverage;
    if (ring) {
        float3 behind = original.sample(smp, sourcePixel / u.sourceSize).rgb;
        float darkening = u.outline * saturate(1.0f - d / max(u.outlineReach, 1.0e-3f));
        float3 darkened = saturate(behind - darkening);
        rgb = (coverage > 0.0f) ? mix(darkened, rgb, coverage) : darkened;
        // Opaque where the ring is, fading over the last pixel; the colour there already equals the backdrop.
        alpha = max(coverage, saturate(u.outlineReach + 1.0f - d));
    }
    return float4(rgb * alpha, alpha);
}
