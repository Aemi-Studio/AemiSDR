//
//  ClearGlassRenderer.swift
//  AemiSDR
//
//  Three passes: a horizontal and a vertical Gaussian blur of the part of the source behind the glass, then the glass
//  itself, which reads the blurred result, the shape and the rim. The blur is exact (see `GaussianKernel`), separable,
//  and limited to the region that can be seen.
//

#if canImport(Metal)
    import CoreGraphics
    import Metal
    import OSLog

    final class ClearGlassRenderer {
        nonisolated private static let logger = Logger(subsystem: "studio.aemi.AemiSDR", category: "ClearGlassRenderer")

        let device: MTLDevice
        private let queue: MTLCommandQueue
        private let library: MTLLibrary
        private var pipelines: [String: MTLRenderPipelineState] = [:]
        private var scratch: [String: MTLTexture] = [:]

        init?(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
            guard let device, let queue = device.makeCommandQueue(), let library = Self.library(for: device) else {
                Self.logger.error("Clear glass cannot start: no Metal device, queue or shader library.")
                return nil
            }
            self.device = device
            self.queue = queue
            self.library = library
        }

        private static func library(for device: MTLDevice) -> MTLLibrary? {
            #if os(macOS)
                let name = "ClearGlass.macOS"
            #elseif targetEnvironment(simulator)
                let name = "ClearGlass.iOSSimulator"
            #else
                let name = "ClearGlass.iOS"
            #endif
            if let url = Bundle.module.url(forResource: name, withExtension: "metallib"),
                let library = try? device.makeLibrary(URL: url)
            {
                return library
            }
            return try? device.makeDefaultLibrary(bundle: Bundle.module)
        }

        // MARK: Resources

        /// A source texture holding the image's encoded values untouched: the glass works in display-encoded space.
        func makeSourceTexture(from image: CGImage) -> MTLTexture? {
            let (width, height) = (image.width, image.height)
            guard width > 0, height > 0 else { return nil }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
                guard
                    let context = unsafe CGContext(
                        data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                            | CGBitmapInfo.byteOrder32Little.rawValue)
                else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard drawn else { return nil }
            // The array holds exactly width * height BGRA8 texels.
            unsafe texture.replace(
                region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
            return texture
        }

        /// A half-precision distance texture. Distances are clamped to `SignedDistanceField.reach`, beyond which the rim
        /// is gone, so half precision still resolves a fraction of a pixel near the edge.
        func makeFieldTexture(_ field: [Float], width: Int, height: Int) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r16Float, width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
            let reach = SignedDistanceField.reach
            let halves = field.map { Self.halfBits(min(max($0, -reach), reach)) }
            // The array holds exactly width * height half-precision values.
            unsafe texture.replace(
                region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: halves, bytesPerRow: width * 2)
            return texture
        }

        /// IEEE 754 binary16 bits of a float of modest magnitude (rounds to nearest, flushes underflow to zero).
        static func halfBits(_ value: Float) -> UInt16 {
            let bits = value.bitPattern
            let sign = UInt16((bits >> 16) & 0x8000)
            let exponent = Int((bits >> 23) & 0xFF) - 127 + 15
            let mantissa = bits & 0x7F_FFFF
            if exponent <= 0 { return sign }
            if exponent >= 31 { return sign | 0x7BFF }
            var half = UInt16(exponent << 10) | UInt16(mantissa >> 13)
            if mantissa & 0x1000 != 0 { half += 1 }
            return sign | half
        }

        private func scratchTexture(_ label: String, width: Int, height: Int) -> MTLTexture? {
            let key = "\(label)-\(width)x\(height)"
            if let cached = scratch[key] { return cached }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .private
            guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
            scratch[key] = texture
            return texture
        }

        private func pipeline(vertex: String, fragment: String, format: MTLPixelFormat, fieldTexture: Bool = false)
            -> MTLRenderPipelineState?
        {
            let key = "\(fragment)-\(format.rawValue)-\(fieldTexture)"
            if let cached = pipelines[key] { return cached }
            let constants = MTLFunctionConstantValues()
            var useTexture = fieldTexture
            // Metal copies the value during the synchronous call.
            unsafe constants.setConstantValue(&useTexture, type: .bool, index: 0)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            descriptor.fragmentFunction = try? library.makeFunction(name: fragment, constantValues: constants)
            descriptor.colorAttachments[0].pixelFormat = format
            guard descriptor.fragmentFunction != nil,
                let state = try? device.makeRenderPipelineState(descriptor: descriptor)
            else {
                Self.logger.error("Clear glass pipeline \(key, privacy: .public) failed to build.")
                return nil
            }
            pipelines[key] = state
            return state
        }

        // MARK: Drawing

        /// Encodes all three passes into `commandBuffer`. `blurSigma` is in pixels of the source.
        func encode(
            into commandBuffer: MTLCommandBuffer, source: MTLTexture, uniforms: ClearGlassUniforms, blurSigma: Float,
            field: MTLTexture?, target: MTLTexture
        ) -> Bool {
            let kernel = GaussianKernel(sigma: blurSigma)
            guard
                let blurState = pipeline(vertex: "clearGlassVertex", fragment: "clearGlassBlur", format: .rgba16Float),
                let glassState = pipeline(
                    vertex: "clearGlassVertex", fragment: "clearGlassFragment", format: target.pixelFormat,
                    fieldTexture: field != nil),
                let horizontal = scratchTexture("h", width: source.width, height: source.height),
                let blurred = scratchTexture("v", width: source.width, height: source.height)
            else { return false }

            // The part of the source behind the view, and how far the blur reaches beyond it.
            let view = CGRect(
                x: CGFloat(uniforms.sourceOrigin.x), y: CGFloat(uniforms.sourceOrigin.y),
                width: CGFloat(uniforms.viewSize.x), height: CGFloat(uniforms.viewSize.y))
            func scissor(_ rect: CGRect) -> MTLScissorRect? {
                let clipped = rect.integral.intersection(CGRect(x: 0, y: 0, width: source.width, height: source.height))
                guard clipped.width >= 1, clipped.height >= 1 else { return nil }
                return MTLScissorRect(
                    x: Int(clipped.minX), y: Int(clipped.minY), width: Int(clipped.width), height: Int(clipped.height))
            }
            guard let wide = scissor(view.insetBy(dx: -CGFloat(kernel.radius + 1), dy: -CGFloat(kernel.radius + 1))),
                let exact = scissor(view.insetBy(dx: -1, dy: -1))
            else { return false }

            var sourceSize = SIMD2<Float>(Float(source.width), Float(source.height))
            var weights = kernel.weights
            func blur(_ input: MTLTexture, _ output: MTLTexture, step: SIMD2<Float>, region: MTLScissorRect) {
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = output
                pass.colorAttachments[0].loadAction = .clear
                pass.colorAttachments[0].storeAction = .store
                guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
                encoder.setRenderPipelineState(blurState)
                encoder.setScissorRect(region)
                encoder.setFragmentTexture(input, index: 0)
                var parameters = BlurParameters(step: step, radius: Int32(kernel.radius))
                // Each value is copied into the command stream during the call.
                unsafe encoder.setVertexBytes(&sourceSize, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
                unsafe encoder.setFragmentBytes(&sourceSize, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
                unsafe encoder.setFragmentBytes(&parameters, length: MemoryLayout<BlurParameters>.stride, index: 1)
                unsafe weights.withUnsafeBytes {
                    if let base = $0.baseAddress { encoder.setFragmentBytes(base, length: $0.count, index: 2) }
                }
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
            }
            blur(source, horizontal, step: SIMD2(1 / sourceSize.x, 0), region: wide)
            blur(horizontal, blurred, step: SIMD2(0, 1 / sourceSize.y), region: exact)

            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
            encoder.setRenderPipelineState(glassState)
            var viewSize = uniforms.viewSize
            var mutable = uniforms
            encoder.setFragmentTexture(blurred, index: 0)
            if let field { encoder.setFragmentTexture(field, index: 2) }
            // Each value is copied into the command stream during the call.
            unsafe encoder.setVertexBytes(&viewSize, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
            unsafe encoder.setFragmentBytes(&mutable, length: MemoryLayout<ClearGlassUniforms>.stride, index: 1)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            return true
        }

        /// Renders into `target` and waits. For tests and for one-off captures; the view presents instead.
        func renderAndWait(
            source: MTLTexture, uniforms: ClearGlassUniforms, blurSigma: Float, field: MTLTexture?, target: MTLTexture
        ) -> Bool {
            guard let buffer = queue.makeCommandBuffer(),
                encode(
                    into: buffer, source: source, uniforms: uniforms, blurSigma: blurSigma, field: field, target: target
                )
            else { return false }
            buffer.commit()
            buffer.waitUntilCompleted()
            return buffer.status == .completed
        }

        func makeCommandBuffer() -> MTLCommandBuffer? { queue.makeCommandBuffer() }
    }

    private struct BlurParameters {
        var step: SIMD2<Float>
        var radius: Int32
    }
#endif
