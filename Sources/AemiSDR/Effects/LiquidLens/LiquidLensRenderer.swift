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
    ///
    /// ## Single-pass architecture
    ///
    /// The capture and lens steps are intentionally decoupled:
    ///
    ///   1. `BackdropCaptureCoordinator` rasterizes the underlying SwiftUI /
    ///      UIKit content into an IOSurface via `UIView.drawHierarchy(in:)`,
    ///      exposed to Metal through `ZeroCopyTextureBridge` as a
    ///      `CVMetalTexture`. This step is CPU-side; the surface uses the
    ///      `.shared` storage mode because Metal must read pixels the CPU
    ///      just wrote.
    ///   2. `render(...)` runs a single Metal render pass: the lens fragment
    ///      shader samples the captured surface and writes the displaced
    ///      result directly to the `CAMetalLayer` drawable. One fragment
    ///      shader invocation per output pixel, one texture read, one
    ///      framebuffer write.
    ///
    /// There are no intermediate render targets. Programmable blending and
    /// memoryless tile storage — useful patterns for fusing successive
    /// fragment passes — don't apply here because the input texture comes
    /// from IOSurface, not from a prior render-pass color attachment, and
    /// the captured surface must persist across the CPU→GPU handoff (so it
    /// can't live in tile memory).
    ///
    /// Future contributors: resist the temptation to "add a render pass for
    /// the capture" — the IOSurface path is already optimal for this
    /// architecture and would only add cost.
    @MainActor
    final class LiquidLensRenderer {
        // MARK: - Properties

        nonisolated private static let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: "LiquidLensRenderer"
        )

        let device: MTLDevice
        private let commandQueue: MTLCommandQueue
        private let pipelineCache: LiquidLensPipelineCache
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

            guard let cache = LiquidLensRenderer.sharedPipelineCache(for: device) else {
                Self.logger.error("Failed to initialize LiquidLens pipeline cache.")
                return nil
            }

            self.device = device
            self.commandQueue = commandQueue
            self.pipelineCache = cache
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
            guard
                let context = unsafe CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                )
            else {
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
            pipelineKey: LiquidLensPipelineKey,
            drawable: CAMetalDrawable,
            onCompleted: (@Sendable () -> Void)? = nil
        ) {
            guard let pipelineState = pipelineCache.pipeline(for: pipelineKey) else {
                Self.logger.error("No pipeline available for key \(String(describing: pipelineKey)).")
                onCompleted?()
                return
            }

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
                        encoder.setScissorRect(
                            MTLScissorRect(
                                x: minX, y: minY,
                                width: maxX - minX, height: maxY - minY
                            ))
                    }
                }
            }

            // Inline-bytes upload for the uniform struct.
            //
            // `setFragmentBytes` copies the payload directly into the command
            // encoder's argument stream — no separate `MTLBuffer`, no
            // round-trip to shared memory. Apple's guidance is to prefer this
            // path for resources ≤4KB; the 128-byte lens uniform fits well
            // inside that envelope.
            //
            // A standalone `MTLBuffer` (with triple-buffering for in-flight
            // frames) would let the GPU reuse the same backing allocation
            // across draws, but it costs an extra allocation per buffer, a
            // dispatch-semaphore-gated CPU/GPU producer/consumer dance, and
            // shaves nothing meaningful when the data is small, changes every
            // frame, and is consumed by exactly one draw call. The win shows
            // up when the same uniforms are reused across many draws or when
            // the struct grows past the inline ceiling — neither applies
            // here. A true Metal argument buffer (with `[[id(N)]]` field
            // attributes bundling multiple resources) is similarly aimed at
            // many-resource scenes, not a single 128-byte payload.
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
        nonisolated(unsafe) private static var pipelineCacheByDevice: [ObjectIdentifier: LiquidLensPipelineCache] = [:]
        nonisolated(unsafe) private static var commandQueueCache: [ObjectIdentifier: MTLCommandQueue] = [:]
        nonisolated(unsafe) private static var textureLoaderCache: [ObjectIdentifier: MTKTextureLoader] = [:]
        nonisolated private static let cacheLock = NSLock()

        static func sharedPipelineCache(
            for device: MTLDevice
        ) -> LiquidLensPipelineCache? {
            let key = ObjectIdentifier(device)
            cacheLock.lock()
            defer { cacheLock.unlock() }
            if let cached = unsafe pipelineCacheByDevice[key] { return cached }
            guard let cache = LiquidLensPipelineCache(device: device) else { return nil }
            unsafe pipelineCacheByDevice[key] = cache
            return cache
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

        // MARK: - Library discovery (used by LiquidLensPipelineCache)

        /// Library discovery only touches `Bundle.module` (read-only) and
        /// `MTLDevice.makeLibrary(URL:)` (thread-safe per Apple docs), so
        /// it's safe to call from any actor context — `nonisolated` lets
        /// the nonisolated `LiquidLensPipelineCache.init` use it.
        nonisolated static func candidateLibraries(device: MTLDevice) -> [MTLLibrary] {
            var libraries: [MTLLibrary] = []

            // The shader plugin compiles one library per destination, so every
            // environment — macOS, device, simulator — loads the one built
            // for it.
            let libraryName: String
            #if os(macOS)
                libraryName = "LiquidLens.macOS"
            #elseif targetEnvironment(simulator)
                libraryName = "LiquidLens.iOSSimulator"
            #else
                libraryName = "LiquidLens.iOS"
            #endif

            if let url = Bundle.module.url(forResource: libraryName, withExtension: "metallib"),
                let library = try? device.makeLibrary(URL: url)
            {
                libraries.append(library)
            }

            // default.metallib, in case a host build system compiled the
            // shaders natively for the active destination anyway.
            if let library = try? device.makeDefaultLibrary(bundle: Bundle.module) {
                libraries.append(library)
            }

            return libraries
        }
    }

    // MARK: - Pipeline Cache

    /// Per-device lazy cache of specialized `MTLRenderPipelineState` instances,
    /// one per `LiquidLensPipelineKey`. Thread-safe via internal lock; safe to
    /// share across `LiquidLensRenderer` instances bound to the same device.
    ///
    /// The cache validates the library at init time by building one default
    /// pipeline; if no candidate library works, init returns nil. Subsequent
    /// pipeline requests reuse the validated library.
    final class LiquidLensPipelineCache: @unchecked Sendable {
        nonisolated private static let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: "LiquidLensPipelineCache"
        )

        let device: MTLDevice
        private let library: MTLLibrary
        private let vertexFunction: MTLFunction
        private var pipelines: [LiquidLensPipelineKey: MTLRenderPipelineState] = [:]
        private let lock = NSLock()

        /// Builds the cache for a device. Tries candidate libraries in order;
        /// returns nil if no library can build the default-key pipeline.
        init?(device: MTLDevice) {
            for library in LiquidLensRenderer.candidateLibraries(device: device) {
                guard let vertex = library.makeFunction(name: "liquidLensVertex") else { continue }
                // Validate by building a default-key pipeline.
                let defaultKey = LiquidLensPipelineKey(
                    chromaticEnabled: true,
                    falloffType: 5  // .exponential matches the configured default
                )
                if let pipeline = Self.makePipeline(device: device, library: library, vertex: vertex, key: defaultKey) {
                    self.device = device
                    self.library = library
                    self.vertexFunction = vertex
                    self.pipelines[defaultKey] = pipeline
                    return
                }
            }
            Self.logger.error("Failed to build any LiquidLens pipeline from candidate libraries.")
            return nil
        }

        /// Returns the cached pipeline for the given key, building it on first use.
        func pipeline(for key: LiquidLensPipelineKey) -> MTLRenderPipelineState? {
            lock.lock()
            defer { lock.unlock() }
            if let cached = pipelines[key] { return cached }
            guard let pipeline = Self.makePipeline(device: device, library: library, vertex: vertexFunction, key: key)
            else {
                return nil
            }
            pipelines[key] = pipeline
            return pipeline
        }

        private static func makePipeline(
            device: MTLDevice,
            library: MTLLibrary,
            vertex: MTLFunction,
            key: LiquidLensPipelineKey
        ) -> MTLRenderPipelineState? {
            var chromatic = key.chromaticEnabled
            var falloff = key.falloffType
            var fresnel = key.enableFresnel
            var spectral = key.enableSpectral
            var aspheric = key.enableAspheric
            var highFidelity = key.highFidelityRefraction
            let constants = MTLFunctionConstantValues()
            unsafe constants.setConstantValue(&chromatic, type: .bool, index: 0)
            unsafe constants.setConstantValue(&falloff, type: .int, index: 1)
            unsafe constants.setConstantValue(&fresnel, type: .bool, index: 2)
            unsafe constants.setConstantValue(&spectral, type: .bool, index: 3)
            unsafe constants.setConstantValue(&aspheric, type: .bool, index: 4)
            unsafe constants.setConstantValue(&highFidelity, type: .bool, index: 5)

            guard
                let fragment = try? library.makeFunction(
                    name: "liquidLensFragment",
                    constantValues: constants
                )
            else {
                return nil
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.label = "AemiSDR.LiquidLens.Pipeline.\(key.label)"
            // Must match `metalLayer.pixelFormat` in `LiquidLensUIView`.
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

            return try? device.makeRenderPipelineState(descriptor: descriptor)
        }
    }

    extension LiquidLensPipelineKey {
        /// Human-readable label for pipeline state debugging in Xcode's Metal capture tool.
        fileprivate var label: String {
            var parts: [String] = []
            parts.append(chromaticEnabled ? "C" : "M")
            parts.append("F\(falloffType)")
            if enableFresnel { parts.append("Fr") }
            if enableSpectral { parts.append("Sp") }
            if enableAspheric { parts.append("As") }
            return parts.joined(separator: "-")
        }
    }
#endif
