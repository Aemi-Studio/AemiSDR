//
//  ShippedShaderTests.swift
//  AemiSDRTests
//
//  The other GPU tests compile LiquidLens.metal from source at run time with default options. Users run the library
//  the build plugin produces, compiled for the package's deployment floor. These tests render the same scene with both
//  and compare pixels, so the shipped artifact is itself under test.
//

#if os(macOS)
    import Foundation
    import Metal
    import Testing

    @testable import AemiSDR

    private final class BundleAnchor {}

    @Suite(
        "The shipped LiquidLens library draws what its source draws",
        .enabled(if: MTLCreateSystemDefaultDevice() != nil, "Requires a Metal device"))
    struct ShippedShaderTests {
        static let size = 256

        /// A representative set of the specialised fragment variants (function constants 0 to 6).
        static let variants: [(name: String, configuration: LiquidLensConfiguration)] = {
            var base = LiquidLensConfiguration(
                center: SIMD2(128, 128), halfSize: SIMD2(100, 70), strength: 1.0, lensCurvature: 1.0,
                cornerRadius: .points(40), falloff: .exponential, chromaticAmount: 3, material: .water)
            func with(_ edit: (inout LiquidLensConfiguration) -> Void) -> LiquidLensConfiguration {
                var copy = base
                edit(&copy)
                return copy
            }
            return [
                ("default chromatic", base),
                (
                    "monochrome, smoothstep falloff",
                    with {
                        $0.chromaticAmount = 0
                        $0.falloff = .easeInOut
                    }
                ),
                ("spectral", with { $0.enableSpectral = true }),
                ("fresnel", with { $0.enableFresnel = true }),
                ("high fidelity refraction", with { $0.enableHighFidelityRefraction = true }),
                ("thick lens", with { $0.enableThickLens = true }),
                (
                    "aspheric",
                    with {
                        $0.enableAspheric = true
                        $0.asphericK2 = 0.2
                        $0.asphericK4 = 0.05
                    }
                ),
                (
                    "flint glass, overlay",
                    with {
                        $0.material = .flintGlass
                        $0.overlayMode = true
                    }
                ),
            ]
        }()

        private func shippedLibrary(_ device: MTLDevice) throws -> MTLLibrary {
            // AEMI_SHIPPED_METALLIB tests any compiled library instead, for example one built for another floor.
            if let path = ProcessInfo.processInfo.environment["AEMI_SHIPPED_METALLIB"] {
                return try device.makeLibrary(URL: URL(fileURLWithPath: path))
            }
            // The resource bundle sits beside the test products.
            let products = Bundle(for: BundleAnchor.self).bundleURL.deletingLastPathComponent()
            let candidates = [products, products.deletingLastPathComponent()]
            for directory in candidates {
                let bundle = directory.appending(path: "AemiSDR_AemiSDR.bundle")
                if let url = Bundle(url: bundle)?.url(forResource: "LiquidLens.macOS", withExtension: "metallib") {
                    return try device.makeLibrary(URL: url)
                }
            }
            throw ShaderTestError.shippedLibraryNotFound(products.path)
        }

        private func sourceLibrary(_ device: MTLDevice) throws -> MTLLibrary {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appending(path: "Sources/AemiSDR/Shaders/LiquidLens.metal")
            return try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        }

        /// A deterministic source image: smooth colour with hard edges, so refraction visibly moves something.
        private func sourceTexture(_ device: MTLDevice, side: Int = ShippedShaderTests.size) throws -> MTLTexture {
            var pixels = [UInt8](repeating: 255, count: side * side * 4)
            for y in 0..<side {
                for x in 0..<side {
                    let checker = ((x / 16) + (y / 16)) % 2 == 0 ? 0.25 : 0.0
                    let offset = (y * side + x) * 4
                    pixels[offset] = UInt8(min(255, (Double(x) / Double(side) * 0.75 + checker) * 255))
                    pixels[offset + 1] = UInt8(min(255, (Double(y) / Double(side) * 0.75 + checker) * 255))
                    pixels[offset + 2] = UInt8(min(255, ((Double(x + y) / Double(2 * side)) * 0.75 + checker) * 255))
                }
            }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: side, height: side, mipmapped: false)
            let texture = try #require(device.makeTexture(descriptor: descriptor))
            pixels.withUnsafeBytes { buffer in
                // The buffer holds exactly side*side RGBA8 texels.
                unsafe texture.replace(
                    region: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0,
                    withBytes: buffer.baseAddress!, bytesPerRow: side * 4)
            }
            return texture
        }

        private func pipeline(
            library: MTLLibrary, configuration: LiquidLensConfiguration, device: MTLDevice, blending: Bool = false
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

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = try #require(library.makeFunction(name: "liquidLensVertex"))
            pipelineDescriptor.fragmentFunction = try library.makeFunction(
                name: "liquidLensFragment", constantValues: constants)
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            // Blending defeats the GPU's removal of fully overdrawn opaque draws, which would leave a repeated draw unshaded.
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = blending
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }

        private func render(
            library: MTLLibrary, configuration: LiquidLensConfiguration, device: MTLDevice, source: MTLTexture,
            side: Int = ShippedShaderTests.size
        ) throws -> (pixels: [UInt8], gpuMilliseconds: Double) {
            let pipeline = try pipeline(library: library, configuration: configuration, device: device)

            let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: side, height: side, mipmapped: false)
            targetDescriptor.usage = [.renderTarget, .shaderRead]
            targetDescriptor.storageMode = .shared
            let target = try #require(device.makeTexture(descriptor: targetDescriptor))

            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

            let queue = try #require(device.makeCommandQueue())
            let command = try #require(queue.makeCommandBuffer())
            let encoder = try #require(command.makeRenderCommandEncoder(descriptor: pass))
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(source, index: 0)
            var uniforms = configuration.toUniforms(textureSize: SIMD2(Float(side), Float(side)), scale: 1)
            // The uniform struct is copied by value into the command stream.
            unsafe encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LiquidLensUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            command.commit()
            command.waitUntilCompleted()
            try #require(command.status == .completed, "GPU error: \(String(describing: command.error))")

            var pixels = [UInt8](repeating: 0, count: side * side * 4)
            pixels.withUnsafeMutableBytes { buffer in
                // The destination holds exactly side*side BGRA8 texels.
                unsafe target.getBytes(
                    buffer.baseAddress!, bytesPerRow: side * 4, from: MTLRegionMake2D(0, 0, side, side),
                    mipmapLevel: 0)
            }
            return (pixels, (command.gpuEndTime - command.gpuStartTime) * 1000)
        }

        @Test(arguments: ShippedShaderTests.variants.map(\.name))
        func `the shipped library draws the same pixels as the source compiled at run time`(name: String) throws {
            let configuration = try #require(Self.variants.first { $0.name == name }).configuration
            let device = try #require(MTLCreateSystemDefaultDevice())
            let source = try sourceTexture(device)
            let shipped = try render(
                library: shippedLibrary(device), configuration: configuration, device: device, source: source)
            let runtime = try render(
                library: sourceLibrary(device), configuration: configuration, device: device, source: source)

            var largest = 0
            var differing = 0
            for index in shipped.pixels.indices {
                let difference = abs(Int(shipped.pixels[index]) - Int(runtime.pixels[index]))
                largest = max(largest, difference)
                if difference > 1 { differing += 1 }
            }
            print(
                "SHADER-DIFF \(name): largest=\(largest)/255 channelsOver1=\(differing) gpuMs shipped=\(shipped.gpuMilliseconds) runtime=\(runtime.gpuMilliseconds)"
            )
            // The scene must actually exercise the lens, or equality would be vacuous.
            #expect(shipped.pixels != Array(repeating: 0, count: shipped.pixels.count))
            #expect(
                largest <= 2, "\(name): largest channel difference \(largest)/255 across \(differing) channels over 1")
        }
    }

    private enum ShaderTestError: Error {
        case shippedLibraryNotFound(String)
    }
#endif
