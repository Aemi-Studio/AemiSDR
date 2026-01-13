//
//  SDFMathTests.swift
//  AemiSDRTests
//
//  Unit tests for verifying the mathematical correctness of SDF functions.
//  These tests verify the theoretical properties of the signed distance fields.
//

import Testing
import Foundation
import simd

@testable import AemiSDR

// MARK: - SDF Mathematical Property Tests

/// Tests for rounded rectangle SDF mathematical properties.
/// These verify the theoretical correctness of the distance calculations.
@Suite("Rounded Rectangle SDF Tests")
struct RoundedRectSDFTests {

    // MARK: - Test Helper Functions

    /// Swift implementation of rounded_rect_sdf for CPU-side verification.
    /// This mirrors the Metal implementation exactly.
    func roundedRectSDF(p: SIMD2<Float>, halfSize: SIMD2<Float>, radius: Float) -> Float {
        let r = Swift.min(Swift.max(radius, 0), Swift.min(halfSize.x, halfSize.y))
        let d = simd_abs(p) - (halfSize - SIMD2<Float>(repeating: r))
        let outside = simd_length(simd_max(d, SIMD2<Float>.zero))
        let inside = Swift.min(Swift.max(d.x, d.y), 0)
        return outside + inside - r
    }

    // MARK: - Center Point Tests

    @Test("Center point distance equals negative half of smallest dimension")
    func centerPointDistance() {
        // At the center (0,0), distance should be -(min(halfSize) - 0) = -min(halfSize)
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 10

        let dist = roundedRectSDF(p: .zero, halfSize: halfSize, radius: radius)

        // Distance from center to nearest edge
        #expect(abs(dist - (-50)) < 0.001, "Center distance should be -50, got \(dist)")
    }

    @Test("Center point distance for non-square rectangle")
    func centerPointNonSquare() {
        let halfSize = SIMD2<Float>(100, 50)
        let radius: Float = 10

        let dist = roundedRectSDF(p: .zero, halfSize: halfSize, radius: radius)

        // Distance should be to the nearest edge (50 units away)
        #expect(abs(dist - (-50)) < 0.001, "Center distance should be -50, got \(dist)")
    }

    // MARK: - Boundary Tests

    @Test("Edge midpoint is exactly on boundary (dist = 0)")
    func edgeMidpointOnBoundary() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 10

        // Point on the right edge middle
        let p = SIMD2<Float>(50, 0)
        let dist = roundedRectSDF(p: p, halfSize: halfSize, radius: radius)

        #expect(abs(dist) < 0.001, "Edge midpoint should have dist=0, got \(dist)")
    }

    @Test("Top edge midpoint is on boundary")
    func topEdgeMidpoint() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 10

        let p = SIMD2<Float>(0, 50)
        let dist = roundedRectSDF(p: p, halfSize: halfSize, radius: radius)

        #expect(abs(dist) < 0.001, "Top edge midpoint should have dist=0, got \(dist)")
    }

    // MARK: - Corner Tests

    @Test("Corner region returns positive distance (outside)")
    func cornerOutside() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 10

        // Point far outside the corner
        let p = SIMD2<Float>(60, 60)
        let dist = roundedRectSDF(p: p, halfSize: halfSize, radius: radius)

        #expect(dist > 0, "Outside corner should have positive distance, got \(dist)")
    }

    @Test("Exact corner of rounded rect")
    func exactCorner() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 10

        // The corner center is at (50-10, 50-10) = (40, 40)
        // A point on the arc at 45 degrees
        let cornerCenter = SIMD2<Float>(40, 40)
        let arcPoint = cornerCenter + SIMD2<Float>(repeating: radius / sqrt(2))

        let dist = roundedRectSDF(p: arcPoint, halfSize: halfSize, radius: radius)

        #expect(abs(dist) < 0.01, "Point on corner arc should have dist≈0, got \(dist)")
    }

    // MARK: - Symmetry Tests

    @Test("SDF is symmetric across all quadrants")
    func quadrantSymmetry() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 10

        let testPoint = SIMD2<Float>(25, 30)

        let dist1 = roundedRectSDF(p: testPoint, halfSize: halfSize, radius: radius)
        let dist2 = roundedRectSDF(p: SIMD2<Float>(-testPoint.x, testPoint.y), halfSize: halfSize, radius: radius)
        let dist3 = roundedRectSDF(p: SIMD2<Float>(testPoint.x, -testPoint.y), halfSize: halfSize, radius: radius)
        let dist4 = roundedRectSDF(p: -testPoint, halfSize: halfSize, radius: radius)

        #expect(abs(dist1 - dist2) < 0.001, "X-symmetry failed")
        #expect(abs(dist1 - dist3) < 0.001, "Y-symmetry failed")
        #expect(abs(dist1 - dist4) < 0.001, "Origin symmetry failed")
    }

    // MARK: - Edge Case Tests

    @Test("Zero radius produces sharp rectangle")
    func zeroRadius() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 0

        // Corner point
        let p = SIMD2<Float>(50, 50)
        let dist = roundedRectSDF(p: p, halfSize: halfSize, radius: radius)

        // For sharp rectangle, corner distance is 0 (exactly on corner)
        #expect(abs(dist) < 0.001, "Sharp corner should have dist=0, got \(dist)")
    }

    @Test("Radius equals min dimension produces capsule/circle")
    func maxRadius() {
        let halfSize = SIMD2<Float>(50, 30)
        let radius: Float = 30 // Max allowed radius

        // Center should still be valid
        let dist = roundedRectSDF(p: .zero, halfSize: halfSize, radius: radius)

        #expect(dist < 0, "Center should be inside shape")
    }
}

// MARK: - Superellipse SDF Tests

@Suite("Superellipse SDF Tests")
struct SuperellipseSDFTests {

    /// Swift implementation of simple_squircle_sdf for CPU verification.
    func simpleSquircleSDF(p: SIMD2<Float>, halfSize: SIMD2<Float>, radius: Float, n: Float) -> Float {
        let r = Swift.min(Swift.max(radius, 0), Swift.min(halfSize.x, halfSize.y))
        var rectHalf = halfSize - SIMD2<Float>(repeating: r)
        rectHalf = simd_max(rectHalf, SIMD2<Float>.zero)

        let d = simd_abs(p) - rectHalf

        // Inside straight edges
        if d.x <= 0 && d.y <= 0 {
            return Swift.max(d.x, d.y) - r
        }

        let corner = simd_max(d, SIMD2<Float>.zero)

        if r <= 0 {
            return simd_length(corner)
        }

        let normalized = corner / r
        let seSum = pow(Swift.max(normalized.x, 0.0001), n) + pow(Swift.max(normalized.y, 0.0001), n)

        if seSum <= 1 {
            let currentR = pow(seSum, 1 / n) * r
            return currentR - r
        } else {
            let scale = pow(seSum, 1 / n)
            return r * (scale - 1)
        }
    }

    @Test("n=2 approximates circle (exact)")
    func circleCase() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 20
        let n: Float = 2

        // Point on the 45-degree line at the corner
        let cornerCenter = halfSize - SIMD2<Float>(repeating: radius)
        let testPoint = cornerCenter + SIMD2<Float>(repeating: radius / sqrt(2))

        let dist = simpleSquircleSDF(p: testPoint, halfSize: halfSize, radius: radius, n: n)

        // For n=2, this should be very close to exact (circle case)
        #expect(abs(dist) < 0.1, "n=2 should give near-zero at boundary, got \(dist)")
    }

    @Test("Superellipse boundary is exact (zero-level set)")
    func boundaryExact() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 20
        let n: Float = 5 // iOS squircle

        // Test point on the superellipse boundary using parametric form
        // x = a * |cos(t)|^(2/n) * sign(cos(t))
        // y = b * |sin(t)|^(2/n) * sign(sin(t))
        let t: Float = .pi / 4 // 45 degrees
        let cornerCenter = halfSize - SIMD2<Float>(repeating: radius)
        let x = cornerCenter.x + radius * pow(abs(cos(t)), 2 / n)
        let y = cornerCenter.y + radius * pow(abs(sin(t)), 2 / n)

        let dist = simpleSquircleSDF(p: SIMD2<Float>(x, y), halfSize: halfSize, radius: radius, n: n)

        // The zero-level set should be exact
        #expect(abs(dist) < 0.1, "Boundary point should have dist≈0, got \(dist)")
    }

    @Test("Center point distance is correct")
    func centerDistance() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 20
        let n: Float = 5

        let dist = simpleSquircleSDF(p: .zero, halfSize: halfSize, radius: radius, n: n)

        // Center should be at distance -(min dimension)
        #expect(abs(dist - (-50)) < 0.001, "Center distance should be -50, got \(dist)")
    }

    @Test("Outside points have positive distance")
    func outsidePositive() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 20
        let n: Float = 5

        let p = SIMD2<Float>(60, 60) // Outside the shape
        let dist = simpleSquircleSDF(p: p, halfSize: halfSize, radius: radius, n: n)

        #expect(dist > 0, "Outside point should have positive distance")
    }

    @Test("Inside points have negative distance")
    func insideNegative() {
        let halfSize = SIMD2<Float>(50, 50)
        let radius: Float = 20
        let n: Float = 5

        let p = SIMD2<Float>(20, 20) // Inside the shape
        let dist = simpleSquircleSDF(p: p, halfSize: halfSize, radius: radius, n: n)

        #expect(dist < 0, "Inside point should have negative distance")
    }
}

// MARK: - Distance to Alpha Tests

@Suite("Distance to Alpha Tests")
struct DistanceToAlphaTests {

    /// Swift implementation of distance_to_alpha for verification.
    func distanceToAlpha(dist: Float, fadeWidth: Float) -> Float {
        if fadeWidth <= 0 {
            return dist >= 0 ? 1 : 0
        }

        let t = min(max(1 + dist / fadeWidth, 0), 1)
        return t * t * (3 - 2 * t) // Hermite smoothstep
    }

    @Test("Outside shape has alpha = 1")
    func outsideOpaque() {
        let alpha = distanceToAlpha(dist: 10, fadeWidth: 5)
        #expect(abs(alpha - 1) < 0.001, "Outside should be opaque (alpha=1), got \(alpha)")
    }

    @Test("On boundary has alpha = 1")
    func boundaryOpaque() {
        let alpha = distanceToAlpha(dist: 0, fadeWidth: 5)
        #expect(abs(alpha - 1) < 0.001, "Boundary should be opaque (alpha=1), got \(alpha)")
    }

    @Test("Deep inside has alpha = 0")
    func insideTransparent() {
        let alpha = distanceToAlpha(dist: -10, fadeWidth: 5)
        #expect(abs(alpha) < 0.001, "Deep inside should be transparent (alpha=0), got \(alpha)")
    }

    @Test("At fade edge has alpha = 0")
    func fadeEdgeTransparent() {
        let alpha = distanceToAlpha(dist: -5, fadeWidth: 5) // dist = -fadeWidth
        #expect(abs(alpha) < 0.001, "At fade edge should be transparent, got \(alpha)")
    }

    @Test("Halfway through fade zone has alpha ≈ 0.5")
    func halfwayFade() {
        let alpha = distanceToAlpha(dist: -2.5, fadeWidth: 5) // dist = -fadeWidth/2
        // Hermite smoothstep at t=0.5: 0.5^2 * (3 - 2*0.5) = 0.25 * 2 = 0.5
        #expect(abs(alpha - 0.5) < 0.01, "Halfway should be alpha≈0.5, got \(alpha)")
    }

    @Test("Zero fade width produces hard edge")
    func hardEdge() {
        let alphaOutside = distanceToAlpha(dist: 0.1, fadeWidth: 0)
        let alphaInside = distanceToAlpha(dist: -0.1, fadeWidth: 0)

        #expect(abs(alphaOutside - 1) < 0.001, "Outside hard edge should be 1")
        #expect(abs(alphaInside) < 0.001, "Inside hard edge should be 0")
    }

    @Test("Alpha is monotonically decreasing from outside to inside")
    func monotonicDecrease() {
        let fadeWidth: Float = 10

        var prevAlpha: Float = 1.1
        for distInt in stride(from: 5, through: -15, by: -1) {
            let dist = Float(distInt)
            let alpha = distanceToAlpha(dist: dist, fadeWidth: fadeWidth)
            #expect(alpha <= prevAlpha, "Alpha should decrease monotonically")
            prevAlpha = alpha
        }
    }
}

// MARK: - Distance to Alpha with Plateau Tests

@Suite("Distance to Alpha with Plateau Tests")
struct DistanceToAlphaPlateauTests {

    /// Swift implementation of distance_to_alpha_with_plateau for verification.
    func distanceToAlphaWithPlateau(dist: Float, plateauWidth: Float, fadeWidth: Float) -> Float {
        if fadeWidth <= 0 && plateauWidth <= 0 {
            return dist >= 0 ? 1 : 0
        }

        let shiftedDist = dist + plateauWidth

        if shiftedDist >= 0 {
            return 1
        }

        if fadeWidth <= 0 {
            return 0
        }

        let t = min(max(1 + shiftedDist / fadeWidth, 0), 1)
        return t * t * (3 - 2 * t)
    }

    @Test("Plateau zone has alpha = 1")
    func plateauOpaque() {
        let plateauWidth: Float = 10
        let fadeWidth: Float = 5

        // Just inside the boundary (in plateau zone)
        let alpha = distanceToAlphaWithPlateau(dist: -5, plateauWidth: plateauWidth, fadeWidth: fadeWidth)
        #expect(abs(alpha - 1) < 0.001, "In plateau zone should be opaque, got \(alpha)")
    }

    @Test("At plateau edge, fade begins")
    func plateauEdge() {
        let plateauWidth: Float = 10
        let fadeWidth: Float = 5

        // At exactly the end of plateau
        let alpha = distanceToAlphaWithPlateau(dist: -10, plateauWidth: plateauWidth, fadeWidth: fadeWidth)
        #expect(abs(alpha - 1) < 0.001, "At plateau edge should be opaque, got \(alpha)")
    }

    @Test("Past fade zone is transparent")
    func pastFadeTransparent() {
        let plateauWidth: Float = 10
        let fadeWidth: Float = 5

        // Past both plateau and fade
        let alpha = distanceToAlphaWithPlateau(dist: -20, plateauWidth: plateauWidth, fadeWidth: fadeWidth)
        #expect(abs(alpha) < 0.001, "Past fade zone should be transparent, got \(alpha)")
    }

    @Test("Zero plateau behaves like standard distance_to_alpha")
    func zeroPlateau() {
        let fadeWidth: Float = 5

        let withPlateau = distanceToAlphaWithPlateau(dist: -2.5, plateauWidth: 0, fadeWidth: fadeWidth)

        #expect(Swift.abs(withPlateau - 0.5) < 0.1, "Zero plateau should match standard behavior")
    }
}

// MARK: - Fast Power Function Tests

@Suite("Fast Power Function Tests")
struct FastPowTests {

    /// Swift implementation of fast_pow for verification.
    func fastPow(_ x: Float, _ n: Float) -> Float {
        if x <= 0 { return 0 }
        if x == 0 && n == 0 { return 1 }
        if n == 0 { return 1 }
        if n == 1 { return x }
        if n == 2 { return x * x }

        let safeN = min(max(n, 0), 100)
        return pow(min(max(x, 1e-6), 1e6), safeN)
    }

    @Test("x^0 = 1")
    func zeroExponent() {
        #expect(abs(fastPow(5, 0) - 1) < 0.001)
        #expect(abs(fastPow(0.5, 0) - 1) < 0.001)
    }

    @Test("x^1 = x")
    func oneExponent() {
        #expect(abs(fastPow(5, 1) - 5) < 0.001)
        #expect(abs(fastPow(0.5, 1) - 0.5) < 0.001)
    }

    @Test("x^2 = x*x")
    func squareExponent() {
        #expect(abs(fastPow(3, 2) - 9) < 0.001)
        #expect(abs(fastPow(0.5, 2) - 0.25) < 0.001)
    }

    @Test("Negative base returns 0")
    func negativeBase() {
        #expect(fastPow(-5, 2) == 0)
        #expect(fastPow(-1, 3) == 0)
    }

    @Test("Zero base returns 0 (except 0^0)")
    func zeroBase() {
        #expect(fastPow(0, 2) == 0)
        #expect(fastPow(0, 5) == 0)
    }

    @Test("Fractional exponent works")
    func fractionalExponent() {
        let result = fastPow(4, 0.5)
        #expect(abs(result - 2) < 0.01, "4^0.5 should be 2, got \(result)")
    }
}
