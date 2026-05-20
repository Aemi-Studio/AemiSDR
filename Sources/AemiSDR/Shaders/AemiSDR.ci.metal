//
//  AemiSDR.metal
//  AemiSDR
//
// Created by Guillaume Coquard on 20.09.25.
//
//  This Metal shader file contains Core Image kernel functions for creating various
//  types of alpha masks and shape masks. These are commonly used for UI effects,
//  image masking, and visual transitions in iOS/macOS applications.
//
//  The file implements several mask types:
//  - Linear gradients (vertical masks with smooth transitions)
//  - Rounded rectangles (iOS-style with customizable corner radius)
//  - Superellipses/Squircles (iOS-style continuous curvature shapes)
//
//  Each mask type supports:
//  - Customizable dimensions and parameters
//  - Smooth anti-aliased edges via distance fields
//  - Optional inversion for cut-out effects
//  - Different easing functions (Hermite smoothstep or quadratic ease)

#include <CoreImage/CoreImage.h>
using namespace metal;

//======================================================================
// MARK: - Mathematical Helper Functions (internal, not exported)
//======================================================================

/**
 * Safe positive-base pow. The squircle SDF feeds normalized values in
 * [0, 1] with exponent n ∈ [2, 100]; the `max(x, 1e-6)` floor avoids
 * `pow(0, n) = 0` propagating into divisions while keeping precision.
 */
inline float safe_pow(float x, float n) {
    return pow(max(x, 1e-6f), n);
}

/**
 * Computes the signed distance field (SDF) to a rounded rectangle.
 *
 * This is a fundamental 2D SDF primitive that returns the minimum distance from
 * a point to the edge of a rounded rectangle. The sign indicates whether the
 * point is inside (negative) or outside (positive) the shape.
 *
 * @param p Point to test, relative to rectangle center
 * @param half_size Half dimensions of the rectangle (width/2, height/2)
 * @param radius Corner radius in pixels
 * @return Signed distance: negative inside, positive outside, zero on boundary
 *
 * Algorithm (based on Inigo Quilez's 2D distance functions):
 * 1. Inset the rectangle by the corner radius
 * 2. Compute distance to the inset rectangle
 * 3. Subtract the radius to account for the rounded corners
 *
 * The function handles edge cases where radius exceeds rectangle dimensions
 * by clamping to create a valid shape (prevents artifacts).
 */
inline float rounded_rect_sdf(float2 p, float2 half_size, float radius) {
    // Ensure radius doesn't exceed the smallest dimension (would create invalid shape)
    float r = clamp(radius, 0.0f, min(half_size.x, half_size.y));
    
    // Compute the effective rectangle size after accounting for rounded corners
    // This creates an "inset" rectangle where straight edges begin
    float2 d = abs(p) - (half_size - float2(r));
    
    // Distance calculation:
    // - If d.x <= 0 and d.y <= 0: point is inside the straight edge region
    // - Otherwise: point is in a corner region (needs circular distance)
    
    // Distance outside the inset rectangle (only positive components contribute)
    float outside = length(max(d, float2(0.0f)));
    
    // Distance inside the inset rectangle (largest negative component)
    // This gives us the distance to the nearest edge when inside
    float inside  = min(max(d.x, d.y), 0.0f);
    
    // Combine and adjust for corner radius
    // The radius subtraction effectively "rounds" the corners
    return outside + inside - r;
}

/**
 * Simplified superellipse/squircle SDF optimized for UI shapes.
 *
 * A squircle is a shape between a square and circle, defined by the
 * superellipse equation: |x/a|^n + |y/b|^n = 1
 *
 * This implementation creates iOS-style continuous curvature corners that
 * look more natural than simple circular corners. The shape smoothly
 * transitions from straight edges to curved corners.
 *
 * @param p Point to test, relative to shape center
 * @param half_size Half dimensions of the bounding rectangle
 * @param radius Corner "radius" (controls corner region size)
 * @param n Exponent controlling corner sharpness (2=circle, 4+=squircle, ∞=square)
 * @return Signed distance to the squircle boundary
 *
 * Implementation notes:
 * - Combines rectangular SDF concepts with superellipse mathematics
 * - Approximates true superellipse distance for better performance
 * - Handles edge cases (zero radius, extreme exponents) gracefully
 */
inline float simple_squircle_sdf(float2 p, float2 half_size, float radius, float n) {
    // Ensure valid radius (same logic as rounded rectangle)
    float r = clamp(radius, 0.0f, min(half_size.x, half_size.y));

    // Define the inner rectangle where edges are straight
    float2 rect_half = max(half_size - float2(r), float2(0.0f));

    // Calculate position relative to the inset rectangle
    float2 d = abs(p) - rect_half;

    // Straight edge region (not in a corner)
    if (d.x <= 0.0f && d.y <= 0.0f) {
        return max(d.x, d.y) - r;
    }

    // Corner region (positive quadrant by symmetry)
    float2 corner = max(d, float2(0.0f));
    if (r <= 0.0f) {
        return length(corner);
    }

    // Transform to normalized superellipse space [0, 1].
    float2 normalized = corner / r;
    float invN = 1.0f / max(n, 2.0f);

    // Evaluate |x|^n + |y|^n. Floor at 1e-6 to avoid `pow(0, n)` problems
    // and to keep the subsequent `pow(seSum, 1/n)` numerically stable.
    float seSum = safe_pow(normalized.x, n) + safe_pow(normalized.y, n);

    // Radial parameterization: distance along the line from the inner-rect
    // corner to (cx, cy). On the curve, scale = 1 and the result is exactly
    // zero. This is the standard Inigo Quilez approximation — not a true
    // Euclidean SDF (the gradient magnitude isn't 1 everywhere), but it has
    // the right sign and is monotonic in radial distance. Sufficient for
    // mask kernels where the smoothstep AA only samples near the curve.
    //
    // Note: closed-form true Euclidean SDF for a superellipse does not exist
    // (see refractiveindex.info and Raph Levien's blurred-rounded-rect work).
    // Newton iteration on F = |x/r|^n + |y/r|^n - 1 is unstable for interior
    // points far from the curve (linear extrapolation overshoots when the
    // gradient is small), so we accept the radial approximation here.
    float scale = safe_pow(seSum, invN);
    return r * (scale - 1.0f);
}

/**
 * Converts a signed distance value to an alpha (opacity) value with smooth falloff.
 *
 * This function creates smooth, anti-aliased edges by gradually transitioning
 * the alpha value across a specified width. It uses a Hermite interpolation
 * (smoothstep) for visually pleasing results without visible aliasing.
 *
 * @param dist Signed distance (negative = inside, positive = outside)
 * @param fade_width Width of the transition zone in pixels
 * @return Alpha value: 0.0 (transparent inside) to 1.0 (opaque outside)
 *
 * The Hermite interpolation (3t² - 2t³) provides:
 * - Smooth start and end (zero derivatives at boundaries)
 * - No visible banding or aliasing
 * - Perceptually uniform fade
 *
 * When fade_width = 0, creates a hard edge (no anti-aliasing)
 * Larger fade_width values create softer, more blurred edges
 */
inline float distance_to_alpha(float dist, float fade_width) {
    // Handle hard edge case (no anti-aliasing)
    if (fade_width <= 0.0f) {
        return (dist >= 0.0f) ? 1.0f : 0.0f;
    }
    // MSL built-in smoothstep: t = clamp((x - edge0) / (edge1 - edge0), 0, 1);
    //                          t * t * (3 - 2 * t)
    // Map: dist = -fade_width → 0, dist = 0 → 1 (Hermite cubic).
    return smoothstep(-fade_width, 0.0f, dist);
}

//======================================================================
// MARK: - Core Image Kernel Functions (exported)
//======================================================================

// These functions are exposed to Core Image and can be called from Swift/Objective-C
// They follow Core Image kernel conventions:
// - Return float4/half4 for color values (even for grayscale)
// - Take dimensions and parameters as float arguments
// - Use coreimage::destination for pixel coordinates

extern "C" { namespace coreimage {
    
    // --------------------------------------------------------------
    // MARK: Linear vertical mask (top<->bottom)
    // --------------------------------------------------------------
    /**
     * Creates a linear gradient mask along the vertical axis.
     *
     * This kernel generates a grayscale gradient that transitions linearly
     * from transparent to opaque (or vice versa) along the Y-axis. Commonly
     * used for fade effects, soft edges, or masking content at screen edges.
     *
     * @param widthPx Width of the output image in pixels
     * @param heightPx Height of the output image in pixels
     * @param startOffset Starting position as fraction of height [-1.0, 1.0]
     *                    0.0 = start at top, 0.5 = start at middle, 1.0 = start at bottom
     * @param inverted Direction flag: 0 = top-to-bottom fade, 1 = bottom-to-top fade
     * @param dest Core Image destination providing current pixel coordinates
     * @return RGBA color where all channels contain the same grayscale value
     *
     * The gradient is perfectly linear (no easing) and extends from the start
     * offset to the opposite edge of the image. Negative or >1 offsets are
     * supported for partial gradients.
     */
    half4 linearMask(float widthPx,
                     float heightPx,
                     float startOffset,
                     float inverted,
                     coreimage::destination dest)
    {
        float y = dest.coord().y;
        float h  = max(heightPx, 1.0f);
        float y0 = clamp(startOffset, -1.0f, 1.0f) * h;
        float effective_h = max(h - abs(y0), 1.0f);

        float alpha;
        if (inverted > 0.5f) {
            float y_from_bottom = h - y;
            alpha = clamp((y_from_bottom - y0) / effective_h, 0.0f, 1.0f);
        } else {
            alpha = clamp((y - y0) / effective_h, 0.0f, 1.0f);
        }

        return half4(half(alpha));
    }
    
    // --------------------------------------------------------------
    // MARK: Rounded rectangle with optional inversion (Hermite/smoothstep)
    // --------------------------------------------------------------
    /**
     * Creates a rounded rectangle mask with optional inversion.
     *
     * Uses signed distance fields for perfect anti-aliasing at any scale.
     * With inverted=0, acts as a standard shape mask (opaque inside, transparent outside).
     * With inverted=1, creates a cut-out effect (transparent inside, opaque outside).
     *
     * @param widthPx Width of the rectangle in pixels
     * @param heightPx Height of the rectangle in pixels
     * @param cornerRadiusPx Corner radius in pixels (0 = sharp corners)
     * @param fadeInWidthPx Width of the anti-aliasing fade zone in pixels
     * @param inverted 0 = normal mask, 1 = inverted (cut-out) mask
     * @param dest Core Image destination for pixel coordinates
     * @return RGBA with alpha mask (all channels identical for grayscale)
     */
    half4 roundedRectAlphaMask(float widthPx,
                               float heightPx,
                               float cornerRadiusPx,
                               float fadeInWidthPx,
                               float inverted,
                               coreimage::destination dest)
    {
        float2 half_size = max(float2(widthPx, heightPx) * 0.5f, float2(1.0f));
        float2 p         = dest.coord() - float2(widthPx * 0.5f, heightPx * 0.5f);

        float dist  = rounded_rect_sdf(p, half_size, max(cornerRadiusPx, 0.0f));
        float alpha = distance_to_alpha(dist, max(fadeInWidthPx, 0.0f));

        if (inverted > 0.5f) alpha = 1.0f - alpha;

        return half4(half(alpha));
    }
    
    // --------------------------------------------------------------
    // MARK: Superellipse/Squircle with optional inversion
    // --------------------------------------------------------------
    /**
     * Creates a superellipse (squircle) mask with optional inversion.
     *
     * Superellipses provide more natural-looking rounded corners than simple
     * circular arcs, matching iOS design language. With inverted=0, acts as a
     * standard shape mask. With inverted=1, creates a cut-out effect.
     *
     * @param widthPx Width of the shape in pixels
     * @param heightPx Height of the shape in pixels
     * @param cornerRadiusPx Size of corner regions in pixels
     * @param fadeInWidthPx Anti-aliasing fade width in pixels
     * @param exponent Superellipse exponent (2.0=ellipse, 5.0=iOS squircle, 8.0+=near-rect)
     * @param inverted 0 = normal, 1 = inverted (cut-out)
     * @param dest Pixel coordinate provider
     * @return RGBA grayscale mask
     */
    half4 superellipseAlphaMask(float widthPx,
                                float heightPx,
                                float cornerRadiusPx,
                                float fadeInWidthPx,
                                float exponent,
                                float inverted,
                                coreimage::destination dest)
    {
        float2 center = float2(widthPx * 0.5f, heightPx * 0.5f);
        float2 half_size = max(float2(widthPx * 0.5f, heightPx * 0.5f), float2(1.0f));
        float2 p = dest.coord() - center;

        float n = (exponent > 1.0f) ? clamp(exponent, 2.0f, 100.0f) : 5.0f;

        float dist = simple_squircle_sdf(p, half_size, cornerRadiusPx, n);
        float alpha = distance_to_alpha(dist, max(fadeInWidthPx, 0.0f));

        if (inverted > 0.5f) alpha = 1.0f - alpha;

        return half4(half(alpha));
    }
    
    // --------------------------------------------------------------
    // MARK: Ease-in vertical mask with optional inversion
    // --------------------------------------------------------------
    /**
     * Creates a vertical gradient with quadratic ease-in curve and optional inversion.
     *
     * The quadratic ease (t²) starts slowly and accelerates, creating
     * a more natural fade than linear gradients.
     *
     * @param widthPx Width in pixels (unused but required for consistency)
     * @param heightPx Height in pixels
     * @param startOffset Start position as fraction [0.0, 1.0]
     * @param direction 0 = top-to-bottom, 1 = bottom-to-top
     * @param inverted 0 = normal, 1 = inverted gradient
     * @param dest Pixel coordinates
     * @return half4 for memory efficiency (16-bit per channel)
     */
    half4 easeInAlphaMask(float widthPx,
                          float heightPx,
                          float startOffset,
                          float direction,
                          float inverted,
                          coreimage::destination dest)
    {
        float h     = max(heightPx, 1.0f);
        float yNorm = dest.coord().y / h;

        if (direction > 0.5f) yNorm = 1.0f - yNorm;

        float s = clamp(startOffset, 0.0f, 0.999f);
        float t = clamp((yNorm - s) / (1.0f - s), 0.0f, 1.0f);
        float eased = t * t;

        half a = half(eased);

        // Apply inversion if requested
        if (inverted > 0.5f) a = half(1.0f) - a;

        return half4(a, a, a, a);
    }
    
    // --------------------------------------------------------------
    // MARK: Rounded rectangle with quadratic ease and optional inversion
    // --------------------------------------------------------------
    /**
     * Creates a rounded rectangle using quadratic easing for edge falloff,
     * with optional inversion for cut-out effects.
     *
     * Quadratic easing (t²) vs Hermite (3t²-2t³):
     * - Quadratic: Faster initial falloff, linear acceleration
     * - Hermite: Smoother at both ends, S-curve profile
     *
     * @param widthPx Rectangle width
     * @param heightPx Rectangle height
     * @param cornerRadiusPx Corner rounding radius
     * @param fadeInWidthPx Edge fade width (0 = hard edge)
     * @param inverted 0 = normal, 1 = inverted (cut-out)
     * @param dest Pixel coordinates
     * @return RGBA grayscale mask
     */
    half4 roundedRectEaseAlphaMask(float widthPx,
                                   float heightPx,
                                   float cornerRadiusPx,
                                   float fadeInWidthPx,
                                   float inverted,
                                   coreimage::destination dest)
    {
        float2 half_size = max(float2(widthPx, heightPx) * 0.5f, float2(1.0f));
        float2 p         = dest.coord() - float2(widthPx * 0.5f, heightPx * 0.5f);

        float dist = rounded_rect_sdf(p, half_size, max(cornerRadiusPx, 0.0f));

        float alpha;
        if (fadeInWidthPx <= 0.0f) {
            alpha = (dist >= 0.0f) ? 1.0f : 0.0f;
        } else {
            float t = clamp(1.0f + dist / fadeInWidthPx, 0.0f, 1.0f);
            alpha = t * t;
        }

        if (inverted > 0.5f) alpha = 1.0f - alpha;

        return half4(half(alpha));
    }
    
    // --------------------------------------------------------------
    // MARK: Uniform mask (constant alpha)
    // --------------------------------------------------------------
    /**
     * Creates a uniform mask with constant alpha 1.0 everywhere.
     *
     * Used with the variable blur filter to produce even blur across the
     * entire view surface, as an alternative to gradient-based masks.
     *
     * @param widthPx Width in pixels (unused, required for kernel signature)
     * @param heightPx Height in pixels (unused, required for kernel signature)
     * @param dest Pixel coordinates
     * @return Solid white RGBA (all channels 1.0)
     */
    half4 uniformMask(float widthPx,
                      float heightPx,
                      coreimage::destination dest)
    {
        return half4(1.0h);
    }

    // --------------------------------------------------------------
    // MARK: Center vertical mask with quadratic ease
    // --------------------------------------------------------------
    /**
     * Creates a vertical gradient that peaks at the center and fades to
     * zero at both top and bottom edges.
     *
     * This is the inverse of the edge blur pattern: edges are clear (no blur)
     * and the center region receives maximum blur intensity.
     *
     * @param widthPx Width in pixels (unused, required for kernel signature)
     * @param heightPx Height in pixels
     * @param startOffset Fraction of the half-height that remains at zero before
     *                    the gradient begins (0.0 = gradient from edge, 0.5 = flat center plateau)
     * @param inverted 0 = center blurred / edges clear, 1 = center clear / edges blurred
     * @param dest Pixel coordinates
     * @return half4 for memory efficiency
     */
    half4 easeInCenterMask(float widthPx,
                           float heightPx,
                           float startOffset,
                           float inverted,
                           coreimage::destination dest)
    {
        float h     = max(heightPx, 1.0f);
        float yNorm = dest.coord().y / h;

        // Proximity to vertical center: 1.0 at center, 0.0 at edges
        float proximity = 1.0f - abs(2.0f * yNorm - 1.0f);

        float s = clamp(startOffset, 0.0f, 0.999f);
        float t = clamp((proximity - s) / (1.0f - s), 0.0f, 1.0f);
        float eased = t * t;

        half a = half(eased);
        if (inverted > 0.5f) a = half(1.0f) - a;
        return half4(a, a, a, a);
    }

    // --------------------------------------------------------------
    // MARK: Linear horizontal mask (left<->right)
    // --------------------------------------------------------------
    /**
     * Creates a linear gradient mask along the horizontal axis. Mirror of
     * `linearMask` for X — the inverted flag flips left/right instead of
     * top/bottom. Useful for fading content at the scroll edges of a
     * horizontally-scrolling row or for directional reveal effects.
     *
     * @param widthPx Width of the output image in pixels
     * @param heightPx Height of the output image in pixels (unused by math, required by the kernel signature for output extent)
     * @param startOffset Starting position as fraction of width [-1.0, 1.0]
     * @param inverted Direction flag: 0 = left-to-right, 1 = right-to-left
     * @param dest Core Image destination providing current pixel coordinates
     * @return RGBA grayscale mask
     */
    half4 linearMaskHorizontal(float widthPx,
                               float heightPx,
                               float startOffset,
                               float inverted,
                               coreimage::destination dest)
    {
        float x = dest.coord().x;
        float w = max(widthPx, 1.0f);
        float x0 = clamp(startOffset, -1.0f, 1.0f) * w;
        float effective_w = max(w - abs(x0), 1.0f);

        float alpha;
        if (inverted > 0.5f) {
            float x_from_right = w - x;
            alpha = clamp((x_from_right - x0) / effective_w, 0.0f, 1.0f);
        } else {
            alpha = clamp((x - x0) / effective_w, 0.0f, 1.0f);
        }

        return half4(half(alpha));
    }

    // --------------------------------------------------------------
    // MARK: Ease-in horizontal mask with optional inversion
    // --------------------------------------------------------------
    /**
     * Quadratic ease-in gradient along the X-axis. Mirror of
     * `easeInAlphaMask` for the horizontal direction.
     *
     * @param widthPx Width in pixels
     * @param heightPx Height in pixels (unused)
     * @param startOffset Start position as fraction [0.0, 1.0]
     * @param direction 0 = left-to-right, 1 = right-to-left
     * @param inverted 0 = normal, 1 = inverted gradient
     * @param dest Pixel coordinates
     * @return half4 mask
     */
    half4 easeInAlphaMaskHorizontal(float widthPx,
                                    float heightPx,
                                    float startOffset,
                                    float direction,
                                    float inverted,
                                    coreimage::destination dest)
    {
        float w     = max(widthPx, 1.0f);
        float xNorm = dest.coord().x / w;

        if (direction > 0.5f) xNorm = 1.0f - xNorm;

        float s = clamp(startOffset, 0.0f, 0.999f);
        float t = clamp((xNorm - s) / (1.0f - s), 0.0f, 1.0f);
        float eased = t * t;

        half a = half(eased);
        if (inverted > 0.5f) a = half(1.0f) - a;

        return half4(a, a, a, a);
    }

    // --------------------------------------------------------------
    // MARK: Center horizontal mask with quadratic ease
    // --------------------------------------------------------------
    /**
     * Horizontal-axis center gradient: peaks at the X centre and fades
     * to zero at both left and right edges. Mirror of `easeInCenterMask`
     * for the horizontal direction.
     *
     * @param widthPx Width in pixels
     * @param heightPx Height in pixels (unused)
     * @param startOffset Fraction of the half-width that remains flat before the gradient begins
     * @param inverted 0 = centre blurred / edges clear, 1 = centre clear / edges blurred
     * @param dest Pixel coordinates
     * @return half4 mask
     */
    half4 easeInCenterMaskHorizontal(float widthPx,
                                     float heightPx,
                                     float startOffset,
                                     float inverted,
                                     coreimage::destination dest)
    {
        float w     = max(widthPx, 1.0f);
        float xNorm = dest.coord().x / w;

        float proximity = 1.0f - abs(2.0f * xNorm - 1.0f);

        float s = clamp(startOffset, 0.0f, 0.999f);
        float t = clamp((proximity - s) / (1.0f - s), 0.0f, 1.0f);
        float eased = t * t;

        half a = half(eased);
        if (inverted > 0.5f) a = half(1.0f) - a;
        return half4(a, a, a, a);
    }

    // --------------------------------------------------------------
    // MARK: Superellipse with quadratic ease and optional inversion
    // --------------------------------------------------------------
    /**
     * Superellipse mask with quadratic easing and optional inversion.
     *
     * Combines continuous curvature corners with quadratic ease edge falloff
     * and optional inversion for cut-outs.
     *
     * @param widthPx Shape width
     * @param heightPx Shape height
     * @param cornerRadiusPx Corner region size
     * @param fadeInWidthPx Anti-aliasing fade width
     * @param exponent Superellipse exponent (2.0=ellipse, 5.0=iOS squircle)
     * @param inverted 0 = normal, 1 = inverted mask
     * @param dest Pixel coordinates
     * @return RGBA grayscale mask
     */
    half4 superellipseEaseAlphaMask(float widthPx,
                                    float heightPx,
                                    float cornerRadiusPx,
                                    float fadeInWidthPx,
                                    float exponent,
                                    float inverted,
                                    coreimage::destination dest)
    {
        float2 center = float2(widthPx * 0.5f, heightPx * 0.5f);
        float2 half_size = max(float2(widthPx * 0.5f, heightPx * 0.5f), float2(1.0f));
        float2 p = dest.coord() - center;

        float n = (exponent > 1.0f) ? clamp(exponent, 2.0f, 100.0f) : 5.0f;

        float dist = simple_squircle_sdf(p, half_size, cornerRadiusPx, n);

        float alpha;
        if (fadeInWidthPx <= 0.0f) {
            alpha = (dist >= 0.0f) ? 1.0f : 0.0f;
        } else {
            float t = clamp(1.0f + dist / fadeInWidthPx, 0.0f, 1.0f);
            alpha = t * t;
        }

        if (inverted > 0.5f) alpha = 1.0f - alpha;

        return half4(half(alpha));
    }
    
}} // extern "C" namespace coreimage
