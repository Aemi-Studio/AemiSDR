//
//  ClearGlassGPUTests.swift
//  AemiSDRTests
//
//  Clear glass on the GPU. The shape function is held to the one verified against Apple's shader; the blur to the exact
//  Gaussian; the tone to the values measured on native clear glass; and a path shape to the analytic shape it describes.
//

#if os(macOS)
    import CoreGraphics
    import Foundation
    import Metal
    import Testing

    @testable import AemiSDR

    @Suite("Clear glass on the GPU", .enabled(if: MTLCreateSystemDefaultDevice() != nil, "Requires a Metal device"))
    struct ClearGlassGPUTests {
        private static let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        // MARK: Shape field against the verified reference

        /// Evaluates a field function over a grid of points and returns (distance, gradient) for each.
        private func evaluate(
            source: String, kernel: String, device: MTLDevice, points: [SIMD2<Float>], block2: [Float],
            block3: [Float]
        ) throws -> [SIMD3<Float>] {
            let library = try device.makeLibrary(source: source, options: nil)
            let pipeline = try device.makeComputePipelineState(function: #require(library.makeFunction(name: kernel)))
            let queue = try #require(device.makeCommandQueue())
            let output = try #require(device.makeBuffer(length: points.count * 16, options: .storageModeShared))
            let command = try #require(queue.makeCommandBuffer())
            let encoder = try #require(command.makeComputeCommandEncoder())
            encoder.setComputePipelineState(pipeline)
            var count = UInt32(points.count)
            // Metal copies each value (or array) during the call.
            unsafe points.withUnsafeBytes {
                if let base = $0.baseAddress { encoder.setBytes(base, length: $0.count, index: 0) }
            }
            unsafe encoder.setBuffer(output, offset: 0, index: 1)
            unsafe block2.withUnsafeBytes {
                if let base = $0.baseAddress { encoder.setBytes(base, length: $0.count, index: 2) }
            }
            unsafe block3.withUnsafeBytes {
                if let base = $0.baseAddress { encoder.setBytes(base, length: $0.count, index: 3) }
            }
            unsafe encoder.setBytes(&count, length: 4, index: 4)
            encoder.dispatchThreads(
                MTLSize(width: points.count, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
            encoder.endEncoding()
            command.commit()
            command.waitUntilCompleted()
            let pointer = unsafe output.contents().bindMemory(to: SIMD4<Float>.self, capacity: points.count)
            return (0..<points.count).map { index in
                let value = unsafe pointer[index]
                return SIMD3(value.x, value.y, value.z)
            }
        }

        private func grid(halfSize: SIMD2<Float>) -> [SIMD2<Float>] {
            var points: [SIMD2<Float>] = []
            for iy in -12...12 {
                for ix in -12...12 {
                    points.append(SIMD2(Float(ix) / 10 * halfSize.x, Float(iy) / 10 * halfSize.y))
                }
            }
            return points
        }

        @Test(arguments: [
            (SIMD2<Float>(120, 80), SIMD4<Float>(-30, -30, -30, -30)),
            (SIMD2<Float>(120, 80), SIMD4<Float>(30, 30, 30, 30)),
            (SIMD2<Float>(120, 80), SIMD4<Float>(-10, -40, -25, -70)),
            (SIMD2<Float>(120, 80), SIMD4<Float>(-10, 40, -25, 70)),
            (SIMD2<Float>(90, 90), SIMD4<Float>(-90, -90, -90, -90)),
        ])
        func `the production shape field matches the verified reference`(halfSize: SIMD2<Float>, radii: SIMD4<Float>)
            throws
        {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let production = try String(
                contentsOf: Self.root.appending(path: "Sources/AemiSDR/Shaders/ClearGlass.metal"), encoding: .utf8)
            let reference = try String(
                contentsOf: Self.root.appending(path: "Verification/Reference/GlassSDFReference.metal"), encoding: .utf8
            )
            let productionKernel = """

                kernel void probe(constant float2 *points [[buffer(0)]], device float4 *out [[buffer(1)]],
                                  constant float2 &half_ [[buffer(2)]], constant float4 &radii [[buffer(3)]],
                                  constant uint &n [[buffer(4)]], uint i [[thread_position_in_grid]]) {
                    if (i >= n) return;
                    out[i] = float4(roundedRectField(points[i], half_, radii), 0.0f);
                }
                """
            // The reference takes its radii as (x: bottomLeft, y: bottomRight, z: topRight, w: topLeft) in mode 5.
            let referenceKernel = """

                kernel void probe(constant float2 *points [[buffer(0)]], device float4 *out [[buffer(1)]],
                                  constant SdfU &u [[buffer(2)]], constant uint &n [[buffer(4)]],
                                  uint i [[thread_position_in_grid]]) {
                    if (i >= n) return;
                    float4 f = shape_field(points[i], 5, u);
                    out[i] = float4(f.x, f.y, f.z, 0.0f);
                }
                """
            let points = grid(halfSize: halfSize)
            let ours = try evaluate(
                source: production + productionKernel, kernel: "probe", device: device, points: points,
                block2: [halfSize.x, halfSize.y], block3: [radii.x, radii.y, radii.z, radii.w])
            // The reference takes its radii as (x: bottomLeft, y: bottomRight, z: topRight, w: topLeft) in mode 5.
            let block = [halfSize.x, halfSize.y, 5, 0, 1, 0, 0, 1, radii.z, radii.w, radii.y, radii.x]
            let theirs = try evaluate(
                source: reference + referenceKernel, kernel: "probe", device: device, points: points,
                block2: block, block3: [])
            var largest: Float = 0
            var largestGradient: Float = 0
            for index in points.indices {
                largest = max(largest, abs(ours[index].x - theirs[index].x))
                largestGradient = max(
                    largestGradient, abs(ours[index].y - theirs[index].y), abs(ours[index].z - theirs[index].z))
            }
            #expect(largest < 1e-3, "the distance differs from the verified reference by \(largest) px")
            #expect(largestGradient < 1e-3, "the gradient differs from the verified reference by \(largestGradient)")
            #expect(ours.contains { $0.x < -1 } && ours.contains { $0.x > 1 }, "the grid must cross the edge")
        }

        @Test func `a sharp rectangle is a plain box, with finite gradients at its corners`() throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let production = try String(
                contentsOf: Self.root.appending(path: "Sources/AemiSDR/Shaders/ClearGlass.metal"), encoding: .utf8)
            let kernel = """

                kernel void probe(constant float2 *points [[buffer(0)]], device float4 *out [[buffer(1)]],
                                  constant float2 &half_ [[buffer(2)]], constant float4 &radii [[buffer(3)]],
                                  constant uint &n [[buffer(4)]], uint i [[thread_position_in_grid]]) {
                    if (i >= n) return;
                    out[i] = float4(roundedRectField(points[i], half_, radii), 0.0f);
                }
                """
            let half = SIMD2<Float>(100, 60)
            let points = grid(halfSize: half)
            let result = try evaluate(
                source: production + kernel, kernel: "probe", device: device, points: points,
                block2: [half.x, half.y], block3: [0, 0, 0, 0])
            for (index, point) in points.enumerated() {
                let q = SIMD2(abs(point.x) - half.x, abs(point.y) - half.y)
                let expected =
                    (max(q.x, 0) * max(q.x, 0) + max(q.y, 0) * max(q.y, 0)).squareRoot() + min(max(q.x, q.y), 0)
                #expect(abs(result[index].x - expected) < 1e-3, "distance at \(point)")
                #expect(result[index].y.isFinite && result[index].z.isFinite, "the gradient at \(point) must be finite")
            }
        }

        // MARK: Rendering

        /// Renders the glass over a BGRA source and returns the BGRA result, `view` pixels in size.
        private func render(
            source: [UInt8], sourceSize: (Int, Int), view: (Int, Int), configuration: ClearGlassConfiguration,
            field: [Float]? = nil
        ) throws -> [UInt8] {
            let renderer = try #require(ClearGlassRenderer())
            let device = renderer.device
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: sourceSize.0, height: sourceSize.1, mipmapped: false)
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared
            let sourceTexture = try #require(device.makeTexture(descriptor: descriptor))
            // The array holds exactly width * height BGRA texels.
            unsafe sourceTexture.replace(
                region: MTLRegionMake2D(0, 0, sourceSize.0, sourceSize.1), mipmapLevel: 0, withBytes: source,
                bytesPerRow: sourceSize.0 * 4)
            // A ring outside the shape needs room: the view extends `margin` pixels beyond the shape on every side.
            let margin = Int(configuration.margin)
            let outer = (view.0 + 2 * margin, view.1 + 2 * margin)
            let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: outer.0, height: outer.1, mipmapped: false)
            targetDescriptor.usage = [.renderTarget, .shaderRead]
            targetDescriptor.storageMode = .shared
            let target = try #require(device.makeTexture(descriptor: targetDescriptor))
            let uniforms = configuration.uniforms(
                size: CGSize(width: view.0, height: view.1), scale: 1,
                sourceOrigin: CGPoint(x: -margin, y: -margin),
                sourceSize: CGSize(width: sourceSize.0, height: sourceSize.1))
            let fieldTexture = try field.map {
                try #require(renderer.makeFieldTexture($0, width: outer.0, height: outer.1))
            }
            try #require(
                renderer.renderAndWait(
                    source: sourceTexture, uniforms: uniforms, blur: configuration.blurPlan(scale: 1),
                    field: fieldTexture,
                    target: target))
            var pixels = [UInt8](repeating: 0, count: outer.0 * outer.1 * 4)
            // The destination holds exactly width * height BGRA texels.
            unsafe pixels.withUnsafeMutableBytes {
                if let base = $0.baseAddress {
                    target.getBytes(
                        base, bytesPerRow: outer.0 * 4, from: MTLRegionMake2D(0, 0, outer.0, outer.1), mipmapLevel: 0)
                }
            }
            return pixels
        }

        /// A glass that only blurs: no rim, no lift.
        private var blurOnly: ClearGlassConfiguration {
            ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), blur: .gaussian(2), rimDepth: 0, rimWidth: 1, lift: 0,
                liftFalloff: 0,
                outline: 0)
        }

        @Test func `blurring an impulse gives the exact Gaussian, and keeps its energy`() throws {
            let side = 64
            var source = [UInt8](repeating: 0, count: side * side * 4)
            let centre = (side / 2 * side + side / 2) * 4
            for channel in 0..<3 { source[centre + channel] = 255 }
            source[centre + 3] = 255
            for index in stride(from: 3, to: source.count, by: 4) { source[index] = 255 }
            let pixels = try render(
                source: source, sourceSize: (side, side), view: (side, side), configuration: blurOnly)
            let kernel = GaussianKernel(sigma: 2)
            var worst: Float = 0
            var total: Float = 0
            var quantised: Float = 0
            for y in 0..<side {
                for x in 0..<side {
                    let value = Float(pixels[(y * side + x) * 4 + 2])
                    total += value
                    let dx = abs(x - side / 2)
                    let dy = abs(y - side / 2)
                    let expected =
                        dx <= kernel.radius && dy <= kernel.radius ? 255 * kernel.weights[dx] * kernel.weights[dy] : 0
                    worst = max(worst, abs(value - expected))
                    quantised += expected.rounded()
                }
            }
            #expect(worst <= 1.5, "the blurred impulse differs from the exact Gaussian by \(worst)/255")
            // 8-bit output rounds the faint tails to zero, so the sum is compared with the rounded exact kernel; the
            // kernel itself summing to one is pinned in ClearGlassGeometryTests.
            #expect(
                abs(total - quantised) <= 2, "the blurred sum is \(total), the rounded exact kernel gives \(quantised)")
        }

        struct FlatCase: Sendable, CustomTestStringConvertible {
            let input: [UInt8]
            let expected: [UInt8]
            var testDescription: String { "\(input) -> \(expected)" }
        }

        /// The values read off native clear glass over flat colours (light appearance, 8-bit).
        static let flatCases: [FlatCase] = [
            FlatCase(input: [0, 0, 0], expected: [32, 32, 32]),
            FlatCase(input: [255, 255, 255], expected: [255, 255, 255]),
            FlatCase(input: [128, 128, 128], expected: [154, 154, 154]),
            FlatCase(input: [255, 0, 0], expected: [255, 26, 26]),
            FlatCase(input: [0, 255, 0], expected: [13, 255, 13]),
            FlatCase(input: [0, 0, 255], expected: [30, 30, 255]),
        ]

        @Test(arguments: ClearGlassGPUTests.flatCases)
        func `flat colours come out as they do through native clear glass`(flat: FlatCase) throws {
            let (input, expected) = (flat.input, flat.expected)
            let side = 48
            var source = [UInt8](repeating: 255, count: side * side * 4)
            for index in 0..<(side * side) {
                source[index * 4] = input[2]
                source[index * 4 + 1] = input[1]
                source[index * 4 + 2] = input[0]
            }
            let configuration = ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), blur: .gaussian(0.5), rimDepth: 0, rimWidth: 1, lift: 32.0 / 255,
                liftFalloff: 0.83)
            let pixels = try render(
                source: source, sourceSize: (side, side), view: (side, side), configuration: configuration)
            let centre = (side / 2 * side + side / 2) * 4
            let actual = [pixels[centre + 2], pixels[centre + 1], pixels[centre]]
            for channel in 0..<3 {
                #expect(
                    abs(Int(actual[channel]) - Int(expected[channel])) <= 2,
                    "input \(input): channel \(channel) is \(actual[channel]), native is \(expected[channel])")
            }
        }

        @Test func `a path shape draws what the analytic shape it describes draws`() throws {
            let (width, height) = (200, 140)
            var source = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height {
                for x in 0..<width {
                    let cell = ((x / 8) + (y / 8)) % 2 == 0
                    source[(y * width + x) * 4] = UInt8((x * 255) / width)
                    source[(y * width + x) * 4 + 1] = cell ? 220 : 40
                    source[(y * width + x) * 4 + 2] = UInt8((y * 255) / height)
                }
            }
            let radius: CGFloat = 30
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            let analytic = ClearGlassConfiguration(
                shape: .roundedRect(radii: GlassCornerRadii(radius), curve: .circular), blur: .gaussian(1.5),
                rimDepth: 24,
                rimWidth: 9, lift: 0.1, liftFalloff: 0.7, outline: 0)
            var viaPath = analytic
            viaPath.shape = .path(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            let field = SignedDistanceField.make(
                path: CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil),
                width: width, height: height, scale: 1)
            let expected = try render(
                source: source, sourceSize: (width, height), view: (width, height), configuration: analytic)
            let actual = try render(
                source: source, sourceSize: (width, height), view: (width, height), configuration: viaPath, field: field
            )
            var total = 0
            var far = 0
            for index in expected.indices where index % 4 != 3 {
                let difference = abs(Int(expected[index]) - Int(actual[index]))
                total += difference
                if difference > 12 { far += 1 }
            }
            let count = expected.count / 4 * 3
            #expect(Double(total) / Double(count) < 2.5, "mean difference \(Double(total) / Double(count))/255")
            #expect(
                Double(far) / Double(count) < 0.04,
                "\(100 * Double(far) / Double(count))% of values differ by more than 12/255")
            #expect(expected.contains { $0 != 0 })
        }

        @Test func `the rim shows what lies further inside, and the interior is not distorted`() throws {
            let (width, height) = (240, 120)
            // Blue rises with x, so the value at an edge says where the glass is looking.
            var source = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height {
                for x in 0..<width {
                    source[(y * width + x) * 4] = UInt8(x * 255 / (width - 1))
                    source[(y * width + x) * 4 + 1] = 0
                    source[(y * width + x) * 4 + 2] = 0
                }
            }
            let configuration = ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), blur: .gaussian(0.5), rimDepth: 30, rimWidth: 10, lift: 0,
                liftFalloff: 0,
                outline: 0)
            let pixels = try render(
                source: source, sourceSize: (width, height), view: (width, height), configuration: configuration)
            func blue(_ x: Int, from data: [UInt8]) -> Int { Int(data[(height / 2 * width + x) * 4]) }
            // Two pixels in from the left edge the glass looks about 30 pixels further right: a clearly higher value.
            #expect(blue(2, from: pixels) > blue(2, from: source) + 20, "the left rim must pull from further inside")
            // Mirror: at the right edge it pulls from further left, a lower value.
            #expect(
                blue(width - 3, from: pixels) < blue(width - 3, from: source) - 20,
                "the right rim must pull from further inside")
            // Well inside, the pull is gone and the image is as it was.
            #expect(
                abs(blue(width / 2, from: pixels) - blue(width / 2, from: source)) <= 2,
                "the interior must be undistorted")
        }

        /// Native glass darkens what lies just outside its edge by a constant that falls off linearly: over grey and
        /// white alike it takes 77/255 at half a pixel out and 38/255 at a pixel and a half (measured at 3x).
        @Test(arguments: [UInt8(128), 255])
        func `the ring outside the edge darkens by the measured amounts`(level: UInt8) throws {
            let side = 40
            let source = [UInt8](repeating: level, count: side * side * 4)
            let configuration = ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), blur: .gaussian(0.5), rimDepth: 0, rimWidth: 1, lift: 0,
                liftFalloff: 0,
                outline: 0.3785,
                outlineReach: 2.47)
            let margin = Int(configuration.margin)
            let pixels = try render(
                source: source, sourceSize: (side, side), view: (side, side), configuration: configuration)
            let width = side + 2 * margin
            func value(atDistance outside: Int) -> Int {
                // The shape's left edge is at x = margin; the pixel `outside` columns to its left. The layer is drawn
                // over the backdrop it was built from, so what a viewer sees is the premultiplied colour over it.
                let offset = ((margin + side / 2) * width + margin - 1 - outside) * 4
                let alpha = Double(pixels[offset + 3]) / 255
                return Int((Double(pixels[offset]) + (1 - alpha) * Double(level)).rounded())
            }
            let reference = Int(level)
            #expect(
                abs(value(atDistance: 0) - (reference - 77)) <= 3,
                "half a pixel out: \(value(atDistance: 0)), native takes \(reference - 77)")
            #expect(
                abs(value(atDistance: 1) - (reference - 38)) <= 3,
                "a pixel and a half out: \(value(atDistance: 1)), native takes \(reference - 38)")
            #expect(abs(value(atDistance: 2) - reference) <= 2, "two and a half pixels out the ring is gone")
        }

        @Test func `a ring over black cannot go below black, and the margin is empty when the outline is off`() throws {
            let side = 40
            let configuration = ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), outline: 0.3785, outlineReach: 2.47)
            let pixels = try render(
                source: [UInt8](repeating: 0, count: side * side * 4), sourceSize: (side, side), view: (side, side),
                configuration: configuration)
            let margin = Int(configuration.margin)
            let width = side + 2 * margin
            #expect(pixels[((margin + side / 2) * width + margin - 1) * 4] == 0)
            #expect(ClearGlassConfiguration(outline: 0).margin == 0)
            #expect(ClearGlassConfiguration(outline: 0.3785, outlineReach: 0.82).margin == 2)
        }

        @Test func `the two-Gaussian blur is the isotropic mixture, not a separable product`() throws {
            let side = 96
            var source = [UInt8](repeating: 0, count: side * side * 4)
            let centre = (side / 2 * side + side / 2) * 4
            for channel in 0..<3 { source[centre + channel] = 255 }
            for index in stride(from: 3, to: source.count, by: 4) { source[index] = 255 }
            let blur = ClearGlassBlur(coreRadius: 1.2, haloRadius: 5, coreWeight: 0.3)
            var configuration = blurOnly
            configuration.blur = blur
            let pixels = try render(
                source: source, sourceSize: (side, side), view: (side, side), configuration: configuration)
            let core = GaussianKernel(sigma: 1.2)
            let halo = GaussianKernel(sigma: 5)
            func weight(_ kernel: GaussianKernel, _ offset: Int) -> Float {
                offset <= kernel.radius ? kernel.weights[offset] : 0
            }
            var worst: Float = 0
            var worstCross: Float = 0
            for y in 0..<side {
                for x in 0..<side {
                    let (dx, dy) = (abs(x - side / 2), abs(y - side / 2))
                    // Each Gaussian is the product of its own two one-dimensional kernels; the results add.
                    let isotropic =
                        0.3 * weight(core, dx) * weight(core, dy) + 0.7 * weight(halo, dx) * weight(halo, dy)
                    // What a separable product of the mixed kernel would give instead: cross terms that streak.
                    let mixedX = 0.3 * weight(core, dx) + 0.7 * weight(halo, dx)
                    let mixedY = 0.3 * weight(core, dy) + 0.7 * weight(halo, dy)
                    let value = Float(pixels[(y * side + x) * 4 + 2])
                    worst = max(worst, abs(value - 255 * isotropic))
                    worstCross = max(worstCross, abs(255 * mixedX * mixedY - 255 * isotropic))
                }
            }
            #expect(worst <= 1.5, "the impulse response differs from the isotropic mixture by \(worst)/255")
            #expect(
                worstCross > 2, "the two models must be distinguishable here or this test proves nothing: \(worstCross)"
            )
        }
    }
#endif
