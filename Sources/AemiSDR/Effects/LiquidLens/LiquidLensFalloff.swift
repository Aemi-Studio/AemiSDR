//
//  LiquidLensFalloff.swift
//  AemiSDR
//

/// Falloff curve controlling how the lens effect intensity transitions from center to edge.
public enum LiquidLensFalloff: Int, Sendable, Equatable, Hashable, CaseIterable {
    /// Linear: f(t) = t
    case linear = 0
    /// Ease-in: f(t) = t²
    case easeIn = 1
    /// Ease-out: f(t) = 1 - (1-t)²
    case easeOut = 2
    /// Ease-in-out: smoothstep
    case easeInOut = 3
    /// Cubic: f(t) = t³
    case cubic = 4
    /// Exponential: f(t) = t⁴
    case exponential = 5
}
