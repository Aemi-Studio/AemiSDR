import CoreGraphics

/// The image of each mask, made once (ADR-0009): the mask is a fraction of its layer, so the image is stretched to whatever size the
/// layer has and a resize makes nothing new. A few kilobytes each; masks are few (one per shape a host uses).
@MainActor
enum BlurMaskImages {
    /// Rows in the image: enough for a smooth ramp once stretched over a bar (128 rows, probed: diary 2026-11-12-01).
    static let rows = 128
    private static let columns = 4
    private static var cache: [BlurMask: CGImage] = [:]

    static func image(for mask: BlurMask) -> CGImage? {
        if let cached = cache[mask] { return cached }
        guard let made = make(mask) else { return nil }
        cache[mask] = made
        return made
    }

    /// Alpha per row, top first: 1 over the solid part from the edge, then a straight fall to 0.
    static func alpha(row: Int, of mask: BlurMask) -> Double {
        let fromEdge = Double(mask.edge == .top ? row : rows - 1 - row) / Double(rows - 1)
        guard fromEdge > mask.solidFraction else { return 1 }
        let fade = 1 - mask.solidFraction
        return fade > 0 ? max(0, 1 - (fromEdge - mask.solidFraction) / fade) : 0
    }

    private static func make(_ mask: BlurMask) -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: columns, height: rows, bitsPerComponent: 8, bytesPerRow: columns * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        for row in 0..<rows {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha(row: row, of: mask)))
            // The context's origin is at the bottom: the image's top row is drawn at the highest y.
            context.fill(CGRect(x: 0, y: rows - 1 - row, width: columns, height: 1))
        }
        return context.makeImage()
    }
}
