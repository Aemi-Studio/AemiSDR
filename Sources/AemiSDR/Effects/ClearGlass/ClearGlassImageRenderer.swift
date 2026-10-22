#if canImport(Metal)
    import CoreGraphics
    import Dispatch
    import Foundation
    import Metal

    /// A still render, with premultiplied sRGB pixels and the glass's position inside the padded image.
    public struct ClearGlassRenderedImage: Sendable {
        public let image: CGImage
        public let contentRect: CGRect
        public let scale: CGFloat
        /// GPU execution only; nil when the driver supplies no timestamps.
        public let gpuMilliseconds: Double?
        /// Includes upload, geometry, encoding, GPU completion and readback; excludes executor queueing.
        public let totalMilliseconds: Double
    }

    /// Asynchronous still-image rendering for previews and exports on macOS and iOS.
    ///
    /// Metal resources belong to this actor. A dedicated serial executor performs the blocking GPU fence and readback,
    /// never the main actor or Swift's cooperative pool. Calls are serialized; cancelled calls do not publish an image.
    /// This readback API is not a live-capture or zero-copy presentation API.
    public actor ClearGlassImageRenderer {
        private nonisolated let executor = DispatchSerialQueue(
            label: "studio.aemi.ClearGlass.images", qos: .userInitiated)
        public nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

        private let maximumWorkingBytes: Int
        private var renderer: ClearGlassRenderer?
        private var sourceImage: CGImage?
        private var sourceTexture: MTLTexture?
        private var fieldKey: FieldKey?
        private var fieldValues: GlassDistanceField?
        private var fieldTexture: MTLTexture?
        private var scratchKey: SIMD3<Int>?

        private struct FieldKey: Equatable {
            let shape: GlassShape
            let size: CGSize
            let scale: CGFloat
            let width: Int
            let height: Int
        }

        /// Bounds the estimated working set before allocating textures or path rasters. Default: 256 MiB.
        public init(maximumWorkingBytes: Int = 256 * 1024 * 1024) {
            self.maximumWorkingBytes = max(0, maximumWorkingBytes)
        }

        /// Renders the glass over a region of `source`. All geometry is in points; `scale` is source pixels per point.
        /// The glass rectangle must be wholly inside the source. Output padding is symmetric at fractional pixel sizes.
        /// - Throws: `RenderError` for invalid geometry, resource limits, cancellation or rendering failure.
        public func render(
            source: CGImage, origin: CGPoint, size: CGSize, scale: CGFloat, configuration: ClearGlassConfiguration
        ) throws(RenderError) -> ClearGlassRenderedImage {
            let start = ContinuousClock.now
            guard !Task.isCancelled else { throw .cancelled }
            guard valid(configuration, origin: origin, size: size, scale: scale),
                source.width <= 16_384, source.height <= 16_384,
                origin.x >= 0, origin.y >= 0,
                (origin.x + size.width) * scale <= CGFloat(source.width),
                (origin.y + size.height) * scale <= CGFloat(source.height)
            else { throw .invalidGeometry }
            let margin = configuration.margin
            let outer = CGSize(width: (size.width + margin * 2) * scale, height: (size.height + margin * 2) * scale)
            guard outer.width.isFinite, outer.height.isFinite,
                (1...16_384).contains(outer.width), (1...16_384).contains(outer.height)
            else { throw .invalidGeometry }
            let width = Int(outer.width.rounded(.up))
            let height = Int(outer.height.rounded(.up))
            var plan = configuration.blurPlan(scale: scale)
            let sourcePixels = source.width * source.height
            let pixels = width * height
            // Includes source upload and scratch, output/readback, and a conservative path raster/upload allowance.
            let estimate = sourcePixels * (8 + 16 * plan.sigmas.count) + pixels * 36
            guard estimate <= maximumWorkingBytes else { throw .resourceLimit }
            if renderer == nil { renderer = ClearGlassRenderer() }
            guard let renderer else { throw .metalUnavailable }
            let nextScratch = SIMD3(source.width, source.height, plan.sigmas.count)
            if scratchKey != nextScratch {
                renderer.removeScratchTextures()
                scratchKey = nextScratch
            }
            let nextFieldKey = FieldKey(
                shape: configuration.shape, size: size, scale: scale, width: width, height: height)
            if nextFieldKey != fieldKey {
                fieldValues = nil
                fieldTexture = nil
                fieldKey = nil
            }
            if sourceImage !== source || sourceTexture == nil {
                sourceImage = nil
                sourceTexture = nil
                guard let texture = renderer.makeSourceTexture(from: source) else { throw .allocationFailed }
                sourceImage = source
                sourceTexture = texture
            }
            guard let sourceTexture else { throw .allocationFailed }
            let padding = CGPoint(
                x: (CGFloat(width) / scale - size.width) / 2, y: (CGFloat(height) / scale - size.height) / 2)
            var uniforms = configuration.uniforms(
                size: size, scale: scale,
                sourceOrigin: CGPoint(x: (origin.x - padding.x) * scale, y: (origin.y - padding.y) * scale),
                sourceSize: CGSize(width: source.width, height: source.height))
            uniforms.viewSize = SIMD2(Float(width), Float(height))
            uniforms.sdfRect = SIMD4(0, 0, Float(width), Float(height))
            if case .path(let path) = configuration.shape {
                let key = nextFieldKey
                if key != fieldKey || fieldTexture == nil {
                    let values = SignedDistanceField.exact(
                        path: path.value, width: width, height: height, scale: scale, origin: padding)
                    guard let texture = renderer.makeFieldTexture(values) else { throw .allocationFailed }
                    fieldKey = key
                    fieldValues = values
                    fieldTexture = texture
                }
            } else {
                fieldKey = nil
                fieldValues = nil
                fieldTexture = nil
            }
            plan.lookReach = configuration.lookReach(size: size, scale: scale, field: fieldValues)
            guard !Task.isCancelled else { throw .cancelled }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = .renderTarget
            descriptor.storageMode = .shared
            guard let target = renderer.device.makeTexture(descriptor: descriptor) else { throw .allocationFailed }
            guard let buffer = renderer.makeCommandBuffer(),
                renderer.encode(
                    into: buffer, source: sourceTexture, uniforms: uniforms, blur: plan, field: fieldTexture,
                    target: target)
            else { throw .encodingFailed }
            buffer.commit()
            buffer.waitUntilCompleted()
            guard buffer.status == .completed else { throw .gpuFailed }
            guard !Task.isCancelled else { throw .cancelled }
            var bytes = [UInt8](repeating: 0, count: pixels * 4)
            unsafe target.getBytes(
                &bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            guard let provider = CGDataProvider(data: Data(bytes) as CFData),
                let space = CGColorSpace(name: CGColorSpace.sRGB),
                let image = CGImage(
                    width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                    space: space,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                        .union(.byteOrder32Little), provider: provider, decode: nil, shouldInterpolate: false,
                    intent: .defaultIntent)
            else { throw .allocationFailed }
            let elapsed = start.duration(to: .now).components
            let gpu = (buffer.gpuEndTime - buffer.gpuStartTime) * 1000
            return ClearGlassRenderedImage(
                image: image, contentRect: CGRect(origin: padding, size: size), scale: scale,
                gpuMilliseconds: gpu.isFinite && gpu > 0 ? gpu : nil,
                totalMilliseconds: Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) * 1e-15)
        }

        /// Drops all cached images, fields, pipelines and textures after earlier serialized calls have finished.
        public func releaseResources() {
            renderer = nil
            sourceImage = nil
            sourceTexture = nil
            fieldKey = nil
            fieldValues = nil
            fieldTexture = nil
            scratchKey = nil
        }

        private func valid(_ config: ClearGlassConfiguration, origin: CGPoint, size: CGSize, scale: CGFloat) -> Bool {
            let values = [
                origin.x, origin.y, size.width, size.height, scale, config.outlineReach, config.outline,
                config.outlineDirection, config.lift, config.liftFalloff, config.chromatic,
                config.veilColor.red, config.veilColor.green, config.veilColor.blue,
                config.rim.edgeDepth, config.rim.edgeFalloff, config.rim.bodyDepth, config.rim.bodyWidth,
                config.rimLight.edgeStrength, config.rimLight.edgeFalloff, config.rimLight.edgePower,
                config.rimLight.tailStrength, config.rimLight.tailFalloff, config.rimLight.tailPower,
                config.rimLight.backdropGain, config.blur.rampDepth, config.blur.rampCurve,
            ]
            guard values.allSatisfy({ $0.isFinite && abs($0) <= 1_000_000 }),
                size.width > 0, size.height > 0, scale > 0, config.outlineReach >= 0,
                config.rimLight.edgePower >= 0, config.rimLight.tailPower >= 0,
                config.rim.profile == .circularArc || config.rim.bodyWidth != 0
            else { return false }
            if case .path(let path) = config.shape {
                let box = path.value.boundingBox
                if !box.isNull {
                    return [box.minX, box.minY, box.maxX, box.maxY].allSatisfy {
                        $0.isFinite && abs($0 * scale) <= 1_000_000
                    }
                }
            }
            return true
        }

        public enum RenderError: Error, LocalizedError, Equatable, Sendable {
            case invalidGeometry, resourceLimit, metalUnavailable, allocationFailed, encodingFailed, gpuFailed,
                cancelled
            public var errorDescription: String? {
                switch self {
                case .invalidGeometry:
                    "Invalid glass geometry or nonfinite configuration. The glass must fit inside the source."
                case .resourceLimit:
                    "The render exceeds its working-memory budget. Reduce the source size or rendering scale."
                case .metalUnavailable: "Metal or the clear-glass shader library is unavailable."
                case .allocationFailed: "Could not allocate the render's textures or image."
                case .encodingFailed: "Could not encode the clear-glass render."
                case .gpuFailed: "The GPU did not complete the clear-glass render."
                case .cancelled: "The render was cancelled."
                }
            }
        }
    }
#endif
