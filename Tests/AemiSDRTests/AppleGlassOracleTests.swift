//
//  AppleGlassOracleTests.swift
//  AemiSDRTests
//
//  The reference glass geometry (Verification/Reference/GlassSDFReference.metal) must draw what Apple's
//  glass_foreground_sdf draws. Apple's shader is the ground truth, read from the installed simulator runtime. ADR-0007.
//

#if os(macOS)
    import Foundation
    import Metal
    import Testing

    private let appleLibrary = AppleGlassOracle.appleLibraryURL()

    @Suite(
        "The reference glass geometry draws what Apple's shader draws",
        .enabled(
            if: MTLCreateSystemDefaultDevice() != nil && appleLibrary != nil,
            "Needs a Metal device and an installed iOS simulator runtime"))
    struct AppleGlassOracleTests {
        private func oracle() throws -> AppleGlassOracle {
            try AppleGlassOracle(appleLibrary: #require(appleLibrary))
        }

        /// Mode 1 and 3 are the plain box with an elliptical normal, 4 is one continuous corner, 5 is four corners.
        @Test(arguments: [1, 3, 4, 5])
        func `every field mode matches Apple's shader on random scenes`(mode: Int) throws {
            let result = try oracle().compare(
                mode: mode, cases: 24, seed: 0xA11CE + UInt64(mode), referenceSource: AppleGlassOracle.referenceSource)
            #expect(result.peak > 0.5, "the scene must draw something, or agreement is vacuous")
            #expect(
                result.largest < 2e-3,
                "mode \(mode): largest difference \(result.largest), \(result.off) values off by more than 1e-3")
        }

        /// Each mutation breaks one claim of the reference. If any of these still agreed, the oracle could not see
        /// that claim and its agreement above would mean less than it appears to.
        @Test(arguments: [
            ("the corner extent", "kContinuousExtent = 1.52866495f", "kContinuousExtent = 1.5f", 4),
            ("the squircle fit", "* t + 0.268530995f", "* t + 0.26f", 4),
            (
                "the half-precision rounding", "half rounded = half(f);",
                "half rounded = half(f); rounded = half(float(rounded) * 1.002f);", 4
            ),
            (
                "which radius owns which corner", "corner_distance(float2(-p.x, p.y), u.s0.xy, u.s2.x",
                "corner_distance(float2(-p.x, p.y), u.s0.xy, u.s2.w", 5
            ),
            ("the squircle on a negative radius", "* t + 0.268530995f", "* t + 0.26f", 5),
            ("the circle blend", "* 0.654165566f + 0.345834434f", "* 0.65f + 0.35f", 4),
        ])
        func `the oracle sees a change to`(claim: String, original: String, mutated: String, mode: Int) throws {
            let source = try AppleGlassOracle.referenceSource
            try #require(source.contains(original), "the mutation target moved: \(claim)")
            let result = try oracle().compare(
                mode: mode, cases: 24, seed: 0xBADC0DE + UInt64(mode),
                referenceSource: source.replacingOccurrences(of: original, with: mutated))
            #expect(result.largest > 0.01, "\(claim): a change went unseen (largest difference \(result.largest))")
        }
    }
#endif
