//
//  MaskCacheTests.swift
//  AemiSDRTests
//

import Foundation
import Testing

@testable import AemiSDR

@Suite("MaskCacheKey quantization")
struct MaskCacheKeyTests {
    @Test func identicalInputsProduceEqualKeys() {
        let a = MaskCacheKey.make(
            size: CGSize(width: 100, height: 200),
            scale: 2.0,
            maskType: .linearTopToBottom,
            startOffset: 0.5,
            cornerRadius: 12,
            fadeWidth: 16,
            inverted: false
        )
        let b = MaskCacheKey.make(
            size: CGSize(width: 100, height: 200),
            scale: 2.0,
            maskType: .linearTopToBottom,
            startOffset: 0.5,
            cornerRadius: 12,
            fadeWidth: 16,
            inverted: false
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func subQuantizationDifferenceCollapses() {
        // Quantization precision is 10_000, so differences below 1/10_000
        // should land in the same bucket.
        let a = MaskCacheKey.make(
            size: CGSize(width: 100, height: 200),
            scale: 2.0,
            maskType: .linearTopToBottom,
            startOffset: 0.5,
            cornerRadius: 12.0,
            fadeWidth: 16,
            inverted: false
        )
        let b = MaskCacheKey.make(
            size: CGSize(width: 100, height: 200),
            scale: 2.0,
            maskType: .linearTopToBottom,
            startOffset: 0.5 + 1e-5,
            cornerRadius: 12.0 + 1e-5,
            fadeWidth: 16,
            inverted: false
        )
        #expect(a == b)
    }

    @Test func invertedFlagDiscriminates() {
        let inv = MaskCacheKey.make(
            size: CGSize(width: 100, height: 200),
            scale: 2.0,
            maskType: .linearTopToBottom,
            startOffset: 0.5,
            cornerRadius: 12,
            fadeWidth: 16,
            inverted: true
        )
        let normal = MaskCacheKey.make(
            size: CGSize(width: 100, height: 200),
            scale: 2.0,
            maskType: .linearTopToBottom,
            startOffset: 0.5,
            cornerRadius: 12,
            fadeWidth: 16,
            inverted: false
        )
        #expect(inv != normal)
    }

    @Test func zeroSizeFloorsToOnePixel() {
        let key = MaskCacheKey.make(
            size: .zero,
            scale: 1.0,
            maskType: .uniform,
            startOffset: 0,
            cornerRadius: 0,
            fadeWidth: 0,
            inverted: false
        )
        // Implementation rounds (size * scale) up to at least 1.
        #expect(key.widthPx == 1)
        #expect(key.heightPx == 1)
    }
}
