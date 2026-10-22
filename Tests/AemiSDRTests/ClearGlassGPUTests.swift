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

        @Test(arguments: [
            SIMD4<Float>(0, 20, 40, 0), SIMD4<Float>(0, -20, -40, 0),
            SIMD4<Float>(20, 0, 40, 50), SIMD4<Float>(0, -20, -40, -50),
            SIMD4<Float>(20, 30, 0, 50), SIMD4<Float>(-20, -30, 0, -50),
        ])
        func `mixed sharp and rounded corners keep finite distances and unit gradients`(radii: SIMD4<Float>) throws {
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
            var points = grid(halfSize: half)
            // Subpixel probes immediately inside/outside each sharp vertex, not just the axes and 45-degree diagonals.
            for sx: Float in [-1, 1] {
                for sy: Float in [-1, 1] {
                    for offset in [SIMD2<Float>(-0.2, -0.7), SIMD2(0.3, 0.8), SIMD2(-0.6, 0.2)] {
                        points.append((half + offset) * SIMD2(sx, sy))
                    }
                }
            }
            let result = try evaluate(
                source: production + kernel, kernel: "probe", device: device, points: points,
                block2: [half.x, half.y], block3: [radii.x, radii.y, radii.z, radii.w])
            try #require(result.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            for (point, field) in zip(points, result) {
                #expect(abs(field.y * field.y + field.z * field.z - 1) < 1e-4, "normal at \(point)")
                if (0..<4).allSatisfy({ radii[$0] >= 0 }) {
                    let index = (point.y < 0 ? 0 : 2) + (point.x < 0 ? 0 : 1)
                    let radius = radii[index]
                    let q = SIMD2(abs(point.x), abs(point.y)) - half + SIMD2(repeating: radius)
                    let outside = SIMD2(max(q.x, 0), max(q.y, 0))
                    let expected =
                        (outside.x * outside.x + outside.y * outside.y).squareRoot()
                        + min(max(q.x, q.y), 0) - radius
                    #expect(abs(field.x - expected) < 0.08, "circular-corner distance at \(point)")
                }
            }
        }

        // MARK: Rendering

        /// Renders the glass over a BGRA source and returns the BGRA result, `view` pixels in size.
        private func render(
            source: [UInt8], sourceSize: (Int, Int), view: (Int, Int), configuration: ClearGlassConfiguration,
            field: GlassDistanceField? = nil, origin: CGPoint = .zero, paired: Bool = true
        ) throws -> [UInt8] {
            let renderer = try #require(ClearGlassRenderer())
            renderer.usesPairedTaps = paired
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
                sourceOrigin: CGPoint(x: origin.x - CGFloat(margin), y: origin.y - CGFloat(margin)),
                sourceSize: CGSize(width: sourceSize.0, height: sourceSize.1))
            let fieldTexture = try field.map {
                try #require(renderer.makeFieldTexture($0))
            }
            var blur = configuration.blurPlan(scale: 1)
            blur.lookReach = configuration.lookReach(
                size: CGSize(width: view.0, height: view.1), scale: 1, field: field)
            try #require(
                renderer.renderAndWait(
                    source: sourceTexture, uniforms: uniforms, blur: blur,
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

        @Test func `paired blur taps preserve displaced textured sampling at fractional positions`() throws {
            let side = 256
            var source = [UInt8](repeating: 255, count: side * side * 4)
            for y in 0..<side {
                for x in 0..<side {
                    for channel in 0..<3 {
                        source[(y * side + x) * 4 + channel] = UInt8((x * 31 + y * 17 + channel * 71) % 256)
                    }
                }
            }
            let configuration = ClearGlassConfiguration(
                shape: .capsule, rim: .nativeClear, lift: 0, chromatic: 0.03, rimLight: .none, outline: 0)
            let expected = try render(
                source: source, sourceSize: (side, side), view: (120, 100), configuration: configuration,
                origin: CGPoint(x: 64, y: 64), paired: false)
            let actual = try render(
                source: source, sourceSize: (side, side), view: (120, 100), configuration: configuration,
                origin: CGPoint(x: 64, y: 64))
            let worst = zip(actual, expected).map { abs(Int($0) - Int($1)) }.max() ?? 255
            #expect(worst <= 1, "paired taps changed fractional displaced sampling by \(worst)/255")
        }

        @Test func `capsule optics use the native continuous field near off-axis joins`() throws {
            let side = 512
            var source = [UInt8](repeating: 255, count: side * side * 4)
            for y in 0..<side {
                for x in 0..<side {
                    let level: UInt8 = x % 11 < 2 || y % 13 < 2 ? 255 : 20
                    for channel in 0..<3 { source[(y * side + x) * 4 + channel] = level }
                }
            }
            let nativeField = ClearGlassConfiguration.nativeClear(shape: .roundedRect(radii: GlassCornerRadii(60)))
            let capsule = ClearGlassConfiguration.nativeClear(shape: .capsule)
            let expected = try render(
                source: source, sourceSize: (side, side), view: (300, 120), configuration: nativeField,
                origin: CGPoint(x: 100, y: 160))
            let actual = try render(
                source: source, sourceSize: (side, side), view: (300, 120), configuration: capsule,
                origin: CGPoint(x: 100, y: 160))
            let worst = zip(actual, expected).map { abs(Int($0) - Int($1)) }.max() ?? 255
            #expect(worst <= 1, "the capsule differs from the native continuous field by \(worst)/255")
        }

        @Test(arguments: [0.0, 0.35, 0.9])
        func `triangle corners preserve a uniform backdrop when the rim looks beyond the shape bounds`(
            chromatic: Double
        )
            throws
        {
            let width = 220
            let height = 200
            let sourceSide = 512
            let path = CGMutablePath()
            path.move(to: CGPoint(x: width / 2, y: 0))
            path.addLine(to: CGPoint(x: width, y: height))
            path.addLine(to: CGPoint(x: 0, y: height))
            path.closeSubpath()
            let field = SignedDistanceField.exact(path: path, width: width, height: height, scale: 1)
            let configuration = ClearGlassConfiguration(
                shape: .path(path), rim: .nativeClear, lift: 0, chromatic: CGFloat(chromatic), rimLight: .none,
                outline: 0)
            var source = [UInt8](repeating: 128, count: sourceSide * sourceSide * 4)
            for index in stride(from: 3, to: source.count, by: 4) { source[index] = 255 }
            let pixels = try render(
                source: source, sourceSize: (sourceSide, sourceSide), view: (width, height),
                configuration: configuration,
                field: field, origin: CGPoint(x: 100, y: 100))
            let interior = field.distance.indices.filter { field.distance[$0] < -1.5 }
            let worst =
                interior.flatMap { index in (0..<3).map { abs(Int(pixels[index * 4 + $0]) - 128) } }.max() ?? 255
            #expect(worst <= 1, "a uniform backdrop acquired a dark wedge: worst error \(worst)/255")
        }

        /// A glass that only blurs: no rim, no lift.
        private var blurOnly: ClearGlassConfiguration {
            ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), blur: .gaussian(2), rim: .none, lift: 0,
                liftFalloff: 0,
                rimLight: .none, outline: 0)
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
                shape: .roundedRect(radii: .zero), blur: .gaussian(0.5), rim: .none, lift: 32.0 / 255,
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
                rim: .gaussian(depth: 24, width: 9), lift: 0.1, liftFalloff: 0.7, rimLight: .none, outline: 0)
            var viaPath = analytic
            viaPath.shape = .path(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            let field = SignedDistanceField.exact(
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
            #expect(Double(total) / Double(count) < 1.2, "mean difference \(Double(total) / Double(count))/255")
            #expect(
                Double(far) / Double(count) < 0.02,
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
                shape: .roundedRect(radii: .zero), blur: .gaussian(0.5), rim: .gaussian(depth: 30, width: 10), lift: 0,
                liftFalloff: 0,
                rimLight: .none, outline: 0)
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
                shape: .roundedRect(radii: .zero), blur: .gaussian(0.5), rim: .none, lift: 0,
                liftFalloff: 0,
                rimLight: .none, outline: 0.3785,
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
            #expect(ClearGlassConfiguration(rimLight: .none, outline: 0).margin == 0)
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

        @Test(arguments: [ClearGlassRim(edgeDepth: 40, edgeFalloff: 3, bodyDepth: 30, bodyWidth: 12), .nativeClear])
        func `the shader pulls by the same amount as the rim function`(rim: ClearGlassRim) throws {
            let (width, height) = (400, 60)
            // Blue rises one level per 1.5 px, so the value read at the left edge says how far the glass looks.
            var source = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height {
                for x in 0..<width {
                    source[(y * width + x) * 4] = UInt8(min(255, Int(Double(x) / 1.5)))
                    source[(y * width + x) * 4 + 1] = 0
                    source[(y * width + x) * 4 + 2] = 0
                }
            }
            let configuration = ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), blur: .gaussian(0.4), rim: rim, lift: 0, liftFalloff: 0,
                rimLight: .none, outline: 0)
            let pixels = try render(
                source: source, sourceSize: (width, height), view: (width, height), configuration: configuration)
            var worst = 0.0
            for depth in [1, 2, 3, 6, 10, 16, 24, 36] {
                // Pixel centre `depth - 0.5` from the edge; the glass looks `pull` pixels further in.
                let x = depth - 1
                let looked = Double(pixels[(height / 2 * width + x) * 4]) * 1.5
                let expected = Double(x) + 0.5 + Double(rim.pull(atDepth: CGFloat(depth) - 0.5))
                worst = max(worst, abs(looked - expected))
            }
            #expect(worst < 3.5, "the shader's pull differs from the rim function by \(worst) px")
        }

        /// The ring follows n.x^2: darkest on the vertical edges, half at 45 degrees, absent on the horizontal edges.
        @Test(arguments: [0.0, 30.0, 45.0, 60.0, 90.0])
        func `the ring outside the edge follows the square of the edge's horizontal part`(degrees: Double) throws {
            let side = 100
            let source = [UInt8](repeating: 128, count: side * side * 4)
            let configuration = ClearGlassConfiguration(
                shape: .circle, blur: .gaussian(0.5), rim: .none, lift: 0, liftFalloff: 0, rimLight: .none,
                outline: 0.3785,
                outlineReach: 2.47)
            let margin = Int(configuration.margin)
            let pixels = try render(
                source: source, sourceSize: (side, side), view: (side, side), configuration: configuration)
            let width = side + 2 * margin
            let centre = Double(margin + side / 2)
            let angle = degrees * .pi / 180
            // The pixel nearest 1.5 px outside the circle in that direction, and its exact distance and direction.
            let target = (x: centre + 51.5 * cos(angle), y: centre + 51.5 * sin(angle))
            let (px, py) = (Int(target.x.rounded(.down)), Int(target.y.rounded(.down)))
            let (dx, dy) = (Double(px) + 0.5 - centre, Double(py) + 0.5 - centre)
            let distance = (dx * dx + dy * dy).squareRoot() - 50
            let nx = dx / (dx * dx + dy * dy).squareRoot()
            let offset = (py * width + px) * 4
            let alpha = Double(pixels[offset + 3]) / 255
            let seen = Double(pixels[offset]) + (1 - alpha) * 128
            let darkening = 0.3785 * nx * nx * max(0, 1 - distance / 2.47) * 255
            #expect(
                abs((128 - seen) - darkening) < 5,
                "at \(degrees) degrees the ring darkens by \(128 - seen), expected \(darkening)")
        }

        /// The inner light follows n.y^2 and rises with the brightness behind it.
        @Test
        func
            `the rim light is brightest on horizontal edges, absent on vertical ones, and stronger over bright backdrops`()
            throws
        {
            let side = 60
            let light = ClearGlassRimLight(
                edgeStrength: 0.5, edgeFalloff: 2, edgePower: 2, tailStrength: 0.06, tailFalloff: 6, tailPower: 2,
                backdropGain: 1.4)
            func render(level: UInt8) throws -> [UInt8] {
                try self.render(
                    source: [UInt8](repeating: level, count: side * side * 4), sourceSize: (side, side),
                    view: (side, side),
                    configuration: ClearGlassConfiguration(
                        shape: .roundedRect(radii: .zero), blur: .gaussian(0.4), rim: .none, lift: 0, liftFalloff: 0,
                        rimLight: light, outline: 0))
            }
            let black = try render(level: 0)
            let gray = try render(level: 128)
            func value(_ pixels: [UInt8], x: Int, y: Int) -> Double { Double(pixels[(y * side + x) * 4]) }
            // Top edge, middle column: row r is r + 0.5 px deep.
            for row in [1, 3] {
                let depth = CGFloat(row) + 0.5
                let expectedBlack = Double(light.contribution(atDepth: depth, backdropLuma: 0)) * 255
                #expect(
                    abs(value(black, x: side / 2, y: row) - expectedBlack) < 3,
                    "black, depth \(depth): \(value(black, x: side / 2, y: row)) against \(expectedBlack)")
                let expectedGray = 128 + Double(light.contribution(atDepth: depth, backdropLuma: 128.0 / 255)) * 255
                #expect(
                    abs(value(gray, x: side / 2, y: row) - expectedGray) < 4,
                    "grey, depth \(depth): \(value(gray, x: side / 2, y: row)) against \(expectedGray)")
            }
            // The bottom edge is the same, and the vertical edges get none.
            #expect(
                abs(value(black, x: side / 2, y: side - 2) - value(black, x: side / 2, y: 1)) < 2,
                "top and bottom match")
            #expect(
                value(black, x: 1, y: side / 2) < 1.5, "the left edge gets no light: \(value(black, x: 1, y: side / 2))"
            )
            #expect(value(black, x: side - 2, y: side / 2) < 1.5, "the right edge gets no light")
            // Over grey the same depth is brighter by the backdrop gain.
            let extraBlack = value(black, x: side / 2, y: 1)
            let extraGray = value(gray, x: side / 2, y: 1) - 128
            #expect(
                extraGray > 1.4 * extraBlack,
                "a brighter backdrop must raise the light: \(extraGray) against \(extraBlack)")
        }

        private func quiet(shape: GlassShape = .roundedRect(radii: .zero), blur: ClearGlassBlur)
            -> ClearGlassConfiguration
        {
            ClearGlassConfiguration(
                shape: shape, blur: blur, rim: .none, lift: 0, liftFalloff: 0, rimLight: .none, outline: 0)
        }

        @Test func `three Gaussians blur an impulse into the isotropic mixture of all three`() throws {
            let side = 96
            var source = [UInt8](repeating: 0, count: side * side * 4)
            let centre = (side / 2 * side + side / 2) * 4
            for channel in 0..<3 { source[centre + channel] = 255 }
            for index in stride(from: 3, to: source.count, by: 4) { source[index] = 255 }
            let blur = ClearGlassBlur(components: [
                .init(radius: 0.8, weight: 0.5), .init(radius: 2.5, weight: 0.3), .init(radius: 6, weight: 0.2),
            ])
            let pixels = try render(
                source: source, sourceSize: (side, side), view: (side, side), configuration: quiet(blur: blur))
            let kernels = [
                (0.5, GaussianKernel(sigma: 0.8)), (0.3, GaussianKernel(sigma: 2.5)), (0.2, GaussianKernel(sigma: 6)),
            ]
            var worst: Float = 0
            for y in 0..<side {
                for x in 0..<side {
                    let (dx, dy) = (abs(x - side / 2), abs(y - side / 2))
                    var expected: Float = 0
                    for (weight, kernel) in kernels where dx <= kernel.radius && dy <= kernel.radius {
                        expected += Float(weight) * kernel.weights[dx] * kernel.weights[dy]
                    }
                    worst = max(worst, abs(Float(pixels[(y * side + x) * 4 + 2]) - 255 * expected))
                }
            }
            #expect(worst <= 1.5, "the impulse response differs from the three-Gaussian mixture by \(worst)/255")
        }

        /// A sharp component at the edge and a wide one inside: an impulse seen from pixels at different depths is blurred
        /// by the mix that depth takes.
        @Test func `the blur mix follows the depth below the edge`() throws {
            let (width, height) = (200, 60)
            var source = [UInt8](repeating: 0, count: width * height * 4)
            let impulse = (height / 2 * width + 8) * 4
            for channel in 0..<3 { source[impulse + channel] = 255 }
            for index in stride(from: 3, to: source.count, by: 4) { source[index] = 255 }
            let blur = ClearGlassBlur(
                components: [
                    .init(radius: 1, edgeWeight: 1, innerWeight: 0), .init(radius: 4, edgeWeight: 0, innerWeight: 1),
                ],
                rampDepth: 20, rampCurve: 1)
            let pixels = try render(
                source: source, sourceSize: (width, height), view: (width, height), configuration: quiet(blur: blur))
            let (sharp, wide) = (GaussianKernel(sigma: 1), GaussianKernel(sigma: 4))
            func g(_ kernel: GaussianKernel, _ offset: Int) -> Float {
                offset <= kernel.radius ? kernel.weights[offset] : 0
            }
            var worst: Float = 0
            for x in 0..<24 {
                // Pixel x is x + 0.5 deep; the ramp is smoothstep over 20 px.
                let ramp = min(Float(x) + 0.5, 20) / 20
                let t = ramp * ramp * (3 - 2 * ramp)
                let expected =
                    255 * ((1 - t) * g(sharp, abs(x - 8)) * g(sharp, 0) + t * g(wide, abs(x - 8)) * g(wide, 0))
                worst = max(worst, abs(Float(pixels[(height / 2 * width + x) * 4 + 2]) - expected))
            }
            #expect(worst <= 1.5, "the depth-dependent blur differs from the exact mix by \(worst)/255")
        }

        @Test func `the veil takes the colour it is given, and no lift removes it`() throws {
            let side = 40
            let source = [UInt8](repeating: 0, count: side * side * 4)
            var configuration = ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), blur: .gaussian(0.5), rim: .none, lift: 0.2, liftFalloff: 0,
                veilColor: ClearGlassColor(red: 1, green: 0.5, blue: 0), rimLight: .none, outline: 0)
            var pixels = try render(
                source: source, sourceSize: (side, side), view: (side, side), configuration: configuration)
            let centre = (side / 2 * side + side / 2) * 4
            #expect(
                abs(Int(pixels[centre + 2]) - 51) <= 1 && abs(Int(pixels[centre + 1]) - 26) <= 1 && pixels[centre] <= 1,
                "RGB \(pixels[centre + 2]) \(pixels[centre + 1]) \(pixels[centre])")
            configuration.lift = 0
            pixels = try render(
                source: source, sourceSize: (side, side), view: (side, side), configuration: configuration)
            #expect(
                pixels[centre] == 0 && pixels[centre + 1] == 0 && pixels[centre + 2] == 0,
                "with no lift, black stays black")
        }

        @Test func `chromatic fringing is off by default and separates the channels when asked`() throws {
            let (width, height) = (300, 40)
            var source = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height {
                for x in 0..<width {
                    let v = UInt8(x * 255 / (width - 1))
                    source[(y * width + x) * 4] = v
                    source[(y * width + x) * 4 + 1] = v
                    source[(y * width + x) * 4 + 2] = v
                }
            }
            var configuration = ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), blur: .gaussian(0.4), rim: .gaussian(depth: 30, width: 10), lift: 0,
                liftFalloff: 0, rimLight: .none, outline: 0)
            func channels(_ pixels: [UInt8]) -> (r: Int, g: Int, b: Int) {
                let offset = (height / 2 * width + 3) * 4
                return (Int(pixels[offset + 2]), Int(pixels[offset + 1]), Int(pixels[offset]))
            }
            let plain = channels(
                try render(
                    source: source, sourceSize: (width, height), view: (width, height), configuration: configuration))
            #expect(plain.r == plain.g && plain.g == plain.b, "no fringing by default: \(plain)")
            configuration.chromatic = 0.2
            let fringed = channels(
                try render(
                    source: source, sourceSize: (width, height), view: (width, height), configuration: configuration))
            #expect(fringed.r > fringed.g && fringed.g > fringed.b, "red is pulled furthest, blue least: \(fringed)")
            // The pull at 3.5 px deep is about 29 px; 20% of it is about 5.8 px, which the ramp (0.85 level per px) shows as about 5.
            #expect(
                abs(Double(fringed.r - fringed.g) - 5) <= 1.5 && abs(Double(fringed.g - fringed.b) - 5) <= 1.5,
                "\(fringed)")
        }

        /// An impulse spreads a wide Gaussian below the 8-bit floor, so the wide components are checked on a step edge.
        @Test func `three Gaussians blur a step edge into the weighted sum of three error functions`() throws {
            let (width, height) = (160, 24)
            var source = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height {
                for x in 0..<width where x < width / 2 {
                    source[(y * width + x) * 4] = 0
                    source[(y * width + x) * 4 + 1] = 0
                    source[(y * width + x) * 4 + 2] = 0
                }
            }
            let blur = ClearGlassBlur(components: [
                .init(radius: 0.8, weight: 0.5), .init(radius: 2.5, weight: 0.3), .init(radius: 6, weight: 0.2),
            ])
            let pixels = try render(
                source: source, sourceSize: (width, height), view: (width, height), configuration: quiet(blur: blur))
            let kernels = [
                (0.5, GaussianKernel(sigma: 0.8)), (0.3, GaussianKernel(sigma: 2.5)), (0.2, GaussianKernel(sigma: 6)),
            ]
            func blurred(at x: Int) -> Double {
                var total = 0.0
                for (weight, kernel) in kernels {
                    var sum = Double(kernel.weights[0]) * (x >= width / 2 ? 255 : 0)
                    for offset in 1...kernel.radius {
                        let (right, left) = (min(width - 1, x + offset), max(0, x - offset))
                        sum +=
                            Double(kernel.weights[offset])
                            * ((right >= width / 2 ? 255 : 0) + (left >= width / 2 ? 255 : 0))
                    }
                    total += weight * sum
                }
                return total
            }
            var worst = 0.0
            for x in (width / 2 - 14)..<(width / 2 + 14) {
                worst = max(worst, abs(Double(pixels[(height / 2 * width + x) * 4 + 2]) - blurred(at: x)))
            }
            #expect(worst <= 2.0, "the blurred step differs from the weighted sum by \(worst)/255")
        }
    }
#endif
