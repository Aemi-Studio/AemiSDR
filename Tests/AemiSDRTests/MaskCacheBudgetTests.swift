import CoreGraphics
import Testing

@testable import AemiSDR

@Suite("Mask cache byte budget", .serialized)
struct MaskCacheBudgetTests {
    @Test func `full size RGBA masks do not retain more than 32 MiB in the shared cache`() throws {
        unsafe MaskCache.storage.removeAllObjects()
        defer { unsafe MaskCache.storage.removeAllObjects() }
        var keys: [MaskCacheKey] = []
        for index in 0..<4 {
            let image = try makeImage(width: 2048, height: 2048)
            #expect(image.bitsPerPixel == 32)
            let key = MaskCacheKey.make(
                size: CGSize(width: 2048, height: 2048), scale: 1, maskType: .uniform,
                startOffset: CGFloat(100 + index), cornerRadius: 0, fadeWidth: 0, inverted: false)
            keys.append(key)
            MaskCache.insert(image, for: key)
        }
        let retainedBytes = keys.compactMap { MaskCache.peek(for: $0) }.reduce(0) { $0 + $1.bytesPerRow * $1.height }
        #expect(retainedBytes <= 32 * 1024 * 1024)
    }

    private func makeImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(
            unsafe CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }
}
