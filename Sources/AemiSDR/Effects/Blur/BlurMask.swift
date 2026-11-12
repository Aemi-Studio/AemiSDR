import Foundation

/// Where a variable blur is strong (ADR-0009). An edge mask is full blur over its solid part, at the edge, then falls to none at the
/// far side. It is a fraction of the layer it is drawn on, so its image does not depend on the layer's size.
public struct BlurMask: Sendable, Hashable {
    /// The edge the blur is strongest at; `around` is strongest in the middle and falls towards every side; `corner` is strongest
    /// at a corner and along its two sides, and falls towards the two others.
    public enum Edge: Sendable, Hashable {
        case top, bottom, around
        case corner(Corner)
    }

    public enum Corner: Sendable, Hashable { case topLeading, topTrailing, bottomLeading, bottomTrailing }

    public let edge: Edge
    /// The part of the layer, from the edge, that is fully blurred (0 to 1); the rest fades to none.
    public let solidFraction: Double
    /// For `around` and `corner`: the part of the width that is fully blurred (1 for the edge masks).
    public var solidFractionX = 1.0

    /// A mask over `solid + fade` points: full for `solid`, then falling to none over `fade`. Negative lengths count as zero; with
    /// no fade at all the whole layer is solid.
    public static func edge(_ edge: Edge, solid: Double, fade: Double) -> Self {
        let solid = solid.isFinite ? max(solid, 0) : 0
        let fade = fade.isFinite ? max(fade, 0) : 0
        guard fade > 0 else { return Self(edge: edge, solidFraction: 1) }
        return Self(edge: edge, solidFraction: solid / (solid + fade))
    }

    /// A mask over a layer of `width` × `height` points: full in the middle, falling to none over `fade` points towards every side
    /// (a panel's blur that fades out around it, with no edge of its own).
    public static func around(width: Double, height: Double, fade: Double) -> Self {
        func solid(_ length: Double) -> Double {
            guard length.isFinite, length > 0, fade.isFinite, fade > 0 else { return 1 }
            return min(max((length - 2 * fade) / length, 0), 1)
        }
        return Self(edge: .around, solidFraction: solid(height), solidFractionX: solid(width))
    }

    /// A mask over a layer of `width` × `height` points: full from `corner` along its two sides, falling to none over the last `fade`
    /// points towards the two other sides (a panel set in a corner whose blur reaches the corner and fades out into the content).
    public static func corner(_ corner: Corner, width: Double, height: Double, fade: Double) -> Self {
        func solid(_ length: Double) -> Double {
            guard length.isFinite, length > 0, fade.isFinite, fade > 0 else { return 1 }
            return min(max((length - fade) / length, 0), 1)
        }
        return Self(edge: .corner(corner), solidFraction: solid(height), solidFractionX: solid(width))
    }
}
