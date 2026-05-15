//
//  LiquidLensSnellTests.swift
//  AemiSDRTests
//

import Testing
import simd
@testable import AemiSDR

@Suite("LiquidLens Snell Precompute")
struct LiquidLensSnellTests {

    /// For every shipping material, the CPU-side Snell precompute should
    /// produce finite deviations and refractive indices. A regression here
    /// (NaN, Inf, division-by-zero, sign flip) would silently produce a
    /// no-displacement or flipped-displacement lens.
    @Test(arguments: [
        LiquidLensMaterial.crownGlass,
        LiquidLensMaterial.flintGlass,
        LiquidLensMaterial.water,
        LiquidLensMaterial.acrylic,
        LiquidLensMaterial.diamond,
    ])
    func deviationsAreFinite(material: LiquidLensMaterial) {
        let config = LiquidLensConfiguration(
            halfSize: SIMD2(100, 100),
            lensCurvature: 1.0,
            material: material
        )
        let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)

        #expect(uniforms.deviationRed.isFinite)
        #expect(uniforms.deviationGreen.isFinite)
        #expect(uniforms.deviationBlue.isFinite)
        #expect(uniforms.refractiveIndexRed.isFinite)
        #expect(uniforms.refractiveIndexGreen.isFinite)
        #expect(uniforms.refractiveIndexBlue.isFinite)

        // All real materials are denser than air → refractive index ≥ 1.
        #expect(uniforms.refractiveIndexRed >= 1.0)
        #expect(uniforms.refractiveIndexGreen >= 1.0)
        #expect(uniforms.refractiveIndexBlue >= 1.0)
    }

    /// Normal dispersion: blue light bends more than red. Verifying the sign
    /// + magnitude relationship between the three channel deviations catches
    /// a Sellmeier-coefficient transcription error.
    @Test func normalDispersionOrdering() {
        // Water has well-known dispersion; the deviation magnitudes should
        // follow |blue| > |green| > |red| for refraction from air into water.
        let config = LiquidLensConfiguration(
            halfSize: SIMD2(100, 100),
            lensCurvature: 1.0,
            material: .water
        )
        let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)

        let absRed = abs(uniforms.deviationRed)
        let absGreen = abs(uniforms.deviationGreen)
        let absBlue = abs(uniforms.deviationBlue)

        #expect(absBlue > absGreen)
        #expect(absGreen > absRed)
    }

    /// Zero curvature → zero displacement everywhere. The shader relies on
    /// this to skip refraction without an explicit `surfaceAngle < epsilon`
    /// branch (the precomputed deviations vanish naturally).
    @Test func zeroCurvatureProducesZeroDeviations() {
        let config = LiquidLensConfiguration(
            halfSize: SIMD2(100, 100),
            lensCurvature: 0.0,
            material: .water
        )
        let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)
        #expect(uniforms.deviationRed == 0)
        #expect(uniforms.deviationGreen == 0)
        #expect(uniforms.deviationBlue == 0)
    }
}
