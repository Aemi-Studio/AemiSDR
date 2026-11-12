import Foundation

/// A blur, as a value (ADR-0009): its shape (uniform, or variable under a mask), its radius, and the colour filters that follow it.
public struct BlurRecipe: Sendable, Equatable {
    public enum Shape: Sendable, Equatable {
        case uniform
        case variable(BlurMask)
    }

    public var shape: Shape
    /// The blur radius in points; zero, negative or not finite: no blur.
    public var radius: Double
    /// `colorSaturate`'s amount after the blur; 1 leaves colour as it is.
    public var saturation: Double = 1
    /// `colorBrightness`'s amount after the blur; 0 leaves brightness as it is.
    public var brightness: Double = 0
    /// Smooths the blur's edges where it meets unblurred content.
    public var normalizesEdges = true
    /// The resolution the backdrop is captured at, relative to the screen's; below 1 is cheaper and softer.
    public var captureScale: Double = 1

    public init(shape: Shape, radius: Double) {
        self.shape = shape
        self.radius = radius
    }

    public static func uniform(radius: Double) -> Self { Self(shape: .uniform, radius: radius) }
    public static func variable(radius: Double, mask: BlurMask) -> Self { Self(shape: .variable(mask), radius: radius) }
}
