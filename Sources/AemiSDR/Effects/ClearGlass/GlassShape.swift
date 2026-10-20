//
//  GlassShape.swift
//  AemiSDR
//
//  The shape of a piece of glass. A rounded rectangle has a radius for each corner and a curve: `.continuous` is the
//  corner native glass uses (its extent is 1.528665 times the radius and it bulges toward the pointy corner),
//  `.circular` is a plain quarter circle. A path can be anything.
//

import CoreGraphics

/// The radius of each corner, in points. A radius of zero is a sharp corner.
public struct GlassCornerRadii: Equatable, Sendable {
    public var topLeading: CGFloat
    public var topTrailing: CGFloat
    public var bottomLeading: CGFloat
    public var bottomTrailing: CGFloat

    public init(topLeading: CGFloat, topTrailing: CGFloat, bottomLeading: CGFloat, bottomTrailing: CGFloat) {
        self.topLeading = topLeading
        self.topTrailing = topTrailing
        self.bottomLeading = bottomLeading
        self.bottomTrailing = bottomTrailing
    }

    /// The same radius on every corner.
    public init(_ radius: CGFloat) {
        self.init(topLeading: radius, topTrailing: radius, bottomLeading: radius, bottomTrailing: radius)
    }

    public static let zero = GlassCornerRadii(0)
}

public enum GlassCornerCurve: Equatable, Sendable {
    /// A quarter circle.
    case circular
    /// The continuous corner of native glass.
    case continuous
}

public enum GlassShape: Equatable, @unchecked Sendable {
    /// A rounded rectangle filling the view.
    case roundedRect(radii: GlassCornerRadii, curve: GlassCornerCurve = .continuous)
    /// A rounded rectangle whose radius is half its shorter side.
    case capsule
    /// An ellipse inscribed in the view (a circle when the view is square).
    case circle
    /// Any closed path, in the view's coordinate space (points, origin top left).
    case path(CGPath)

    /// The signed pixel radii the shader expects: (topLeft, topRight, bottomLeft, bottomRight), negative for a
    /// continuous corner. Only meaningful for the analytic shapes.
    func shaderRadii(size: CGSize, scale: CGFloat) -> SIMD4<Float> {
        let half = min(size.width, size.height) / 2 * scale
        func pixels(_ points: CGFloat, _ curve: GlassCornerCurve) -> Float {
            let value = Float(min(max(points * scale, 0), half))
            // A sharp corner is a plain zero: a negative zero is a different bit pattern the shader would have to special-case.
            return curve == .continuous && value > 0 ? -value : value
        }
        switch self {
        case .roundedRect(let radii, let curve):
            return SIMD4(
                pixels(radii.topLeading, curve), pixels(radii.topTrailing, curve),
                pixels(radii.bottomLeading, curve), pixels(radii.bottomTrailing, curve))
        case .capsule, .circle:
            // A circle is the capsule of a square: the ends are circular whatever the curve.
            let value = Float(half)
            return SIMD4(repeating: value)
        case .path:
            return .zero
        }
    }
}
