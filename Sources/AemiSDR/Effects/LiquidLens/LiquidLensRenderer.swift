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

        nonisolated private static let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: "LiquidLensRenderer"
        )

        let device: MTLDevice
        private let commandQueue: MTLCommandQueue
        private let pipelineStateChromatic: MTLRenderPipelineState
        private let pipelineStateMonochrome: MTLRenderPipelineState
        private let textureLoader: MTKTextureLoader

        /// Reusable render pass descriptor; only the color attachment's texture
        /// is mutated per `render(...)`. The static fields (load/store action,
        /// clear color) are initialised once. Drops one allocation per render
        /// frame.
        private let passDescriptor: MTLRenderPassDescriptor = {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].storeAction = .store
            descriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: 0, green: 0, blue: 0, alpha: 0
            )
            return descriptor
        }()

        // MARK: - Initialization

        init?() {
            guard let device = MTLCreateSystemDefaultDevice() else {
                Self.logger.error("Metal is not available on this device.")
                return nil
            }

            guard let commandQueue = LiquidLensRenderer.sharedCommandQueue(for: device) else {
                Self.logger.error("Failed to create Metal command queue.")
                return nil
            }

            guard let pipelines = LiquidLensRenderer.sharedPipelines(for: device) else {
                return nil
            }

            self.device = device
            self.commandQueue = commandQueue
            self.pipelineStateChromatic = pipelines.chromatic
            self.pipelineStateMonochrome = pipelines.monochrome
            self.textureLoader = LiquidLensRenderer.sharedTextureLoader(for: device)
        }

        // MARK: - Texture Creation

        func makeTexture(from cgImage: CGImage) -> MTLTexture? {
            // Try MTKTextureLoader first (fastest path for file-backed images).
            // Load as sRGB so the GPU sampler linearises on read — matches the
            // sRGB drawable format and avoids double-gamma when the lens is
            // composited over wide-gamut backdrops.
            if let texture = try? textureLoader.newTexture(
                cgImage: cgImage,
                options: [
                    .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                    .SRGB: true,
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
            guard let context = unsafe CGContext(
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
            guard let data = unsafe context.data else { return nil }

            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.usage = .shaderRead
            // Explicit storage mode: `texture.replace(...)` below requires
            // `.shared` (or `.managed` on macOS). The factory's default is
            // `.private` on iOS, which would silently corrupt the texture.
            descriptor.storageMode = .shared

            guard let texture = device.makeTexture(descriptor: descriptor) else {
                Self.logger.error("Failed to create MTLTexture descriptor.")
                return nil
            }

            unsafe texture.replace(
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
            drawable: CAMetalDrawable,
            onCompleted: (@Sendable () -> Void)? = nil
        ) {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                // Even on early failure, fire the consumer's completion so the
                // ZeroCopyTextureBridge slot doesn't stay in-flight forever.
                onCompleted?()
                return
            }
            commandBuffer.label = "AemiSDR.LiquidLens.CommandBuffer"

            // Reuse the cached descriptor; only the drawable's texture changes
            // per frame. Static fields (load/store action, clear color) were
            // configured once at init.
            passDescriptor.colorAttachments[0].texture = drawable.texture

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
                onCompleted?()
                return
            }
            encoder.label = "AemiSDR.LiquidLens.RenderEncoder"

            let pipelineState = uniforms.chromaticAmount > 0.0001
                ? pipelineStateChromatic
                : pipelineStateMonochrome
            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentTexture(sourceTexture, index: 0)

            // Bound the rasterised region to the lens's AABB in overlay mode.
            // The fragment shader returns transparent outside the SDF, but the
            // GPU still runs the shader for every fragment without a scissor.
            // For a small lens on a large drawable, scissoring cuts fragment
            // count by orders of magnitude. Include a 2px margin to preserve
            // SDF antialiasing at the lens edge.
            if uniforms.overlayMode != 0 {
                let drawableW = Int(uniforms.textureSize.x)
                let drawableH = Int(uniforms.textureSize.y)
                if drawableW > 0, drawableH > 0 {
                    let margin: Float = 2
                    let minX = max(0, Int((uniforms.center.x - uniforms.halfSize.x - margin).rounded(.down)))
                    let minY = max(0, Int((uniforms.center.y - uniforms.halfSize.y - margin).rounded(.down)))
                    let maxX = min(drawableW, Int((uniforms.center.x + uniforms.halfSize.x + margin).rounded(.up)))
                    let maxY = min(drawableH, Int((uniforms.center.y + uniforms.halfSize.y + margin).rounded(.up)))
                    if maxX > minX, maxY > minY {
                        encoder.setScissorRect(MTLScissorRect(
                            x: minX, y: minY,
                            width: maxX - minX, height: maxY - minY
                        ))
                    }
                }
            }

            var mutableUniforms = uniforms
            unsafe encoder.setFragmentBytes(&mutableUniforms, length: MemoryLayout<LiquidLensUniforms>.stride, index: 0)

            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()

            commandBuffer.present(drawable)

            // Completion handler fires off the main thread; route the bridge
            // slot release plus error logging from here in all builds.
            commandBuffer.addCompletedHandler { buffer in
                if let error = buffer.error {
                    Self.logger.error("GPU command buffer error: \(error.localizedDescription)")
                }
                onCompleted?()
            }

            commandBuffer.commit()
        }

        // MARK: - Per-device Shared Caches

        /// Process-wide caches keyed by `ObjectIdentifier(device)`. Multiple
        /// `LiquidLensUIView` instances sharing the same `MTLDevice` reuse the
        /// same pipeline states, command queue, and texture loader instead of
        /// allocating a fresh set per view. This avoids the synchronous
        /// pipeline-state compilation (single-digit milliseconds) on every
        /// `LiquidLensUIView.init` — material for scroll-on of a list with N
        /// glass cells.
        ///
        /// `MTLRenderPipelineState`, `MTLCommandQueue`, and `MTKTextureLoader`
        /// are documented thread-safe; sharing across instances is sound.
        nonisolated(unsafe) private static var pipelineCache: [ObjectIdentifier: (chromatic: MTLRenderPipelineState, monochrome: MTLRenderPipelineState)] = [:]
        nonisolated(unsafe) private static var commandQueueCache: [ObjectIdentifier: MTLCommandQueue] = [:]
        nonisolated(unsafe) private static var textureLoaderCache: [ObjectIdentifier: MTKTextureLoader] = [:]
        nonisolated private static let cacheLock = NSLock()

        static func sharedPipelines(
            for device: MTLDevice
        ) -> (chromatic: MTLRenderPipelineState, monochrome: MTLRenderPipelineState)? {
            let key = ObjectIdentifier(device)
            cacheLock.lock()
            defer { cacheLock.unlock() }
            if let cached = unsafe pipelineCache[key] { return cached }
            guard let built = buildPipelines(device: device) else { return nil }
            unsafe pipelineCache[key] = built
            return built
        }

        static func sharedCommandQueue(for device: MTLDevice) -> MTLCommandQueue? {
            let key = ObjectIdentifier(device)
            cacheLock.lock()
            defer { cacheLock.unlock() }
            if let cached = unsafe commandQueueCache[key] { return cached }
            guard let queue = device.makeCommandQueue() else { return nil }
            unsafe commandQueueCache[key] = queue
            return queue
        }

        static func sharedTextureLoader(for device: MTLDevice) -> MTKTextureLoader {
            let key = ObjectIdentifier(device)
            cacheLock.lock()
            defer { cacheLock.unlock() }
            if let cached = unsafe textureLoaderCache[key] { return cached }
            let loader = MTKTextureLoader(device: device)
            unsafe textureLoaderCache[key] = loader
            return loader
        }

        // MARK: - Pipeline Construction

        /// Attempts to build a render pipeline from candidate libraries.
        ///
        /// The named metallib (e.g. `LiquidLens.iOS.metallib`) compiled by the SPM build plugin
        /// targets the device architecture. On simulator, `makeLibrary(URL:)` succeeds but
        /// `makeRenderPipelineState` fails because the GPU IR is incompatible. We try the named
        /// metallib first, and if pipeline creation fails, fall back to `default.metallib` which
        /// Xcode auto-compiles for the active run destination.
        private static func buildPipelines(
            device: MTLDevice
        ) -> (chromatic: MTLRenderPipelineState, monochrome: MTLRenderPipelineState)? {
            for library in candidateLibraries(device: device) {
                if let pipelines = tryBuildPipelines(device: device, library: library) {
                    return pipelines
                }
            }

            logger.error("Failed to build LiquidLens render pipelines from any available library.")
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

            // On simulator, prefer default.metallib built for the active destination.
            #if targetEnvironment(simulator)
                if let library = try? device.makeDefaultLibrary(bundle: Bundle.module) {
                    libraries.append(library)
                }
            #endif

            // Named metallib (works on device)
            if let url = Bundle.module.url(forResource: libraryName, withExtension: "metallib"),
               let library = try? device.makeLibrary(URL: url)
            {
                libraries.append(library)
            }

            // default.metallib (Xcode auto-compiles for the active run destination — simulator or device)
            #if !targetEnvironment(simulator)
                if let library = try? device.makeDefaultLibrary(bundle: Bundle.module) {
                    libraries.append(library)
                }
            #endif

            return libraries
        }

        private static func tryBuildPipelines(
            device: MTLDevice,
            library: MTLLibrary
        ) -> (chromatic: MTLRenderPipelineState, monochrome: MTLRenderPipelineState)? {
            guard let vertexFunction = library.makeFunction(name: "liquidLensVertex"),
                  let chromaticFragment = makeFragmentFunction(library: library, chromaticEnabled: true),
                  let monochromeFragment = makeFragmentFunction(library: library, chromaticEnabled: false)
            else {
                return nil
            }

            let chromaticDescriptor = makePipelineDescriptor(
                vertexFunction: vertexFunction,
                fragmentFunction: chromaticFragment
            )
            chromaticDescriptor.label = "AemiSDR.LiquidLens.Pipeline.Chromatic"

            let monochromeDescriptor = makePipelineDescriptor(
                vertexFunction: vertexFunction,
                fragmentFunction: monochromeFragment
            )
            monochromeDescriptor.label = "AemiSDR.LiquidLens.Pipeline.Monochrome"

            guard let chromatic = try? device.makeRenderPipelineState(descriptor: chromaticDescriptor),
                  let monochrome = try? device.makeRenderPipelineState(descriptor: monochromeDescriptor)
            else {
                return nil
            }

            return (chromatic, monochrome)
        }

        private static func makeFragmentFunction(
            library: MTLLibrary,
            chromaticEnabled: Bool
        ) -> MTLFunction? {
            var chromatic = chromaticEnabled
            let constants = MTLFunctionConstantValues()
            unsafe constants.setConstantValue(&chromatic, type: .bool, index: 0)

            return try? library.makeFunction(
                name: "liquidLensFragment",
                constantValues: constants
            )
        }

        private static func makePipelineDescriptor(
            vertexFunction: MTLFunction,
            fragmentFunction: MTLFunction
        ) -> MTLRenderPipelineDescriptor {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            // Must match `metalLayer.pixelFormat` in `LiquidLensUIView`. See
            // that file for the simulator vs device rationale.
            #if targetEnvironment(simulator)
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            #else
                descriptor.colorAttachments[0].pixelFormat = .bgra10_xr_srgb
            #endif
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return descriptor
        }
    }
#endif
