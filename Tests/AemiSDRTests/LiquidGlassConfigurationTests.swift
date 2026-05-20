//
//  LiquidGlassConfigurationTests.swift
//  AemiSDRTests
//

#if os(iOS)
    import Testing
    @testable import AemiSDR

    @Suite("LiquidGlassConfiguration clamping")
    struct LiquidGlassConfigurationTests {
        @Test func refreshRateClampsToFloor() {
            var config = LiquidGlassConfiguration()
            config.refreshRate = 0
            #expect(config.refreshRate == 1)
            config.refreshRate = -10
            #expect(config.refreshRate == 1)
        }

        @Test func refreshRateClampsToCeiling() {
            var config = LiquidGlassConfiguration()
            config.refreshRate = 200
            #expect(config.refreshRate == 120)
        }

        @Test func refreshRateInRangePassesThrough() {
            var config = LiquidGlassConfiguration()
            config.refreshRate = 60
            #expect(config.refreshRate == 60)
        }

        @Test func captureScaleClampsToFloor() {
            var config = LiquidGlassConfiguration()
            config.captureScale = 0.1
            #expect(config.captureScale == 0.25)
            config.captureScale = -1.0
            #expect(config.captureScale == 0.25)
        }

        @Test func captureScaleClampsToCeiling() {
            var config = LiquidGlassConfiguration()
            config.captureScale = 10.0
            #expect(config.captureScale == 3.0)
        }

        @Test func captureScaleInRangePassesThrough() {
            var config = LiquidGlassConfiguration()
            config.captureScale = 1.5
            #expect(config.captureScale == 1.5)
        }

        /// Two configurations that render identically (after clamping) should
        /// compare equal and hash identically. Prior to the didSet clamp, hashing
        /// over the raw value caused (refreshRate: 0) ≠ (refreshRate: 1).
        @Test func clampedEqualityHash() {
            let a = LiquidGlassConfiguration(refreshRate: 0)
            let b = LiquidGlassConfiguration(refreshRate: 1)
            #expect(a == b)
            #expect(a.hashValue == b.hashValue)
        }
    }
#endif
