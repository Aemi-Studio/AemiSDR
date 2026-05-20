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
    @Test func uniformsStrideIs104() {
        #expect(MemoryLayout<LiquidLensUniforms>.stride == 104)
    }

    @Test func uniformsLazyStrideMatches() {
        #expect(LiquidLensUniforms._stride == 104)
    }

    /// Pin every field's offset so a reorder is caught even if stride happens
    /// to stay 104. Matches the Metal struct order in `LiquidLens.metal`.
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
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.airOverRed) == 72)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.airOverGreen) == 76)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.airOverBlue) == 80)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.diagonalBand) == 84)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.asphericK2) == 88)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.asphericK4) == 92)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.spectralAirOver0) == 96)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.spectralAirOver1) == 100)
    }
}
