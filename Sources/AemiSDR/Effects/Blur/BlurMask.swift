import Foundation

/// Where a variable blur is strong (ADR-0009). An edge mask is full blur over its solid part, at the edge, then falls to none at the
/// far side. It is a fraction of the layer it is drawn on, so its image does not depend on the layer's size.
public struct BlurMask: Sendable, Hashable {
    /// The edge the blur is strongest at.
    public enum Edge: Sendable, Hashable { case top, bottom }

    public let edge: Edge
    /// The part of the layer, from the edge, that is fully blurred (0 to 1); the rest fades to none.
    public let solidFraction: Double

    /// A mask over `solid + fade` points: full for `solid`, then falling to none over `fade`. Negative lengths count as zero; with
    /// no fade at all the whole layer is solid.
    public static func edge(_ edge: Edge, solid: Double, fade: Double) -> Self {
        let solid = solid.isFinite ? max(solid, 0) : 0
        let fade = fade.isFinite ? max(fade, 0) : 0
        guard fade > 0 else { return Self(edge: edge, solidFraction: 1) }
        return Self(edge: edge, solidFraction: solid / (solid + fade))
    }
}
