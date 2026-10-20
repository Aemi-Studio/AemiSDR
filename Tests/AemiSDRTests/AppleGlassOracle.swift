//
//  AppleGlassOracle.swift
//  AemiSDRTests
//
//  Runs Apple's own glass_foreground_sdf shader as ground truth (ADR-0007). The library is read at test time from the
//  installed simulator runtime (QuartzCore's default.metallib). It is Apple's file, it stays where Apple put it, and
//  nothing from it is copied into this repository. Without a runtime the tests skip.
//

#if os(macOS)
    import Foundation
    import Metal
    import simd

    /// Deterministic pseudo-random numbers, so a failure reproduces.
    struct OracleRandom {
        var state: UInt64
        mutating func unit() -> Float {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float((state >> 40) & 0xFF_FFFF) / Float(0x100_0000)
        }
        mutating func value(in range: ClosedRange<Float>) -> Float {
            range.lowerBound + (range.upperBound - range.lowerBound) * unit()
        }
    }

    struct AppleGlassOracle {
        static let side = 96
        static let extent: Float = 50

        /// Where the simulator runtime keeps Core Animation's shader library, or nil when none is installed.
        static func appleLibraryURL() -> URL? {
            if let path = ProcessInfo.processInfo.environment["AEMI_APPLE_QUARTZCORE_METALLIB"] {
                return URL(fileURLWithPath: path)
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "list", "runtimes", "-j"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            guard (try? process.run()) != nil else { return nil }
            // Drain before waiting: a long listing would otherwise block on a full pipe.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let runtimes = json["runtimes"] as? [[String: Any]]
            else { return nil }
            let candidates =
                runtimes
                .filter { ($0["name"] as? String)?.hasPrefix("iOS") == true }
                .compactMap { $0["runtimeRoot"] as? String }
                .map {
                    URL(fileURLWithPath: $0).appending(
                        path: "System/Library/Frameworks/QuartzCore.framework/default.metallib")
                }
            return candidates.last { FileManager.default.fileExists(atPath: $0.path) }
        }

        static var referenceSource: String {
            get throws {
                let url = URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                    .appending(path: "Verification/Reference/GlassSDFReference.metal")
                return try String(contentsOf: url, encoding: .utf8)
            }
        }

        struct Vertex {
            var position: SIMD4<Float>
            var sdf: SIMD2<Float>
            var src: SIMD2<Float>
        }

        private static func vertex(_ x: Float, _ y: Float) -> Vertex {
            Vertex(
                position: SIMD4<Float>(x, y, 0, 1), sdf: SIMD2<Float>(x * extent, y * extent),
                src: SIMD2<Float>((x + 1) / 2, (1 - y) / 2))
        }

        let device: MTLDevice
        let queue: MTLCommandQueue
        let apple: MTLLibrary
        let applePipeline: MTLRenderPipelineState

        init(appleLibrary: URL) throws {
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
                throw OracleError.noDevice
            }
            self.device = device
            self.queue = queue
            apple = try device.makeLibrary(URL: appleLibrary)
            applePipeline = try Self.pipeline(
                device: device, vertexLibrary: apple, fragmentLibrary: apple, fragment: "glass_foreground_sdf_lpf")
        }

        /// The same vertex stage drives both fragment functions, so only the fragment code differs.
        static func pipeline(
            device: MTLDevice, vertexLibrary: MTLLibrary, fragmentLibrary: MTLLibrary, fragment: String,
            vertex: String = "sdf_filter_vert_lpf", pixelFormat: MTLPixelFormat = .rgba32Float, blending: Bool = false
        ) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexLibrary.makeFunction(name: vertex)
            descriptor.fragmentFunction = fragmentLibrary.makeFunction(name: fragment)
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            if blending {
                // Blending forces every overlapping fragment to be shaded; an opaque overdraw would be skipped.
                descriptor.colorAttachments[0].isBlendingEnabled = true
                descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
                descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
                descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
                descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
            }
            let layout = MTLVertexDescriptor()
            layout.attributes[0].format = .float4
            layout.attributes[0].offset = 0
            layout.attributes[0].bufferIndex = 8
            layout.attributes[1].format = .float2
            layout.attributes[1].offset = 16
            layout.attributes[1].bufferIndex = 8
            layout.attributes[2].format = .float2
            layout.attributes[2].offset = 24
            layout.attributes[2].bufferIndex = 8
            layout.layouts[8].stride = MemoryLayout<Vertex>.stride
            descriptor.vertexDescriptor = layout
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }

        func referencePipeline(source: String) throws -> MTLRenderPipelineState {
            let library = try device.makeLibrary(source: source, options: nil)
            return try Self.pipeline(
                device: device, vertexLibrary: apple, fragmentLibrary: library,
                fragment: "reference_glass_foreground_sdf")
        }

        /// 16x16 premultiplied random colour with alpha in 0.4...1, so every dispersive tap reads something different.
        func makeSource(_ random: inout OracleRandom) throws -> MTLTexture {
            let n = 16
            var texels = [Float](repeating: 0, count: n * n * 4)
            for index in 0..<(n * n) {
                let alpha = random.value(in: 0.4...1)
                texels[index * 4] = random.unit() * alpha
                texels[index * 4 + 1] = random.unit() * alpha
                texels[index * 4 + 2] = random.unit() * alpha
                texels[index * 4 + 3] = alpha
            }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba32Float, width: n, height: n, mipmapped: false)
            guard let texture = device.makeTexture(descriptor: descriptor) else { throw OracleError.noDevice }
            // The array holds exactly n*n RGBA32F texels.
            unsafe texture.replace(
                region: MTLRegionMake2D(0, 0, n, n), mipmapLevel: 0, withBytes: texels, bytesPerRow: n * 16)
            return texture
        }

        /// 32 floats: the 12-float field block, then the glass block. Field mode in slot 2.
        static func uniforms(_ random: inout OracleRandom, mode: Int) -> [Float] {
            var u = [Float](repeating: 0, count: 32)
            let bx = random.value(in: 18...40)
            let by = random.value(in: 18...40)
            let smaller = min(bx, by)
            u[0] = bx
            u[1] = by
            u[2] = Float(mode)
            u[3] = [0, 0, 0.35, 1][Int(random.unit() * 4) % 4]
            let angle = random.unit() < 0.5 ? 0 : random.value(in: -0.5...0.5)
            u[4] = cos(angle)
            u[5] = -sin(angle)
            u[6] = sin(angle)
            u[7] = cos(angle)
            if mode == 4 {
                u[8] = random.value(in: 0...1)
                u[9] = random.value(in: 0...1)
                u[10] = random.value(in: 2...smaller)
            } else if mode == 5 {
                // Mixed signs: negative radii take the continuous curve, positive ones the circle.
                for index in 0..<4 {
                    let radius = random.value(in: 1...smaller)
                    u[8 + index] = random.unit() < 0.6 ? -radius : radius
                }
            }
            let tilt = random.value(in: 0...6.28)
            u[12] = cos(tilt)
            u[13] = sin(tilt)
            u[14] = -sin(tilt)
            u[15] = cos(tilt)
            u[16] = random.value(in: 0...0.25)
            u[17] = random.value(in: 0.05...0.6)
            u[18] = random.value(in: 0...15)
            u[19] = random.value(in: 0...0.25)
            u[20] = random.value(in: 0.05...0.6)
            u[21] = random.value(in: 0...15)
            let second = random.value(in: 0...6.28)
            u[22] = cos(second)
            u[23] = sin(second)
            let from = random.value(in: -25...0)
            u[24] = from
            u[25] = from + random.value(in: 5...50)
            u[26] = random.value(in: 0...0.3)
            u[27] = random.value(in: 0.5...1)
            let first = random.value(in: 0...6.28)
            u[28] = cos(first)
            u[29] = sin(first)
            return u
        }

        /// Everything a draw needs besides the pipeline: the quad, the matrices, the texture and the uniform blocks.
        func bind(_ encoder: MTLRenderCommandEncoder, uniforms: [Float], source: MTLTexture, edr: Float) {
            let vertices = [Self.vertex(-1, -1), Self.vertex(1, -1), Self.vertex(-1, 1), Self.vertex(1, 1)]
            var mvp = matrix_identity_float4x4
            var texmat = SIMD4<Float>(1, 0, 0, 1)
            var edrScale = edr
            // Every pointer is copied by Metal during the call; each source outlives it.
            unsafe vertices.withUnsafeBytes {
                if let base = $0.baseAddress { encoder.setVertexBytes(base, length: $0.count, index: 8) }
            }
            unsafe encoder.setVertexBytes(&mvp, length: MemoryLayout<simd_float4x4>.size, index: 2)
            unsafe encoder.setVertexBytes(&texmat, length: MemoryLayout<SIMD4<Float>>.size, index: 3)
            encoder.setFragmentTexture(source, index: 3)
            unsafe uniforms.withUnsafeBytes {
                if let base = $0.baseAddress { encoder.setFragmentBytes(base, length: 128, index: 1) }
            }
            unsafe encoder.setFragmentBytes(&edrScale, length: 4, index: 6)
        }

        func render(_ pipeline: MTLRenderPipelineState, uniforms: [Float], source: MTLTexture, edr: Float) throws
            -> [Float]
        {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba32Float, width: Self.side, height: Self.side, mipmapped: false)
            descriptor.usage = [.renderTarget]
            descriptor.storageMode = .shared
            guard let target = device.makeTexture(descriptor: descriptor), let command = queue.makeCommandBuffer()
            else {
                throw OracleError.noDevice
            }
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { throw OracleError.noDevice }
            encoder.setRenderPipelineState(pipeline)
            bind(encoder, uniforms: uniforms, source: source, edr: edr)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            command.commit()
            command.waitUntilCompleted()
            guard command.status == .completed else { throw OracleError.gpu(String(describing: command.error)) }
            var pixels = [Float](repeating: 0, count: Self.side * Self.side * 4)
            // The destination holds exactly side*side RGBA32F texels.
            unsafe pixels.withUnsafeMutableBytes {
                guard let base = $0.baseAddress else { return }
                target.getBytes(
                    base, bytesPerRow: Self.side * 16, from: MTLRegionMake2D(0, 0, Self.side, Self.side),
                    mipmapLevel: 0)
            }
            return pixels
        }

        /// Largest absolute difference, the number of values off by more than 1e-3, and the peak output (so a
        /// comparison of two blank images cannot pass for agreement).
        func compare(mode: Int, cases: Int, seed: UInt64, referenceSource: String) throws -> (
            largest: Float, off: Int, peak: Float
        ) {
            let reference = try referencePipeline(source: referenceSource)
            var random = OracleRandom(state: seed)
            var largest: Float = 0
            var off = 0
            var peak: Float = 0
            for _ in 0..<cases {
                let uniforms = Self.uniforms(&random, mode: mode)
                let source = try makeSource(&random)
                let edr: Float = random.unit() < 0.5 ? 1 : random.value(in: 1...2)
                let expected = try render(applePipeline, uniforms: uniforms, source: source, edr: edr)
                let actual = try render(reference, uniforms: uniforms, source: source, edr: edr)
                for index in expected.indices {
                    let difference = abs(expected[index] - actual[index])
                    largest = max(largest, difference)
                    if difference > 1e-3 { off += 1 }
                    peak = max(peak, abs(expected[index]))
                }
            }
            return (largest, off, peak)
        }
    }

    enum OracleError: Error {
        case noDevice
        case gpu(String)
    }
#endif
