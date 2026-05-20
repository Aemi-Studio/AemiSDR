//
//  LiquidLensFalloff.swift
//  AemiSDR
//

/// Falloff curve controlling how the lens-effect *intensity envelope*
/// transitions from center to edge. This envelope multiplies the physical
/// angular profile (which the shader now computes per-fragment via the
/// `refract()` 3D form). The default `.exponential` (quartic ease-in)
/// concentrates the boost at the rim.
public enum LiquidLensFalloff: Int, Sendable, Equatable, Hashable, CaseIterable {
    /// Linear: f(t) = t.
    case linear = 0
    /// Quadratic ease-in: f(t) = t².
    case easeIn = 1
    /// Quadratic ease-out: f(t) = 1 − (1 − t)².
    case easeOut = 2
    /// Hermite cubic smoothstep: f(t) = t²·(3 − 2t). C¹ continuous.
    case easeInOut = 3
    /// Cubic ease-in: f(t) = t³.
    ///
    /// (The name "Cubic" refers to the exponent; mathematically this is a
    /// cubic ease-in, not a Hermite cubic or B-spline cubic.)
    case cubic = 4
    /// Quartic ease-in: f(t) = t⁴.
    ///
    /// (The name "Exponential" is historical/aesthetic — this is a quartic
    /// polynomial, not an exponential `e^t`-style decay. It concentrates
    /// effect at the rim more aggressively than `.cubic`.)
    case exponential = 5
}
