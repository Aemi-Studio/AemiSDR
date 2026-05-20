//
//  LiquidLensSnellTests.swift
//  AemiSDRTests
//

import Testing
import simd

@testable import AemiSDR

@Suite("LiquidLens Refraction Precompute")
struct LiquidLensSnellTests {
    /// For every shipping material, the CPU-side precompute should produce
    /// finite refractive indices and airOver ratios. A regression here (NaN,
    /// Inf, division-by-zero, sign flip) would silently produce a flat or
    /// flipped-displacement lens.
    @Test(arguments: [
        LiquidLensMaterial.crownGlass,
        LiquidLensMaterial.flintGlass,
        LiquidLensMaterial.water,
        LiquidLensMaterial.acrylic,
        LiquidLensMaterial.diamond,
    ])
    func uniformsAreFinite(material: LiquidLensMaterial) {
        let config = LiquidLensConfiguration(
            halfSize: SIMD2(100, 100),
            lensCurvature: 1.0,
            material: material
        )
        let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)

        #expect(uniforms.refractiveIndex.x.isFinite)
        #expect(uniforms.refractiveIndex.y.isFinite)
        #expect(uniforms.refractiveIndex.z.isFinite)
        #expect(uniforms.airOver.x.isFinite)
        #expect(uniforms.airOver.y.isFinite)
        #expect(uniforms.airOver.z.isFinite)
        #expect(uniforms.spectralAirOver0.isFinite)
        #expect(uniforms.spectralAirOver1.isFinite)

        // All real materials are denser than air → n ≥ 1, so n_air / n ≤ 1.
        #expect(uniforms.refractiveIndex.x >= 1.0)
        #expect(uniforms.refractiveIndex.y >= 1.0)
        #expect(uniforms.refractiveIndex.z >= 1.0)
        #expect(uniforms.airOver.x > 0 && uniforms.airOver.x <= 1.0)
        #expect(uniforms.airOver.y > 0 && uniforms.airOver.y <= 1.0)
        #expect(uniforms.airOver.z > 0 && uniforms.airOver.z <= 1.0)
    }

    /// Normal dispersion: n_blue > n_green > n_red, so the eta ratios used by
    /// `refract()` follow `airOverBlue < airOverGreen < airOverRed`. The shader
    /// then produces larger refraction for blue (correct chromatic ordering).
    @Test func normalDispersionOrdering() {
        let config = LiquidLensConfiguration(
            halfSize: SIMD2(100, 100),
            lensCurvature: 1.0,
            material: .water
        )
        let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)

        // Eta ratios: smaller eta → more refraction. So airOverBlue is the
        // smallest, airOverRed the largest, for any normally-dispersive medium.
        #expect(uniforms.airOver.z < uniforms.airOver.y)
        #expect(uniforms.airOver.y < uniforms.airOver.x)

        // Refractive index ordering: blue > green > red.
        #expect(uniforms.refractiveIndex.z > uniforms.refractiveIndex.y)
        #expect(uniforms.refractiveIndex.y > uniforms.refractiveIndex.x)
    }

    /// Zero curvature → zero per-fragment displacement (shader-side property).
    /// CPU side, lensCurvature is clamped and stored as-is.
    @Test func zeroCurvatureClamps() {
        let config = LiquidLensConfiguration(
            halfSize: SIMD2(100, 100),
            lensCurvature: 0.0,
            material: .water
        )
        let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)
        #expect(uniforms.lensCurvature == 0)
        // airOver values are still non-zero (they're material constants), but
        // the shader's `sinTheta = normalizedRadius * lensCurvature = 0` makes
        // `refract()` return a straight-through ray with T.xy = 0 → no displacement.
        #expect(uniforms.airOver.y > 0)
    }

    /// Diamond's exact refractive index after fixing the Sellmeier C-coefficients.
    /// Pre-fix the code produced n≈2.84 at 546 nm; the canonical Peter (1923)
    /// formula gives ≈2.42. This test pins the corrected behavior.
    @Test func diamondHasCorrectRefractiveIndex() {
        let config = LiquidLensConfiguration(
            halfSize: SIMD2(100, 100),
            lensCurvature: 1.0,
            material: .diamond
        )
        let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)
        // Real diamond at 546 nm ≈ 2.430. Allow ±0.05 for the 2-term fit.
        #expect(abs(uniforms.refractiveIndex.y - 2.42) < 0.05)
    }

    /// Water's 4-term Daimon-Masumura fit improves accuracy in the visible
    /// vs the 3-term truncation. Pins the post-fix value near the published
    /// refractive index of water at 546 nm.
    @Test func waterHasCorrectRefractiveIndex() {
        let config = LiquidLensConfiguration(
            halfSize: SIMD2(100, 100),
            lensCurvature: 1.0,
            material: .water
        )
        let uniforms = config.toUniforms(textureSize: SIMD2(200, 200), scale: 1)
        // Real water at 546 nm ≈ 1.3345.
        #expect(abs(uniforms.refractiveIndex.y - 1.3345) < 0.01)
    }
}
