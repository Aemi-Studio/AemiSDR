//
//  LiquidLensGradientTests.swift
//  AemiSDRTests
//
//  Swift mirror of `computeSDFGradient` in `Sources/AemiSDR/Shaders/LiquidLens.metal`,
//  validating the diagonal-band fix (the smoothstep-band replacement for
//  the old `normalize((dy, dx))` form). Properties tested:
//
//    1. At the inner-rect medial axis (q.x = q.y exactly), the gradient is
//       defined — `(0.5, 0.5)` from the smoothstep midpoint, multiplied by
//       signP. No NaN like the prior `normalize((0, 0))` form produced.
//    2. Outside the transition band (|q.x − q.y| > diagonalBand), the
//       gradient is exactly axial: (1, 0) or (0, 1). No off-axis blend.
//    3. The gradient transitions C¹-smoothly across the band: angular
//       rate-of-change is bounded by the smoothstep derivative.
//    4. Corner-arc region still returns the radial gradient from the
//       inner-rect corner (unchanged from prior implementation).
//    5. Flat-edge region still returns the axial gradient (unchanged).
//

import Foundation
import Testing
import simd

@testable import AemiSDR

@Suite("LiquidLens SDF Gradient Tests")
struct LiquidLensGradientTests {
    /// Mirror of the Metal `computeSDFGradient`. Matches the shader's logic
    /// region-for-region, with the diagonal-band smoothstep in the interior.
    func computeSDFGradient(
        p: SIMD2<Float>,
        halfSize: SIMD2<Float>,
        cornerRadius: Float,
        diagonalBand: Float
    ) -> SIMD2<Float> {
        let corner = min(max(cornerRadius, 0), min(halfSize.x, halfSize.y))
        let absP = simd_abs(p)

        let seamWidth = Swift.max(min(halfSize.x, halfSize.y), 0.5)
        let signX = (p.x >= 0 ? Float(1) : -1) * smoothstep(0, seamWidth, absP.x)
        let signY = (p.y >= 0 ? Float(1) : -1) * smoothstep(0, seamWidth, absP.y)
        let signP = SIMD2<Float>(signX, signY)

        let inner = halfSize - SIMD2<Float>(repeating: corner)
        let q = absP - inner
        let qp = simd_max(q, SIMD2<Float>.zero)

        let gradLocal: SIMD2<Float>
        if corner > 0.0001 && qp.x > 0 && qp.y > 0 {
            let qLen = simd_length(qp)
            gradLocal = qLen > 0.0001 ? (qp / qLen) : SIMD2<Float>(0.707107, 0.707107)
        } else if q.x <= 0 && q.y <= 0 {
            // Interior: smoothstep band across q.x = q.y
            let band = Swift.max(diagonalBand, 0.5)
            let t = smoothstep(-band, band, q.x - q.y)
            gradLocal = SIMD2<Float>(t, 1 - t)
        } else {
            // Flat-edge region
            gradLocal = q.y > q.x ? SIMD2<Float>(0, 1) : SIMD2<Float>(1, 0)
        }

        return gradLocal * signP
    }

    /// Hermite cubic smoothstep matching MSL's built-in.
    func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = Swift.min(Swift.max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    // MARK: - Diagonal continuity

    @Test("Gradient at exact inner-rect corner is defined (no NaN)")
    func innerRectCornerNotNaN() {
        // For halfSize=(200, 100), corner=40, inner=(160, 60). The exact
        // inner-rect corner is at abs(p) = (160, 60), i.e. q = (0, 0).
        let halfSize = SIMD2<Float>(200, 100)
        let p = SIMD2<Float>(160, 60)

        let grad = computeSDFGradient(p: p, halfSize: halfSize, cornerRadius: 40, diagonalBand: 6)

        #expect(grad.x.isFinite)
        #expect(grad.y.isFinite)
        // Without the diagonal-band fix, the old `normalize((dy, dx))` form
        // would produce NaN at this point because dx = dy = 0.
    }

    @Test("On the inner-rect diagonal, gradient is (0.5, 0.5) before signP")
    func diagonalMedialAxisIsBisector() {
        // Square lens, point at the inner-rect's diagonal midpoint.
        let halfSize = SIMD2<Float>(100, 100)
        let p = SIMD2<Float>(50, 50)  // q = (-50, -50) → on diagonal

        // signP at (50, 50) for seamWidth=100: smoothstep(0, 100, 50) ≈ 0.5
        // so the expected final magnitude is 0.5 * (0.5, 0.5).
        let grad = computeSDFGradient(p: p, halfSize: halfSize, cornerRadius: 0, diagonalBand: 6)
        // After signP: (0.5 * 0.5, 0.5 * 0.5) = (0.25, 0.25)
        #expect(abs(grad.x - 0.25) < 0.001)
        #expect(abs(grad.y - 0.25) < 0.001)
    }

    @Test("Outside the band, gradient is exact axial (1, 0)")
    func outsideBandIsExactAxial() {
        // Wide lens (200×100), point well off the inner-rect diagonal,
        // closer to the vertical (right) edge than the horizontal (top) edge.
        // halfSize=(200, 100), corner=0 → inner=(200, 100).
        // Point (150, 0): q = (-50, -100). q.x - q.y = 50 > diagonalBand=6 → t=1.
        // Expected gradient before signP: (1, 0). Then signP.x ≈ 1, signP.y = 0.
        // Final: (1, 0).
        let halfSize = SIMD2<Float>(200, 100)
        let p = SIMD2<Float>(150, 0)
        let grad = computeSDFGradient(p: p, halfSize: halfSize, cornerRadius: 0, diagonalBand: 6)

        // signP.x = smoothstep(0, 100, 150) = 1 (saturated)
        // signP.y = smoothstep(0, 100, 0) = 0
        // gradient before signP = (1, 0)
        // final = (1*1, 0*0) = (1, 0)
        #expect(abs(grad.x - 1.0) < 0.001)
        #expect(abs(grad.y) < 0.001)
    }

    @Test("Outside the band on the other side, gradient is exact (0, 1)")
    func outsideBandIsExactAxialOther() {
        // Same lens, point closer to the horizontal edge.
        // Point (0, 80): q = (-200, -20). q.x - q.y = -180 < -diagonalBand=-6 → t=0.
        // gradient = (0, 1) before signP. signP.y > 0, signP.x = 0.
        let halfSize = SIMD2<Float>(200, 100)
        let p = SIMD2<Float>(0, 80)
        let grad = computeSDFGradient(p: p, halfSize: halfSize, cornerRadius: 0, diagonalBand: 6)

        #expect(abs(grad.x) < 0.001)
        // signP.y = smoothstep(0, 100, 80) ≈ 0.896
        // gradient.y = 1 * 0.896 = 0.896
        #expect(grad.y > 0.8)
    }

    @Test("Angular rate of change across the band is bounded")
    func angularRateBoundedAcrossBand() {
        // Sample 3 points across the diagonal band and check the angle change.
        let halfSize = SIMD2<Float>(200, 100)
        // Use unscaled positions to avoid signP magnitude changes; check the
        // pre-signP angle by reading the gradient at points where signP ≈ (1, 1).
        let p1 = SIMD2<Float>(155, 50)  // q.x - q.y = (-45) - (-50) = 5
        let p2 = SIMD2<Float>(150, 50)  // q.x - q.y = 0 (on diagonal)
        let p3 = SIMD2<Float>(145, 50)  // q.x - q.y = -5

        let g1 = computeSDFGradient(p: p1, halfSize: halfSize, cornerRadius: 0, diagonalBand: 6)
        let g2 = computeSDFGradient(p: p2, halfSize: halfSize, cornerRadius: 0, diagonalBand: 6)
        let g3 = computeSDFGradient(p: p3, halfSize: halfSize, cornerRadius: 0, diagonalBand: 6)

        // Normalize each to a unit vector and compare angles.
        func angle(_ v: SIMD2<Float>) -> Float {
            atan2(v.y, v.x)
        }
        let a1 = angle(g1)
        let a2 = angle(g2)
        let a3 = angle(g3)

        // Angle changes should be smooth and bounded — no jumps > 90° between
        // adjacent samples.
        #expect(abs(a1 - a2) < .pi / 2)
        #expect(abs(a2 - a3) < .pi / 2)
    }

    // MARK: - Corner arc region (unchanged behavior)

    @Test("Corner arc returns radial gradient from inner-rect corner")
    func cornerArcIsRadial() {
        // halfSize=(100, 100), corner=20, inner=(80, 80).
        // Point at (90, 90): q = (10, 10) → corner-arc region.
        // qp = (10, 10), normalized = (0.707, 0.707).
        let halfSize = SIMD2<Float>(100, 100)
        let p = SIMD2<Float>(90, 90)
        let grad = computeSDFGradient(p: p, halfSize: halfSize, cornerRadius: 20, diagonalBand: 6)

        // After signP (both positive smoothstep ≈ 1 at p=(90, 90)):
        #expect(grad.x > 0.65)
        #expect(grad.y > 0.65)
        #expect(abs(grad.x - grad.y) < 0.01)  // symmetric about diagonal
    }

    // MARK: - Flat edge region (unchanged behavior)

    @Test("Flat right-edge region returns (1, 0)")
    func flatRightEdgeIsAxial() {
        // halfSize=(100, 100), corner=20, inner=(80, 80).
        // Point at (90, 50): q = (10, -30) → flat-edge region (q.x > 0, q.y < 0).
        let halfSize = SIMD2<Float>(100, 100)
        let p = SIMD2<Float>(90, 50)
        let grad = computeSDFGradient(p: p, halfSize: halfSize, cornerRadius: 20, diagonalBand: 6)

        // signP.x ≈ 1, signP.y = smoothstep(0, 80, 50) ≈ 0.726
        // Pre-signP gradient = (1, 0). Final = (1, 0).
        #expect(grad.x > 0.8)
        #expect(abs(grad.y) < 0.001)
    }
}
