#if os(macOS)
    import Foundation
    import Metal
    import Testing

    @Suite("LiquidLens shader math", .enabled(if: MTLCreateSystemDefaultDevice() != nil, "Requires a Metal device"))
    struct LiquidLensShaderTests {
        @Test(arguments: [Float(-1), 0, 0.5])
        func `conic tilt matches the normalized surface normal`(conic: Float) async throws {
            let actual = try await evaluate(
                "surfaceTilt(input, 1.0f, \(conic), 0.0f, 0.0f)", input: 0.5)
            // Differentiate the conic sag, then normalize its surface normal.
            let slope: Float = 0.5 / sqrt(1 - (1 + conic) * 0.25)
            let expected = slope / sqrt(1 + slope * slope)
            #expect(abs(actual - expected) < 0.00001)
        }

        @Test(arguments: [Float(0), 0.5, 0.99])
        func `two surface displacement follows Snell angles including total reflection`(sine: Float) async throws {
            let actual = try await evaluate(
                "refractDisplacementThick(float2(1, 0), input, sqrt(1 - input * input), 0.751f).x",
                input: sine)
            let theta = asin(sine)
            let interiorAngle = asin(0.751 * sine)
            let exitSine = sin(2 * theta - interiorAngle) / 0.751
            let expected: Float = exitSine > 1 ? 0 : -tan(asin(exitSine) - theta)
            #expect(actual.isFinite)
            #expect(abs(actual - expected) < 0.00001)
        }

        private func evaluate(_ expression: String, input: Float) async throws -> Float {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let sourceURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Sources/AemiSDR/Shaders/LiquidLens.metal")
            let source =
                try String(contentsOf: sourceURL, encoding: .utf8) + """

                    kernel void testLens(device float *result [[buffer(0)]],
                                         constant float &input [[buffer(1)]]) {
                        result[0] = \(expression);
                    }
                    """
            let library = try await device.makeLibrary(source: source, options: nil)
            let constants = MTLFunctionConstantValues()
            var enabled = true
            // Metal copies one Bool from this live value during the synchronous call.
            unsafe constants.setConstantValue(&enabled, type: .bool, index: 4)
            let function = try await library.makeFunction(name: "testLens", constantValues: constants)
            let pipeline = try await device.makeComputePipelineState(function: function)
            let output = try #require(
                device.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared))
            let queue = try #require(device.makeCommandQueue())
            let command = try #require(queue.makeCommandBuffer())
            let encoder = try #require(command.makeComputeCommandEncoder())
            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(output, offset: 0, index: 0)
            var input = input
            // The copied input and GPU output each occupy exactly one Float.
            unsafe encoder.setBytes(&input, length: MemoryLayout<Float>.stride, index: 1)
            encoder.dispatchThreads(
                MTLSize(width: 1, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
            encoder.endEncoding()
            await withCheckedContinuation { continuation in
                command.addCompletedHandler { _ in continuation.resume() }
                command.commit()
            }
            try #require(command.status == .completed)
            // Completion guarantees the GPU initialized the shared, Float-aligned allocation.
            return unsafe output.contents().load(as: Float.self)
        }
    }
#endif
