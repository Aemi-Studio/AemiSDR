//
//  LiquidLensMaterial.swift
//  AemiSDR
//

/// Optical material type for the liquid lens effect.
///
/// Each material has distinct Sellmeier dispersion coefficients that determine
/// how much the refractive index varies with wavelength, producing different
/// amounts of chromatic aberration.
public enum LiquidLensMaterial: Int, Sendable, Equatable, Hashable, CaseIterable {
    /// BK7 Crown Glass — low dispersion, common optical glass.
    case crownGlass = 0
    /// SF11 Flint Glass — high dispersion, used in prisms.
    case flintGlass = 1
    /// Water at 20°C.
    case water = 2
    /// PMMA (Acrylic/Plexiglass).
    case acrylic = 3
    /// Diamond — very high refractive index.
    case diamond = 4
}
