import CoreGraphics

/// The image of each mask, made once (ADR-0009): the mask is a fraction of its layer, so the image is stretched to whatever size the
/// layer has and a resize makes nothing new. A few kilobytes each; masks are few (one per shape a host uses).
@MainActor
enum BlurMaskImages {
    /// Rows in the image: enough for a smooth ramp once stretched over a bar (128 rows, probed: diary 2026-11-12-01).
    static let rows = 128
    /// Columns: an edge mask is the same across; `around` needs as many as rows.
    private static func columns(_ mask: BlurMask) -> Int { mask.edge == .top || mask.edge == .bottom ? 4 : rows }
    private static var cache: [BlurMask: CGImage] = [:]

    static func image(for mask: BlurMask) -> CGImage? {
        if let cached = cache[mask] { return cached }
        guard let made = make(mask) else { return nil }
        cache[mask] = made
        return made
    }

    /// Alpha per row, top first, for an edge mask: 1 over the solid part from the edge, then a cubic fall to 0. The alpha scales
    /// the blur's radius, and fine detail is gone at a small part of it: with a straight fall the content stays blurred out until
    /// the last few points and comes back along a line. The cubic gives most of the fall to small radii, where the eye still sees
    /// them change (probed: diary 2026-11-13-01).
    static func alpha(row: Int, of mask: BlurMask) -> Double {
        switch mask.edge {
        case .top: fall(Double(row) / Double(rows - 1), solid: mask.solidFraction)
        case .bottom: fall(Double(rows - 1 - row) / Double(rows - 1), solid: mask.solidFraction)
        case .around, .corner, .under: alpha(column: (rows - 1) / 2, row: row, of: mask)
        }
    }

    /// Alpha at a pixel: for `around`, the product of the falls from the middle across and down (soft corners); for `corner`, of
    /// the falls from the corner's two sides; else the row's.
    static func alpha(column: Int, row: Int, of mask: BlurMask) -> Double {
        let last = Double(rows - 1)
        func fromMiddle(_ index: Int) -> Double { abs(2 * Double(index) / last - 1) }
        switch mask.edge {
        case .top, .bottom: return alpha(row: row, of: mask)
        case .around:
            return fall(fromMiddle(column), solid: mask.solidFractionX)
                * fall(fromMiddle(row), solid: mask.solidFraction)
        case .corner(let corner):
            let leading = corner == .topLeading || corner == .bottomLeading
            let top = corner == .topLeading || corner == .topTrailing
            let x = leading ? Double(column) / last : 1 - Double(column) / last
            let y = top ? Double(row) / last : 1 - Double(row) / last
            return fall(x, solid: mask.solidFractionX) * fall(y, solid: mask.solidFraction)
        case .under(let top):
            let y = top ? Double(row) / last : 1 - Double(row) / last
            return fall(fromMiddle(column), solid: mask.solidFractionX) * fall(y, solid: mask.solidFraction)
        }
    }

    /// 1 up to `solid` (0 to 1 from the strong side), then a cubic fall to 0 at 1.
    private static func fall(_ position: Double, solid: Double) -> Double {
        guard position > solid else { return 1 }
        let fade = 1 - solid
        let linear = fade > 0 ? max(0, 1 - (position - solid) / fade) : 0
        return linear * linear * linear
    }

    private static func make(_ mask: BlurMask) -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: columns(mask), height: rows, bitsPerComponent: 8, bytesPerRow: columns(mask) * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        for row in 0..<rows {
            for column in 0..<columns(mask) where (mask.edge != .top && mask.edge != .bottom) || column == 0 {
                let alpha = alpha(column: column, row: row, of: mask)
                context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha))
                // The context's origin is at the bottom: the image's top row is drawn at the highest y. An edge mask's row is
                // one rectangle across.
                let width = mask.edge == .top || mask.edge == .bottom ? columns(mask) : 1
                context.fill(CGRect(x: column, y: rows - 1 - row, width: width, height: 1))
            }
        }
        return context.makeImage()
    }
}
