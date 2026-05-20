//
//  LiquidLensUniformsLayoutTests.swift
//  AemiSDRTests
//

import Testing

@testable import AemiSDR

@Suite("LiquidLensUniforms Layout")
struct LiquidLensUniformsLayoutTests {
    /// The Swift `LiquidLensUniforms` must match the Metal struct byte-for-byte.
    /// The 112-byte stride is set by `SIMD3<Float>` alignment (16 bytes) on
    /// the trailing `airOver` / `deviation` triplets.
    @Test func uniformsStrideIs112() {
        #expect(MemoryLayout<LiquidLensUniforms>.stride == 112)
    }

    @Test func uniformsLazyStrideMatches() {
        #expect(LiquidLensUniforms._stride == 112)
    }

    /// Pin every field's offset so a reorder is caught even if stride happens
    /// to stay 112. Field order must match the Metal struct in `LiquidLens.metal`.
    @Test func uniformsFieldOffsets() {
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.center) == 0)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.textureSize) == 8)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.halfSize) == 16)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.strength) == 24)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.lensCurvature) == 28)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.cornerRadius) == 32)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.falloffLength) == 36)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.falloffIntensity) == 40)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.chromaticAmount) == 44)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.overlayMode) == 48)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.diagonalBand) == 52)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.asphericK2) == 56)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.asphericK4) == 60)
        // SIMD3<Float> fields occupy 16-byte slots; they are 16-byte aligned
        // and Swift pads the field to 16 bytes even though the data is 12.
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.airOver) == 64)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.deviation) == 80)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.spectralAirOver0) == 96)
        #expect(MemoryLayout<LiquidLensUniforms>.offset(of: \.spectralAirOver1) == 100)
    }
}
