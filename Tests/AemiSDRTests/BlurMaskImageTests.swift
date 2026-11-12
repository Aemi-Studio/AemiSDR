import CoreGraphics
import Testing

@testable import AemiSDR

/// Roadmap 0020 slice 1: the mask image a variable blur reads (alpha 1 = full blur, 0 = none), made once per shape.
@MainActor @Suite("Blur mask image") struct BlurMaskImageTests {
    /// The alpha of the image's pixel rows, top first.
    private func alphas(_ image: CGImage) -> [UInt8] {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return [] }
        return (0..<height).map { pixels[$0 * width * 4 + 3] }
    }

    @Test func `a top edge mask is full over its solid part and falls to nothing at the far end`() throws {
        let image = try #require(BlurMaskImages.image(for: .edge(.top, solid: 1, fade: 1)))
        let rows = alphas(image)
        #expect(rows.first == 255 && rows.last == 0)
        #expect(rows[rows.count / 2 - 1] == 255, "the top half is solid")
        #expect(zip(rows, rows.dropFirst()).allSatisfy { $0 >= $1 }, "never rises towards the far end")
    }

    @Test func `a bottom edge mask is the top one upside down`() throws {
        let top = alphas(try #require(BlurMaskImages.image(for: .edge(.top, solid: 1, fade: 3))))
        let bottom = alphas(try #require(BlurMaskImages.image(for: .edge(.bottom, solid: 1, fade: 3))))
        #expect(bottom == top.reversed())
    }

    @Test func `the same shape gives the same image object: a resize does no mask work`() {
        let first = BlurMaskImages.image(for: .edge(.top, solid: 38, fade: 38))
        let again = BlurMaskImages.image(for: .edge(.top, solid: 76, fade: 76))
        #expect(first != nil && first === again)
    }
}
