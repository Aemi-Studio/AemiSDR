#if os(macOS)
    import CoreGraphics
    import Foundation
    import Testing

    @testable import AemiSDR

    @Suite("Asynchronous clear-glass still images", .serialized)
    struct ClearGlassImageRendererTests {
        private func source() throws -> CGImage {
            var bytes = [UInt8](repeating: 255, count: 256 * 256 * 4)
            for y in 0..<256 {
                for x in 0..<256 {
                    let offset = (y * 256 + x) * 4
                    bytes[offset] = UInt8((x * 37) % 256)
                    bytes[offset + 1] = UInt8((y * 53) % 256)
                    bytes[offset + 2] = 23
                }
            }
            let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
            let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            return try #require(
                CGImage(
                    width: 256, height: 256, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 256 * 4,
                    space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        }

        @Test func `fractional still-image geometry preserves pixel centres and both image axes`() async throws {
            let renderer = ClearGlassImageRenderer()
            let config = ClearGlassConfiguration(
                shape: .roundedRect(radii: .zero), blur: .gaussian(0), rim: .none, lift: 0,
                rimLight: .none, outline: 0)
            let origin = CGPoint(x: 20.25, y: 30.75)
            let result = try await renderer.render(
                source: source(), origin: origin, size: CGSize(width: 40.2, height: 30.4), scale: 2,
                configuration: config)
            #expect(result.image.width == 81)
            #expect(result.image.height == 61)
            #expect(abs(result.contentRect.midX - CGFloat(result.image.width) / 4) < 1e-10)
            #expect(abs(result.contentRect.midY - CGFloat(result.image.height) / 4) < 1e-10)
            let data = try #require(result.image.dataProvider?.data) as Data
            func expected(_ position: CGFloat, multiplier: Int) -> Int {
                let lower = Int(position.rounded(.down))
                let fraction = Double(position) - Double(lower)
                return Int(
                    (Double((lower * multiplier) % 256) * (1 - fraction)
                        + Double(((lower + 1) * multiplier) % 256) * fraction).rounded())
            }
            for y in stride(from: 2, to: 59, by: 7) {
                for x in stride(from: 2, to: 79, by: 7) {
                    let offset = y * result.image.bytesPerRow + x * 4
                    let sourceX = origin.x * 2 + CGFloat(x) - result.contentRect.minX * 2
                    let sourceY = origin.y * 2 + CGFloat(y) - result.contentRect.minY * 2
                    #expect(abs(Int(data[offset + 2]) - expected(sourceX, multiplier: 37)) <= 1)
                    #expect(abs(Int(data[offset + 1]) - expected(sourceY, multiplier: 53)) <= 1)
                    #expect(data[offset] == 23)
                    #expect(data[offset + 3] == 255)
                }
            }
            #expect(result.totalMilliseconds > 0)
        }

        @Test func `still-image allocation budgets reject work before creating resources`() async throws {
            let renderer = ClearGlassImageRenderer(maximumWorkingBytes: 0)
            await #expect(throws: ClearGlassImageRenderer.RenderError.resourceLimit) {
                try await renderer.render(
                    source: source(), origin: .zero, size: CGSize(width: 40, height: 30), scale: 1,
                    configuration: .nativeClear(shape: .capsule))
            }
        }

        @Test(arguments: [CGFloat.nan, .infinity, -.infinity, 0, -1])
        func `invalid still-image scales return errors rather than trapping`(scale: CGFloat) async throws {
            let renderer = ClearGlassImageRenderer()
            await #expect(throws: ClearGlassImageRenderer.RenderError.invalidGeometry) {
                try await renderer.render(
                    source: source(), origin: .zero, size: CGSize(width: 40, height: 30), scale: scale,
                    configuration: .nativeClear(shape: .capsule))
            }
        }

        @Test func `a cancelled still-image request never returns a publishable image`() async throws {
            let image = try source()
            let renderer = ClearGlassImageRenderer()
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await renderer.render(
                    source: image, origin: .zero, size: CGSize(width: 40, height: 30), scale: 1,
                    configuration: .nativeClear(shape: .capsule))
            }
            await #expect(throws: ClearGlassImageRenderer.RenderError.cancelled) { try await task.value }
        }
    }
#endif
