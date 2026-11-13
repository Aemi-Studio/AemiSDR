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

    @Test func `the fall is cubic, so the blur comes back gradually instead of along a line`() throws {
        let mask = BlurMask.edge(.top, solid: 0, fade: 1)
        let rows = BlurMaskImages.rows
        let middle = BlurMaskImages.alpha(row: (rows - 1) / 2, of: mask)
        #expect(abs(middle - 0.125) < 0.02, "half way through the fall, an eighth of the radius")
        #expect(BlurMaskImages.alpha(row: rows - 1, of: mask) == 0)
    }

    @Test func `an around mask is full in the middle and falls to nothing at every side`() throws {
        let mask = BlurMask.around(width: 200, height: 100, fade: 25)
        #expect(mask.solidFractionX == 0.75 && mask.solidFraction == 0.5)
        let last = BlurMaskImages.rows - 1
        let middle = last / 2
        #expect(BlurMaskImages.alpha(column: middle, row: middle, of: mask) == 1)
        for (column, row) in [(0, middle), (last, middle), (middle, 0), (middle, last), (0, 0)] {
            #expect(BlurMaskImages.alpha(column: column, row: row, of: mask) == 0)
        }
        let image = try #require(BlurMaskImages.image(for: mask))
        #expect(image.width == BlurMaskImages.rows && image.height == BlurMaskImages.rows)
    }

    @Test func `a corner mask is full at its corner and along its sides, and falls to nothing at the two others`() {
        let mask = BlurMask.corner(.topTrailing, width: 100, height: 80, fade: 20)
        #expect(mask.solidFractionX == 0.8 && mask.solidFraction == 0.75)
        let last = BlurMaskImages.rows - 1
        #expect(BlurMaskImages.alpha(column: last, row: 0, of: mask) == 1, "the corner")
        #expect(BlurMaskImages.alpha(column: last, row: last / 2, of: mask) == 1, "along the trailing side")
        #expect(BlurMaskImages.alpha(column: last / 2, row: 0, of: mask) == 1, "along the top")
        #expect(BlurMaskImages.alpha(column: 0, row: 0, of: mask) == 0, "the leading side")
        #expect(BlurMaskImages.alpha(column: last, row: last, of: mask) == 0, "the bottom")
    }

    @Test func `an under mask is full along its edge in the middle, and falls away from it and towards both ends`() {
        let mask = BlurMask.under(top: true, width: 200, height: 80, solid: 40, endFade: 25)
        #expect(mask.solidFraction == 0.5 && mask.solidFractionX == 0.75)
        let last = BlurMaskImages.rows - 1
        #expect(BlurMaskImages.alpha(column: last / 2, row: 0, of: mask) == 1)
        #expect(BlurMaskImages.alpha(column: last / 2, row: last / 3, of: mask) == 1, "the solid part")
        #expect(BlurMaskImages.alpha(column: last / 2, row: last, of: mask) == 0, "the far side")
        #expect(BlurMaskImages.alpha(column: 0, row: 0, of: mask) == 0, "the leading end")
        #expect(BlurMaskImages.alpha(column: last, row: 0, of: mask) == 0, "the trailing end")
    }
}
