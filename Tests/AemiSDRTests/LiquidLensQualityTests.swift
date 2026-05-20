//
//  LiquidLensQualityTests.swift
//  AemiSDRTests
//

import Testing

@testable import AemiSDR

@Suite("LiquidLensQuality preset mapping")
struct LiquidLensQualityTests {
    @Test("fastest disables all opt-in physical features")
    func fastestDisablesAllOptIns() {
        let q: LiquidLensQuality = .fastest
        #expect(!q.usesHighFidelityRefraction)
        #expect(!q.usesFresnel)
        #expect(!q.usesSpectral)
        #expect(!q.usesAspheric)
    }

    @Test("balanced disables all opt-in physical features")
    func balancedDisablesAllOptIns() {
        let q: LiquidLensQuality = .balanced
        #expect(!q.usesHighFidelityRefraction)
        #expect(!q.usesFresnel)
        #expect(!q.usesSpectral)
        #expect(!q.usesAspheric)
    }

    @Test("high enables 3D refract + fresnel only")
    func highEnablesRefractAndFresnel() {
        let q: LiquidLensQuality = .high
        #expect(q.usesHighFidelityRefraction)
        #expect(q.usesFresnel)
        #expect(!q.usesSpectral)
        #expect(!q.usesAspheric)
    }

    @Test("maximum enables every opt-in physical feature")
    func maximumEnablesEverything() {
        let q: LiquidLensQuality = .maximum
        #expect(q.usesHighFidelityRefraction)
        #expect(q.usesFresnel)
        #expect(q.usesSpectral)
        #expect(q.usesAspheric)
    }

    #if os(iOS)
        @Test("captureScale is monotonically non-decreasing across tiers")
        func captureScaleMonotonic() {
            // `captureScale` lives in the iOS-only extension because it returns
            // `CGFloat` (which exists on iOS); the value tier-mapping is
            // identical across platforms but the type is iOS-specific.
            #expect(LiquidLensQuality.fastest.captureScale <= LiquidLensQuality.balanced.captureScale)
            #expect(LiquidLensQuality.balanced.captureScale <= LiquidLensQuality.high.captureScale)
            #expect(LiquidLensQuality.high.captureScale <= LiquidLensQuality.maximum.captureScale)
        }
    #endif

    @Test("apply mutates LiquidLensConfiguration flags")
    func applyMutatesLensConfig() {
        var config = LiquidLensConfiguration()
        config.apply(.maximum)
        #expect(config.enableHighFidelityRefraction)
        #expect(config.enableFresnel)
        #expect(config.enableSpectral)
        #expect(config.enableAspheric)

        config.apply(.fastest)
        #expect(!config.enableHighFidelityRefraction)
        #expect(!config.enableFresnel)
        #expect(!config.enableSpectral)
        #expect(!config.enableAspheric)
    }

    #if os(iOS)
        @Test("apply on LiquidGlassConfiguration sets flags and captureScale")
        func applyMutatesGlassConfig() {
            // `LiquidGlassConfiguration` is the high-level iOS wrapper around
            // the lens. Quality presets here also drive the source capture
            // scale, since the wrapper owns that knob.
            var glass = LiquidGlassConfiguration()
            glass.apply(.maximum)
            #expect(glass.enableHighFidelityRefraction)
            #expect(glass.enableFresnel)
            #expect(glass.enableSpectral)
            #expect(glass.enableAspheric)
            #expect(glass.captureScale == 1.0)

            glass.apply(.fastest)
            #expect(!glass.enableHighFidelityRefraction)
            #expect(glass.captureScale == 0.25)
        }
    #endif

    @Test("apply does not touch unrelated fields")
    func applyLeavesUnrelatedFieldsIntact() {
        var config = LiquidLensConfiguration(strength: 0.7, chromaticAmount: 22)
        config.apply(.high)
        #expect(config.strength == 0.7)
        #expect(config.chromaticAmount == 22)
    }
}
