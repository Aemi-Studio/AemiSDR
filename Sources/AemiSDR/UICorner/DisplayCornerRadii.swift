//
//  DisplayCornerRadii.swift
//  AemiSDR
//

import CoreGraphics

/// The radius of each corner of a display, in points.
///
/// Most displays are uniform, and `UIScreen.displayCornerRadius` was enough. The iPhone Duo is not: the iOS 27.2
/// simulator reports 8 pt for its two hinge-side corners and 59 pt for the other two, through the scene's corner
/// configuration, while the scalar APIs report only 59 (diary 2026-10-20-02). A single number rounds corners the
/// hardware leaves nearly square, so the per-corner values are the primary API and the scalar is derived from them.
///
/// Corners are physical (`topLeft`, not leading), as the system reports them.
public struct DisplayCornerRadii: Sendable, Equatable, Hashable {
    public var topLeft: CGFloat
    public var topRight: CGFloat
    public var bottomLeft: CGFloat
    public var bottomRight: CGFloat

    public init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    /// Four equal corners.
    public init(uniform radius: CGFloat) {
        self.init(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
    }

    public static let zero = DisplayCornerRadii(uniform: 0)

    /// Whether all four corners are the same.
    public var isUniform: Bool {
        topLeft == topRight && topRight == bottomLeft && bottomLeft == bottomRight
    }

    /// The largest corner: the conservative single value for content that must clear every corner.
    public var maximum: CGFloat {
        max(max(topLeft, topRight), max(bottomLeft, bottomRight))
    }

    /// Whether every corner is a usable radius (finite and not negative).
    var isValid: Bool {
        [topLeft, topRight, bottomLeft, bottomRight].allSatisfy { $0.isFinite && $0 >= 0 }
    }
}
