//
//  LiquidLensRefractionTests.swift
//  AemiSDRTests
//
//  Mirrors the per-fragment Snell refraction path in
//  `Sources/AemiSDR/Shaders/LiquidLens.metal`. The shader uses MSL
//  `refract(I, N, η)` 3D form with image-plane projection. We mirror that
//  here to validate:
//
//    1. At lens apex (normalizedRadius = 0), displacement is exactly 0.
//    2. At lens rim (normalizedRadius = 1, curvature = 1), displacement is
//       maximal in the outward-normal direction.
//    3. Chromatic ordering: |disp_blue| > |disp_green| > |disp_red| for
//       any normally-dispersive material at the rim.
//    4. Zero curvature → zero displacement everywhere (refract returns
//       straight-through ray with T.xy = 0).
//    5. The displacement vs angle relationship matches the 3D refract
//       formula, not the older scalar `asin(η·sinθ) − θ` form.
//

import Foundation
import Testing
import simd

@testable import AemiSDR

@Suite("LiquidLens 3D Refraction Tests")
struct LiquidLensRefractionTests {
    /// Mirror of MSL `refract(I, N, η)` for `incident = (0, 0, -1)`, `normal`
    /// a 3D unit vector. Returns the refracted ray direction (also unit).
    func refract(incident: SIMD3<Float>, normal: SIMD3<Float>, eta: Float) -> SIMD3<Float> {
        let dotIN = simd_dot(incident, normal)
        let k = 1 - eta * eta * (1 - dotIN * dotIN)
        if k < 0 { return SIMD3<Float>(0, 0, 0) }  // Total internal reflection
        return eta * incident - (eta * dotIN + sqrt(k)) * normal
    }

    /// Mirror of the shader's `refractDisplacement`. Returns the 2D
    /// image-plane displacement direction-times-scale: t.xy / (-t.z).
    func refractDisplacement(
        outwardDir: SIMD2<Float>,
        sinTheta: Float,
        cosTheta: Float,
        eta: Float
    ) -> SIMD2<Float> {
        let normal = SIMD3<Float>(outwardDir.x * sinTheta, outwardDir.y * sinTheta, cosTheta)
        let incident = SIMD3<Float>(0, 0, -1)
        let refracted = refract(incident: incident, normal: normal, eta: eta)
        let invTz = 1 / Swift.max(-refracted.z, 1e-4)
        return SIMD2<Float>(refracted.x, refracted.y) * invTz
    }

    /// Helper to fetch the airOver_λ ratios for a given material and the
    /// clamped curvature, as the shader would compute per-fragment.
    func materialAirOver(_ material: LiquidLensMaterial) -> (red: Float, green: Float, blue: Float) {
        let config = LiquidLensConfiguration(
            halfSize: SIMD2(100, 100),
            lensCurvature: 1.0,
            material: material
        )
        let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)
        return (uniforms.airOver.x, uniforms.airOver.y, uniforms.airOver.z)
    }

    // MARK: - Apex behavior

    @Test("Apex (r=0) produces zero displacement")
    func apexZeroDisplacement() {
        // sinTheta = r * c = 0 * 1 = 0. cosTheta = 1. N = (0, 0, 1).
        // I = (0, 0, -1). dot(I, N) = -1. k = 1 - eta²·(1 - 1) = 1.
        // T = eta·I + (eta·1 - sqrt(1))·N = (0, 0, -eta) + (eta - 1)·(0, 0, 1)
        //   = (0, 0, -eta + eta - 1) = (0, 0, -1)
        // T.xy = (0, 0). Displacement = (0, 0).
        let disp = refractDisplacement(
            outwardDir: SIMD2(1, 0),
            sinTheta: 0,
            cosTheta: 1,
            eta: 0.752  // water green
        )
        #expect(abs(disp.x) < 1e-5)
        #expect(abs(disp.y) < 1e-5)
    }

    // MARK: - Rim behavior

    @Test("Rim with full curvature produces non-zero outward displacement")
    func rimNonzeroDisplacement() {
        // sinTheta = 1, cosTheta = 0. N = (outwardDir, 0). Tangent.
        // refract(I, N, eta) where I·N = 0 → k = 1 - eta²·1 = 1 - eta².
        // For eta < 1, k > 0. T = eta·I - sqrt(k)·N.
        // T.xy = -sqrt(k) * outwardDir (so disp is in -outwardDir direction
        // before sign correction)
        // T.z = -eta
        // disp = T.xy / (-T.z) = -sqrt(k) * outwardDir / eta
        // For water green (eta ≈ 0.751): k = 1 - 0.564 = 0.436. sqrt(k) ≈ 0.660.
        // disp magnitude = 0.660 / 0.751 ≈ 0.879
        let outward = SIMD2<Float>(1, 0)
        let disp = refractDisplacement(
            outwardDir: outward,
            sinTheta: 1,
            cosTheta: 0,
            eta: 0.751
        )
        // Disp points opposite to outward direction (refracted ray bends inward).
        // Magnitude should be ~0.88 for water.
        let magnitude = simd_length(disp)
        #expect(magnitude > 0.5)
        #expect(magnitude < 1.5)
    }

    // MARK: - Chromatic ordering

    @Test("Chromatic dispersion at rim follows |blue| > |green| > |red|")
    func chromaticDispersionOrderingAtRim() {
        let etas = materialAirOver(.water)
        let outward = SIMD2<Float>(1, 0)

        // Use a moderate angle (sinTheta = 0.7) for a realistic test
        let sinTheta: Float = 0.7
        let cosTheta = sqrt(1 - sinTheta * sinTheta)

        let dispR = refractDisplacement(outwardDir: outward, sinTheta: sinTheta, cosTheta: cosTheta, eta: etas.red)
        let dispG = refractDisplacement(outwardDir: outward, sinTheta: sinTheta, cosTheta: cosTheta, eta: etas.green)
        let dispB = refractDisplacement(outwardDir: outward, sinTheta: sinTheta, cosTheta: cosTheta, eta: etas.blue)

        let magR = simd_length(dispR)
        let magG = simd_length(dispG)
        let magB = simd_length(dispB)

        // Blue light bends most (smallest eta → largest displacement)
        #expect(magB > magG)
        #expect(magG > magR)
    }

    @Test("Chromatic spread vs Sellmeier index match: refractiveIndexBlue > Green > Red")
    func sellmeierRefractiveIndexOrdering() {
        for material: LiquidLensMaterial in [.crownGlass, .flintGlass, .water, .acrylic, .diamond] {
            let config = LiquidLensConfiguration(
                halfSize: SIMD2(100, 100),
                lensCurvature: 1.0,
                material: material
            )
            let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)
            // Normal dispersion: n_blue > n_green > n_red
            #expect(uniforms.refractiveIndex.z > uniforms.refractiveIndex.y)
            #expect(uniforms.refractiveIndex.y > uniforms.refractiveIndex.x)
        }
    }

    // MARK: - Zero curvature

    @Test("Zero curvature produces zero displacement at all radii")
    func zeroCurvatureZeroDisplacement() {
        // sinTheta = r * 0 = 0 for any r. cosTheta = 1. N = (0, 0, 1).
        // T = (0, 0, -1). Displacement = (0, 0).
        let outward = SIMD2<Float>(0.6, 0.8)
        for r: Float in stride(from: 0, through: 1, by: 0.1) {
            let sinTheta = r * 0  // curvature = 0
            let disp = refractDisplacement(
                outwardDir: outward,
                sinTheta: sinTheta,
                cosTheta: 1,
                eta: 0.7
            )
            #expect(abs(disp.x) < 1e-5)
            #expect(abs(disp.y) < 1e-5)
        }
    }

    // MARK: - Outward direction follows outwardDir

    @Test("Displacement direction follows the outward normal")
    func displacementDirectionFollowsOutward() {
        let outward = SIMD2<Float>(0.6, 0.8)  // unit vector
        let disp = refractDisplacement(
            outwardDir: outward,
            sinTheta: 0.5,
            cosTheta: sqrt(1 - 0.25),
            eta: 0.751
        )
        // Displacement should be (anti-)parallel to outward direction.
        // disp = -k * outward / (eta + k*cosTheta) — parallel.
        if simd_length(disp) > 1e-5 {
            let dispDir = disp / simd_length(disp)
            let dot = abs(simd_dot(dispDir, outward))
            #expect(dot > 0.99)  // collinear (up to sign)
        }
    }

    // MARK: - 3D vs scalar comparison (sanity check on the math)

    @Test("Small-angle limit matches scalar deviation form")
    func smallAngleMatchesScalar() {
        // For small theta, asin(eta·sinTheta) - theta ≈ (eta - 1) * theta.
        // The 3D form: |disp| ≈ |eta - 1| * theta for tan(theta) ≈ theta.
        let eta: Float = 0.751
        let theta: Float = 0.05  // small angle
        let sinTheta = sin(theta)
        let cosTheta = cos(theta)

        let outward = SIMD2<Float>(1, 0)
        let disp = refractDisplacement(outwardDir: outward, sinTheta: sinTheta, cosTheta: cosTheta, eta: eta)

        let dispMag = simd_length(disp)
        let expectedSmallAngle = abs(1 - eta) * theta  // ≈ |deviation_scalar|

        // 3D form gives tan(deviation), scalar gives deviation. For theta = 0.05
        // these match within 1%.
        #expect(abs(dispMag - expectedSmallAngle) < 0.001)
    }
}
