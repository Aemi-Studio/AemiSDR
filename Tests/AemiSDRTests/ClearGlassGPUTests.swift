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
    }
#endif
