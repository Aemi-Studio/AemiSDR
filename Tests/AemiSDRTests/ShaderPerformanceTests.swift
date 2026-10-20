//
//  ShaderPerformanceTests.swift
//  AemiSDRTests
//
//  Opt-in GPU cost comparison (AEMI_BENCH=1): Apple's glass_foreground_sdf, run from the installed simulator runtime,
//  against our reference port of it, on the same GPU, target and pass count. Timing a GPU is easy to get wrong, so the
//  harness checks itself: a constant-colour floor pass is subtracted, blending keeps every overlapping fragment shaded,
//  and cost must scale linearly with the number of passes and with pixel area or the run is rejected.
//

#if os(macOS)
    import Foundation
    import Metal
    import Testing

    @testable import AemiSDR

    private let benchEnabled = ProcessInfo.processInfo.environment["AEMI_BENCH"] != nil
    private let benchLibrary = AppleGlassOracle.appleLibraryURL()

    private let floorSource = """
        #include <metal_stdlib>
        using namespace metal;
        struct Interpolants { float4 position [[position]]; float2 sdf_uv; float2 src_uv; };
        fragment float4 floor_pass(Interpolants in [[stage_in]]) { return float4(0.01f); }
        """

    @Suite(
        "Shader performance (opt-in)",
        .serialized,
        .enabled(if: benchEnabled && MTLCreateSystemDefaultDevice() != nil && benchLibrary != nil, "set AEMI_BENCH=1"))
    struct ShaderPerformanceTests {
        /// Median GPU milliseconds for one full-target pass, from `rounds` command buffers of `passes` draws each.
        private func millisecondsPerPass(
            _ oracle: AppleGlassOracle, pipeline: MTLRenderPipelineState, uniforms: [Float], source: MTLTexture,
            side: Int, passes: Int, rounds: Int = 25
        ) throws -> Double {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: side, height: side, mipmapped: false)
            descriptor.usage = [.renderTarget]
            descriptor.storageMode = .private
            let target = try #require(oracle.device.makeTexture(descriptor: descriptor))
            var samples: [Double] = []
            for round in 0..<rounds {
                let command = try #require(oracle.queue.makeCommandBuffer())
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = target
                pass.colorAttachments[0].loadAction = .clear
                pass.colorAttachments[0].storeAction = .store
                let encoder = try #require(command.makeRenderCommandEncoder(descriptor: pass))
                encoder.setRenderPipelineState(pipeline)
                oracle.bind(encoder, uniforms: uniforms, source: source, edr: 1)
                for _ in 0..<passes {
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                }
                encoder.endEncoding()
                command.commit()
                command.waitUntilCompleted()
                if round >= 5 { samples.append((command.gpuEndTime - command.gpuStartTime) * 1000 / Double(passes)) }
            }
            return samples.sorted()[samples.count / 2]
        }

        @Test func `Apple's glass foreground against our reference port`() throws {
            let oracle = try AppleGlassOracle(appleLibrary: #require(benchLibrary))
            var random = OracleRandom(state: 7)
            let source = try oracle.makeSource(&random)
            // A representative scene: one continuous corner (mode 4), both highlights live.
            var uniforms = AppleGlassOracle.uniforms(&random, mode: 4)
            uniforms[0] = 40
            uniforms[1] = 40
            uniforms[3] = 0
            uniforms[10] = 20
            uniforms[16] = 0.1
            uniforms[19] = 0.1
            func pipeline(_ library: MTLLibrary, _ fragment: String, vertex: String = "sdf_filter_vert_lpf") throws
                -> MTLRenderPipelineState
            {
                try AppleGlassOracle.pipeline(
                    device: oracle.device, vertexLibrary: oracle.apple, fragmentLibrary: library, fragment: fragment,
                    vertex: vertex, pixelFormat: .bgra8Unorm, blending: true)
            }
            let reference = try oracle.device.makeLibrary(source: AppleGlassOracle.referenceSource, options: nil)
            let floor = try oracle.device.makeLibrary(source: floorSource, options: nil)
            let contenders: [(String, MTLRenderPipelineState)] = [
                ("floor (constant colour)", try pipeline(floor, "floor_pass")),
                ("Apple glass_foreground_sdf (float)", try pipeline(oracle.apple, "glass_foreground_sdf_lpf")),
                (
                    "Apple glass_foreground_sdf (half)",
                    try pipeline(oracle.apple, "glass_foreground_sdf_lph", vertex: "sdf_filter_vert_lph")
                ),
                ("our reference port (float)", try pipeline(reference, "reference_glass_foreground_sdf")),
            ]

            // The harness must be trustworthy before any number is: linear in passes and in area.
            let probe = contenders[1].1
            let few = try millisecondsPerPass(
                oracle, pipeline: probe, uniforms: uniforms, source: source, side: 2048, passes: 8)
            let many = try millisecondsPerPass(
                oracle, pipeline: probe, uniforms: uniforms, source: source, side: 2048, passes: 32)
            let small = try millisecondsPerPass(
                oracle, pipeline: probe, uniforms: uniforms, source: source, side: 1024, passes: 32)
            print(
                String(
                    format: "BENCH harness: 8 passes %.3f ms/pass, 32 passes %.3f ms/pass, 1024^2 %.3f ms/pass", few,
                    many, small))
            #expect(abs(few / many - 1) < 0.25, "per-pass cost must not depend on the pass count")
            #expect(many / small > 2.5 && many / small < 5.5, "cost must scale with area (4x): got \(many / small)x")

            for (name, state) in contenders {
                let value = try millisecondsPerPass(
                    oracle, pipeline: state, uniforms: uniforms, source: source, side: 2048, passes: 32)
                print(String(format: "BENCH %-38@ %7.3f ms per 2048x2048 pass", name as NSString, value))
            }
        }

        // MARK: Our lens

        private func lensPipeline(
            _ library: MTLLibrary, _ configuration: LiquidLensConfiguration, device: MTLDevice
        ) throws -> MTLRenderPipelineState {
            let key = configuration.pipelineKey()
            let constants = MTLFunctionConstantValues()
            var chromatic = key.chromaticEnabled
            var falloff = key.falloffType
            var fresnel = key.enableFresnel
            var spectral = key.enableSpectral
            var aspheric = key.enableAspheric
            var highFidelity = key.highFidelityRefraction
            var thick = key.enableThickLens
            // Metal copies each value during the synchronous call.
            unsafe constants.setConstantValue(&chromatic, type: .bool, index: 0)
            unsafe constants.setConstantValue(&falloff, type: .int, index: 1)
            unsafe constants.setConstantValue(&fresnel, type: .bool, index: 2)
            unsafe constants.setConstantValue(&spectral, type: .bool, index: 3)
            unsafe constants.setConstantValue(&aspheric, type: .bool, index: 4)
            unsafe constants.setConstantValue(&highFidelity, type: .bool, index: 5)
            unsafe constants.setConstantValue(&thick, type: .bool, index: 6)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "liquidLensVertex")
            descriptor.fragmentFunction = try library.makeFunction(
                name: "liquidLensFragment", constantValues: constants)
            let attachment = descriptor.colorAttachments[0]
            attachment?.pixelFormat = .bgra8Unorm
            // Premultiplied "over" blending keeps every overlapping fragment shaded.
            attachment?.isBlendingEnabled = true
            attachment?.sourceRGBBlendFactor = .one
            attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment?.sourceAlphaBlendFactor = .one
            attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }

        /// Opt-in comparison of the working-tree lens shader against a saved baseline copy
        /// (AEMI_BENCH_LENS_BASELINE=/path/LiquidLens.metal), interleaved so background load cancels.
        @Test func `our lens variants, full and typical coverage`() throws {
            let oracle = try AppleGlassOracle(appleLibrary: #require(benchLibrary))
            let device = oracle.device
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let current = try device.makeLibrary(
                source: String(
                    contentsOf: root.appending(path: "Sources/AemiSDR/Shaders/LiquidLens.metal"), encoding: .utf8),
                options: nil)
            // A control, the baseline source compiled a second time, measures the noise of every comparison.
            let baselinePath = ProcessInfo.processInfo.environment["AEMI_BENCH_LENS_BASELINE"]
            let baselineSource =
                try baselinePath.map { try String(contentsOfFile: $0, encoding: .utf8) }
                ?? String(
                    contentsOf: root.appending(path: "Sources/AemiSDR/Shaders/LiquidLens.metal"), encoding: .utf8)
            let libraries: [(String, MTLLibrary)] = [
                ("baseline", try device.makeLibrary(source: baselineSource, options: nil)),
                ("control", try device.makeLibrary(source: baselineSource, options: nil)),
                ("tree", current),
            ]
            let side = 2048
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: side, height: side, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .private
            let target = try #require(device.makeTexture(descriptor: descriptor))
            var random = OracleRandom(state: 11)
            let source = try oracle.makeSource(&random)
            let sourceDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba16Float, width: side, height: side, mipmapped: false)
            sourceDescriptor.usage = [.shaderRead]
            let photo = try #require(device.makeTexture(descriptor: sourceDescriptor))
            _ = source
            // Incompressible content: a texture of zeros would compress perfectly and flatter the memory system.
            var texels = [Float16](repeating: 0, count: side * side * 4)
            for index in texels.indices { texels[index] = Float16(random.unit()) }
            // The array holds exactly side*side RGBA16F texels.
            unsafe photo.replace(
                region: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0, withBytes: texels, bytesPerRow: side * 8)

            for coverage in ["full", "typical"] {
                for variant in ShippedShaderTests.variants {
                    var configuration = variant.configuration
                    configuration.center = SIMD2(1024, 1024)
                    if coverage == "full" {
                        configuration.halfSize = SIMD2(1020, 1020)
                        configuration.cornerRadius = .points(300)
                    } else {
                        configuration.halfSize = SIMD2(420, 300)
                    }
                    var uniforms = configuration.toUniforms(textureSize: SIMD2(Float(side), Float(side)), scale: 1)
                    let states = try libraries.map { try lensPipeline($0.1, configuration, device: device) }
                    var samples = Array(repeating: [Double](), count: states.count)
                    for round in 0..<45 {
                        // Rotate who goes first so a warm-up or clock-ramp bias lands on every contender equally.
                        for step in 0..<states.count {
                            let index = (step + round) % states.count
                            let state = states[index]
                            let command = try #require(oracle.queue.makeCommandBuffer())
                            let pass = MTLRenderPassDescriptor()
                            pass.colorAttachments[0].texture = target
                            pass.colorAttachments[0].loadAction = .clear
                            pass.colorAttachments[0].storeAction = .store
                            let encoder = try #require(command.makeRenderCommandEncoder(descriptor: pass))
                            encoder.setRenderPipelineState(state)
                            encoder.setFragmentTexture(photo, index: 0)
                            // The uniform struct is copied by value into the command stream.
                            unsafe encoder.setFragmentBytes(
                                &uniforms, length: MemoryLayout<LiquidLensUniforms>.stride, index: 0)
                            for _ in 0..<16 {
                                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                            }
                            encoder.endEncoding()
                            command.commit()
                            command.waitUntilCompleted()
                            if round >= 5 {
                                samples[index].append((command.gpuEndTime - command.gpuStartTime) * 1000 / 16)
                            }
                        }
                    }
                    func median(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }
                    let base = median(samples[0])
                    // Paired ratios: each round's control and tree against that round's baseline.
                    let controlRatio = median(zip(samples[1], samples[0]).map { $0 / $1 })
                    let treeRatio = median(zip(samples[2], samples[0]).map { $0 / $1 })
                    print(
                        "LENS \(coverage) \(variant.name.padding(toLength: 32, withPad: " ", startingAt: 0)) baseline \(String(format: "%.3f", base)) ms   control x\(String(format: "%.3f", controlRatio))   tree x\(String(format: "%.3f", treeRatio))"
                    )
                }
            }
        }

        // MARK: Clear glass

        /// GPU milliseconds for the whole clear-glass pipeline (two blur passes and the glass) over a 2048 x 2048 source,
        /// for a rounded rectangle covering `coverage` of it. The two-Gaussian blur is compared with a single Gaussian,
        /// rotating the order each round, with a control (the same configuration twice) to show the noise.
        @Test func `clear glass: paired taps against one fetch per texel`() throws {
            let renderer = try #require(ClearGlassRenderer())
            let device = renderer.device
            let side = 2048
            let sourceDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: side, height: side, mipmapped: false)
            sourceDescriptor.usage = .shaderRead
            let source = try #require(device.makeTexture(descriptor: sourceDescriptor))
            var random = OracleRandom(state: 5)
            var bytes = [UInt8](repeating: 0, count: side * side * 4)
            for index in bytes.indices { bytes[index] = UInt8(random.unit() * 255) }
            // Incompressible content, so the memory system is not flattered.
            unsafe source.replace(
                region: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0, withBytes: bytes, bytesPerRow: side * 4)
            let configuration = ClearGlassConfiguration(shape: .roundedRect(radii: GlassCornerRadii(32)))
            for (name, size) in [
                ("typical 300 x 200 pt at 3x", CGSize(width: 300, height: 200)),
                ("large 650 x 650 pt at 3x", CGSize(width: 650, height: 650)),
            ] {
                let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm, width: Int(size.width * 3) + 8, height: Int(size.height * 3) + 8,
                    mipmapped: false)
                targetDescriptor.usage = .renderTarget
                targetDescriptor.storageMode = .private
                let target = try #require(device.makeTexture(descriptor: targetDescriptor))
                let uniforms = configuration.uniforms(
                    size: size, scale: 3, sourceOrigin: CGPoint(x: 100, y: 100),
                    sourceSize: CGSize(width: side, height: side))
                // paired, plain, and a control that is paired again: the control's spread is the noise.
                let modes: [(String, Bool)] = [("paired", true), ("plain", false), ("control", true)]
                var samples = Array(repeating: [Double](), count: modes.count)
                for round in 0..<40 {
                    for step in 0..<modes.count {
                        let index = (step + round) % modes.count
                        renderer.usesPairedTaps = modes[index].1
                        let command = try #require(renderer.makeCommandBuffer())
                        for _ in 0..<4 {
                            _ = renderer.encode(
                                into: command, source: source, uniforms: uniforms,
                                blur: configuration.blurPlan(scale: 3), field: nil,
                                target: target)
                        }
                        command.commit()
                        command.waitUntilCompleted()
                        if round >= 8 { samples[index].append((command.gpuEndTime - command.gpuStartTime) * 1000 / 4) }
                    }
                }
                renderer.usesPairedTaps = true
                func median(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }
                let paired = median(samples[0])
                let plain = median(zip(samples[1], samples[0]).map { $0 / $1 })
                let control = median(zip(samples[2], samples[0]).map { $0 / $1 })
                print(
                    "CLEAR \(name): paired \(String(format: "%.3f", paired)) ms; plain x\(String(format: "%.3f", plain)) of paired; control x\(String(format: "%.3f", control))"
                )
            }
        }
    }
#endif
