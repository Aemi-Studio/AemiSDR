//
//  GlassSDFReference.metal
//  AemiSDR verification
//
//  A reference implementation of the shape distance field behind native Liquid Glass, and of the foreground
//  highlight that consumes it. It exists for one purpose: AppleGlassOracleTests renders it and Apple's own
//  glass_foreground_sdf shader (read at test time from the installed simulator runtime, never copied into this
//  repository) with the same random inputs and compares every pixel. See ADR-0007.
//
//  The geometry, as measured:
//    - a rounded box whose corner extent is R = 1.528665 * r (the continuous-corner extent), not r;
//    - the circular corner distance is replaced by a fitted correction in t = min(w)/max(w) of the corner-local
//      coordinates w, which bulges toward the pointy corner like a squircle;
//    - that is blended with a plain circle of radius r by a per-edge parameter m in [0, 1];
//    - the corner term is rounded to half precision before it is scaled by R;
//    - four corners take the largest of four reflected evaluations, each with its own radius;
//    - the sign of a corner radius selects the curve (negative: continuous, positive: circular), and the
//      continuous curve fades to a circle as the radius approaches the half-size, so a capsule stays round.
//

#include <metal_stdlib>
using namespace metal;

constant float kContinuousExtent = 1.52866495f;

/// s0 = (halfWidth, halfHeight, mode, ellipseMix); s1 = rows of the 2x2 applied to the gradient;
/// s2 = (mx, my, radius, unused) for mode 4, or four corner radii for mode 5.
struct SdfU { float4 s0; float4 s1; float4 s2; };

/// Distance and unit gradient of one corner. `p` is in the quadrant that owns the corner.
static inline float3 corner_distance(float2 p, float2 b, float k, float2 m) {
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
    half rounded = half(f);
    float2 outside = max(float2(0.0f), cc);
    float2 n = outside * rsqrt(dot(outside, outside));
    float2 axis = (cc.x > cc.y) ? float2(1.0f, 0.0f) : float2(0.0f, 1.0f);
    float2 g = (n.x + n.y > 0.0f) ? n : axis;
    float d = min(max(cc.x, cc.y), 0.0f) + R * float(rounded);
    return float3(d, g);
}

/// (distance, gradient.x, gradient.y, coverage) at `p`.
static inline float4 shape_field(float2 p, int mode, constant SdfU &u) {
    float2 sgn = float2(p.x >= 0.0f ? 1.0f : -1.0f, p.y >= 0.0f ? 1.0f : -1.0f);
    float2 ell = float2(p.x, u.s0.x * p.y / u.s0.y);
    ell *= rsqrt(dot(ell, ell));
    float d;
    float2 g;
    if (mode < 4) {
        float2 q = fabs(p) - u.s0.xy;
        d = max(q.x, q.y);
        g = ((q.x > q.y) ? float2(1.0f, 0.0f) : float2(0.0f, 1.0f)) * sgn;
    } else if (mode == 4) {
        float3 r = corner_distance(fabs(p), u.s0.xy, u.s2.z, u.s2.xy);
        d = r.x;
        g = r.yz * sgn;
    } else {
        // Per-edge continuity from the neighbouring corner radii: negative radii ask for the continuous curve.
        float4 edge = (u.s2.xxwy + u.s2.ywzz) * 0.5f;
        float4 ratio = u.s0.xyxy / edge;
        float4 mm = saturate((-kContinuousExtent - ratio) * -1.89155722f);
        mm = select(float4(1.0f), mm, edge < 0.0f);
        float3 best = corner_distance(p, u.s0.xy, u.s2.y, float2(mm.x, mm.w));
        float3 c2 = corner_distance(float2(-p.x, p.y), u.s0.xy, u.s2.x, float2(mm.x, mm.y));
        if (c2.x > best.x) best = float3(c2.x, -c2.y, c2.z);
        float3 c3 = corner_distance(float2(p.x, -p.y), u.s0.xy, u.s2.z, float2(mm.z, mm.w));
        if (c3.x > best.x) best = float3(c3.x, c3.y, -c3.z);
        float3 c4 = corner_distance(float2(-p.x, -p.y), u.s0.xy, u.s2.w, float2(mm.z, mm.y));
        if (c4.x > best.x) best = float3(c4.x, -c4.y, -c4.z);
        d = best.x;
        g = best.yz;
    }
    float2 n = mix(g, ell, u.s0.w);
    n *= rsqrt(dot(n, n));
    return float4(d, dot(n, u.s1.xy), dot(n, u.s1.zw), 1.0f);
}

struct GlassU {
    float4 m;
    float amp1, gain1, start1, amp2, gain2, start2;
    float2 L2;
    float fadeA, fadeB, fadeFrom, fadeTo;
    float2 L1;
};
struct ForegroundU { SdfU sdf; GlassU glass; };

struct Interpolants { float4 position [[position]]; float2 sdf_uv; float2 src_uv; };

static inline float4 foreground(float2 srcUV, float4 field, texture2d<float> tex, constant GlassU &g, float edr) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    float d = field.x;
    if (field.w < 0.001f) return float4(0.0f);
    float coverage = saturate(0.5f - d / max(fwidth(d), 1e-4f));
    float2 grad = field.yz;
    // Two highlight offsets: the edge normal pushed through a 2x2 and a light direction, scaled by a circular
    // profile of the depth below the edge.
    float2 a1 = float2(dot(g.m.xy, g.L1), g.L1.x * g.m.y - g.L1.y * g.m.x);
    float2 b1 = float2(dot(g.m.zw, g.L1), g.L1.x * g.m.w - g.L1.y * g.m.z);
    float2 o1 = float2(dot(a1, grad), dot(b1, grad));
    float t1 = saturate((-d - g.start1) * g.gain1);
    o1 *= g.amp1 * (1.0f - saturate(sqrt(saturate((2.0f - t1) * t1))));
    float2 a2 = float2(dot(g.m.xy, g.L2), g.L2.x * g.m.y - g.L2.y * g.m.x);
    float2 b2 = float2(dot(g.m.zw, g.L2), g.L2.x * g.m.w - g.L2.y * g.m.z);
    float2 o2 = float2(dot(b2, grad), dot(a2, grad));
    float t2 = saturate((-d - g.start2) * g.gain2);
    o2 *= g.amp2 * (1.0f - saturate(sqrt(saturate((2.0f - t2) * t2))));
    float2 base = o1 + srcUV;
    // Dispersive taps: red leans along +o2, blue along -o2, green on both sides.
    float4 acc = float4(0.0f);
    float k = 1.0f;
    for (int i = 0; i < 3; i++) {
        float4 s = tex.sample(smp, base + k * o2);
        float2 c = s.xy / max(s.w, 3.3e-6f);
        acc.x += c.x * k; acc.y += c.y * (1.0f - k); acc.w += s.w;
        k -= 0.333333343f;
    }
    k = 0.0f;
    for (int i = 0; i < 4; i++) {
        float4 s = tex.sample(smp, base - k * o2);
        float2 c = s.yz / max(s.w, 3.3e-6f);
        acc.y += c.x * (1.0f - k); acc.z += c.y * k; acc.w += s.w;
        k += 0.333333343f;
    }
    float3 rgb = acc.xyz * float3(0.5f, 0.333333343f, 0.5f);
    float alpha = field.w * 0.142857149f * coverage * acc.w;
    float4 color = float4(rgb * (alpha * edr), alpha);
    float fade = mix(g.fadeFrom, g.fadeTo, saturate(fma(d, 1.0f / (g.fadeB - g.fadeA), -g.fadeA / (g.fadeB - g.fadeA))));
    return (1.0f - fade) * color;
}

fragment float4 reference_glass_foreground_sdf(
    Interpolants in [[stage_in]], texture2d<float> tex [[texture(3)]],
    constant ForegroundU &u [[buffer(1)]], constant float &edr [[buffer(6)]]) {
    float4 field = shape_field(in.sdf_uv, int(fabs(u.sdf.s0.z)), u.sdf);
    return foreground(in.src_uv, field, tex, u.glass, edr);
}
