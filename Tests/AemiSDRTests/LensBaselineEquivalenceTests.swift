//
//  LensBaselineEquivalenceTests.swift
//  AemiSDRTests
//
//  A performance change must not change a pixel. Every lens variant is rendered with the frozen baseline shader
//  (Verification/Reference/LiquidLensBaseline.metal) and with the working tree, and the two must agree. A deliberate
//  visual change re-freezes the baseline; an optimisation never does. Roadmap 0019 step 5.
//

#if os(macOS)
    import Foundation
    import Metal
    import Testing

    @testable import AemiSDR

    @Suite(
        "An optimised lens draws what the frozen baseline draws",
        .enabled(if: MTLCreateSystemDefaultDevice() != nil, "Requires a Metal device"))
    struct LensBaselineEquivalenceTests {
        private static let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        private func library(_ device: MTLDevice, _ path: String) throws -> MTLLibrary {
            try device.makeLibrary(
                source: String(contentsOf: Self.root.appending(path: path), encoding: .utf8), options: nil)
        }

        @Test(arguments: ShippedShaderTests.variants.map(\.name))
        func `every variant renders the same pixels as the baseline`(name: String) throws {
            let configuration = try #require(ShippedShaderTests.variants.first { $0.name == name }).configuration
            let device = try #require(MTLCreateSystemDefaultDevice())
            let source = try ShippedShaderTests.sourceTexture(device)
            let baseline = try ShippedShaderTests.render(
                library: library(device, "Verification/Reference/LiquidLensBaseline.metal"),
                configuration: configuration,
                device: device, source: source)
            let tree = try ShippedShaderTests.render(
                library: library(device, "Sources/AemiSDR/Shaders/LiquidLens.metal"), configuration: configuration,
                device: device, source: source)
            var largest = 0
            for index in baseline.pixels.indices {
                largest = max(largest, abs(Int(baseline.pixels[index]) - Int(tree.pixels[index])))
            }
            #expect(baseline.pixels.contains { $0 != 0 }, "the scene must draw something, or equality is vacuous")
            #expect(largest <= 1, "\(name): the working tree differs from the baseline by \(largest)/255")
        }

        /// The test can fail: a change to the shader that alters the image is seen.
        @Test func `a visible change is detected`() throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let configuration = try #require(ShippedShaderTests.variants.first { $0.name == "spectral" }).configuration
            let baselineSource = try String(
                contentsOf: Self.root.appending(path: "Verification/Reference/LiquidLensBaseline.metal"),
                encoding: .utf8)
            let mutated = baselineSource.replacingOccurrences(
                of: "{ 0.400f, 0.045f, 0.010f },", with: "{ 0.300f, 0.045f, 0.010f },")
            try #require(mutated != baselineSource, "the mutation target moved")
            let source = try ShippedShaderTests.sourceTexture(device)
            let reference = try ShippedShaderTests.render(
                library: library(device, "Verification/Reference/LiquidLensBaseline.metal"),
                configuration: configuration,
                device: device, source: source)
            let changed = try ShippedShaderTests.render(
                library: device.makeLibrary(source: mutated, options: nil), configuration: configuration,
                device: device,
                source: source)
            var largest = 0
            for index in reference.pixels.indices {
                largest = max(largest, abs(Int(reference.pixels[index]) - Int(changed.pixels[index])))
            }
            #expect(largest > 2, "a spectral weight changed and no pixel moved: the equivalence test is blind")
        }
    }
#endif
