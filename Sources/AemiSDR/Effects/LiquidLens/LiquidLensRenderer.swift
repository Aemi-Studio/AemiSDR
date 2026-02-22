//
//  LiquidLensRenderer.swift
//  AemiSDR
//

#if os(iOS)
    import Metal
    import MetalKit
    import OSLog

    /// Manages the Metal render pipeline for the liquid lens distortion effect.
    ///
    /// Loads the compiled `LiquidLens` metallib from `Bundle.module` and creates
    /// the render pipeline state, sampler, and command queue needed to render
    /// the effect into a `CAMetalLayer` drawable.
    @MainActor
    final class LiquidLensRenderer {

        // MARK: - Properties

        private static let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: "LiquidLensRenderer"
        )

        let device: MTLDevice
        private let commandQueue: MTLCommandQueue
        private let pipelineState: MTLRenderPipelineState
        private let textureLoader: MTKTextureLoader

        // MARK: - Initialization

        init?() {
            guard let device = MTLCreateSystemDefaultDevice() else {
                Self.logger.error("Metal is not available on this device.")
                return nil
            }

            guard let commandQueue = device.makeCommandQueue() else {
                Self.logger.error("Failed to create Metal command queue.")
                return nil
            }

            guard let pipelineState = Self.buildPipeline(device: device) else {
                return nil
            }

            self.device = device
            self.commandQueue = commandQueue
            self.pipelineState = pipelineState
            self.textureLoader = MTKTextureLoader(device: device)
        }

        // MARK: - Texture Creation

        func makeTexture(from cgImage: CGImage) -> MTLTexture? {
            // Try MTKTextureLoader first (fastest path for file-backed images)
            if let texture = try? textureLoader.newTexture(
                cgImage: cgImage,
                options: [
                    .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                    .SRGB: false,
                ]
            ) {
                return texture
            }

            // Fallback: manual texture creation via CGContext.
            // drawHierarchy/UIGraphicsImageRenderer can produce CGImages with pixel
            // formats that MTKTextureLoader rejects. Drawing into a BGRA context
            // normalizes the format.
            let width = cgImage.width
            let height = cgImage.height
            guard width > 0, height > 0 else { return nil }

            let bytesPerRow = width * 4
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else {
                Self.logger.error("Failed to create CGContext for texture conversion.")
                return nil
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            guard let data = context.data else { return nil }

            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.usage = .shaderRead

            guard let texture = device.makeTexture(descriptor: descriptor) else {
                Self.logger.error("Failed to create MTLTexture descriptor.")
                return nil
            }

            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: data,
                bytesPerRow: bytesPerRow
            )

            return texture
        }

        // MARK: - Rendering

        func render(
            sourceTexture: MTLTexture,
            uniforms: LiquidLensUniforms,
            drawable: CAMetalDrawable
        ) {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            let passDescriptor = MTLRenderPassDescriptor()
            passDescriptor.colorAttachments[0].texture = drawable.texture
            passDescriptor.colorAttachments[0].loadAction = .clear
            passDescriptor.colorAttachments[0].storeAction = .store
            passDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: 0, green: 0, blue: 0, alpha: 0
            )

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
                return
            }

            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentTexture(sourceTexture, index: 0)

            var mutableUniforms = uniforms
            encoder.setFragmentBytes(&mutableUniforms, length: MemoryLayout<LiquidLensUniforms>.stride, index: 0)

            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()

            commandBuffer.present(drawable)

            #if DEBUG
            commandBuffer.addCompletedHandler { buffer in
                if let error = buffer.error {
                    Self.logger.error("GPU command buffer error: \(error.localizedDescription)")
                }
            }
            #endif

            commandBuffer.commit()
        }

        // MARK: - Pipeline Construction

        /// Attempts to build a render pipeline from candidate libraries.
        ///
        /// The named metallib (e.g. `LiquidLens.iOS.metallib`) compiled by the SPM build plugin
        /// targets the device architecture. On simulator, `makeLibrary(URL:)` succeeds but
        /// `makeRenderPipelineState` fails because the GPU IR is incompatible. We try the named
        /// metallib first, and if pipeline creation fails, fall back to `default.metallib` which
        /// Xcode auto-compiles for the active run destination.
        private static func buildPipeline(device: MTLDevice) -> MTLRenderPipelineState? {
            for library in candidateLibraries(device: device) {
                if let pipeline = tryBuildPipeline(device: device, library: library) {
                    return pipeline
                }
            }

            logger.error("Failed to build LiquidLens render pipeline from any available library.")
            return nil
        }

        private static func candidateLibraries(device: MTLDevice) -> [MTLLibrary] {
            var libraries: [MTLLibrary] = []

            let libraryName: String
            #if os(macOS)
                libraryName = "LiquidLens.macOS"
            #else
                libraryName = "LiquidLens.iOS"
            #endif

            // Named metallib (works on device)
            if let url = Bundle.module.url(forResource: libraryName, withExtension: "metallib"),
               let library = try? device.makeLibrary(URL: url)
            {
                libraries.append(library)
            }

            // default.metallib (Xcode auto-compiles for the active run destination — simulator or device)
            if let library = try? device.makeDefaultLibrary(bundle: Bundle.module) {
                libraries.append(library)
            }

            return libraries
        }

        private static func tryBuildPipeline(device: MTLDevice, library: MTLLibrary) -> MTLRenderPipelineState? {
            guard let vertexFunction = library.makeFunction(name: "liquidLensVertex"),
                  let fragmentFunction = library.makeFunction(name: "liquidLensFragment")
            else {
                return nil
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            return try? device.makeRenderPipelineState(descriptor: descriptor)
        }
    }
#endif
