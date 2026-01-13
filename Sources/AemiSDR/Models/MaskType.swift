//
//  MaskType.swift
//  AemiSDR
//

/// Mask shapes and gradients used for variable blur and alpha masking.
/// Each case maps to a dedicated, optimized shader.
public enum MaskType: Sendable, Equatable, Hashable, CaseIterable {
    /// Linear gradient: top is masked/blurred; bottom is clear.
    case linearTopToBottom

    /// Linear gradient: bottom is masked/blurred; top is clear.
    case linearBottomToTop

    /// Standard rounded rectangle (SDF) with crisp edges.
    case roundedRectangle

    /// Rounded rectangle with eased corner transitions.
    case easedRoundedRectangle

    /// Mathematical superellipse (squircle).
    case superellipseSquircle

    /// Superellipse with eased edge transitions.
    case easedSuperellipseSquircle

    /// Quadratic ease-in gradient: top is masked/blurred; bottom is clear.
    case easeInTopToBottom

    /// Quadratic ease-in gradient: bottom is masked/blurred; top is clear.
    case easeInBottomToTop
}
