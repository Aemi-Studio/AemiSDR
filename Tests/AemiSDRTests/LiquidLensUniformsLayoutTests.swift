//
//  LiquidLensUniformsLayoutTests.swift
//  AemiSDRTests
//

import Testing
@testable import AemiSDR

@Suite("LiquidLensUniforms Layout")
struct LiquidLensUniformsLayoutTests {

    /// `LiquidLensUniforms` must match the Metal-side struct byte-for-byte.
    /// When this fails, the Metal `LiquidLensUniforms` struct in `LiquidLens.metal`
    /// must be updated to match.
    @Test func uniformsStrideIs88() {
        #expect(MemoryLayout<LiquidLensUniforms>.stride == 88)
    }

    @Test func uniformsLazyStrideMatches() {
        #expect(LiquidLensUniforms._stride == 88)
    }

    /// Pin every field's offset so a reorder is caught even if stride happens
    /// to stay 88. Matches the Metal struct order in `LiquidLens.metal`.
    @Test func uniformsFieldOffsets() {
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.center) == 0)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.textureSize) == 8)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.halfSize) == 16)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.strength) == 24)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.lensCurvature) == 28)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.cornerRadius) == 32)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.falloffType) == 36)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.falloffLength) == 40)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.falloffIntensity) == 44)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.chromaticAmount) == 48)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.materialType) == 52)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.overlayMode) == 56)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.refractiveIndexRed) == 60)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.refractiveIndexGreen) == 64)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.refractiveIndexBlue) == 68)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.deviationRed) == 72)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.deviationGreen) == 76)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.deviationBlue) == 80)
    }
}
