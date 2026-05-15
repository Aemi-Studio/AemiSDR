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
}
