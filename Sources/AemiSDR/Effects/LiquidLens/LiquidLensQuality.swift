//
//  LiquidLensQuality.swift
//  AemiSDR
//

/// Top-level rendering-quality preset for the liquid lens. Provides a single
/// knob that bundles the right combination of opt-in fidelity flags so
/// consumers can pick a tier (fast / balanced / high / maximum) without
/// reasoning about each flag individually.
///
/// The individual flags on `LiquidLensConfiguration` (and its high-level
/// wrapper `LiquidGlassConfiguration`) remain public — the preset is a
/// convenience that resolves to them, not a replacement. After applying a
/// preset, callers may override any individual flag to deviate from the
/// chosen tier.
public enum LiquidLensQuality: Sendable, Equatable, Hashable, CaseIterable {
    /// Cheapest rendering path. Scalar rim deviation (no per-fragment
    /// `refract()`), no Fresnel, no spectral integration, no aspheric
    /// surface profile. Targets the fastest possible chromatic-path
    /// fragment cost.
    case fastest

    /// Default balanced configuration. Scalar refraction, no opt-in physical
    /// modes. Matches the out-of-the-box behavior and is appropriate for
    /// most interactive use.
    case balanced

    /// Per-fragment 3D `refract()` for `tan(α)` accuracy at large incidence
    /// angles. Fresnel transmission attenuation on. Spectral and aspheric
    /// stay off — they add texture-sample cost or vertex-tilt math for an
    /// improvement that's visible only in side-by-side comparison.
    case high

    /// Every opt-in feature on: per-fragment 3D `refract()`, Fresnel,
    /// 5-wavelength spectral integration, aspheric surface profile. Use for
    /// hero shots or non-interactive captures where frame time isn't
    /// constrained.
    case maximum
}

extension LiquidLensQuality {
    /// Human-readable label for UI use.
    public var label: String {
        switch self {
        case .fastest: "Fastest"
        case .balanced: "Balanced"
        case .high: "High"
        case .maximum: "Maximum"
        }
    }

    /// Whether per-fragment 3D `refract()` is enabled by this preset.
    public var usesHighFidelityRefraction: Bool {
        switch self {
        case .fastest, .balanced: false
        case .high, .maximum: true
        }
    }

    /// Whether Fresnel transmission attenuation is enabled by this preset.
    public var usesFresnel: Bool {
        switch self {
        case .fastest, .balanced: false
        case .high, .maximum: true
        }
    }

    /// Whether 5-wavelength spectral integration is enabled by this preset.
    public var usesSpectral: Bool {
        switch self {
        case .fastest, .balanced, .high: false
        case .maximum: true
        }
    }

    /// Whether the aspheric surface-tilt model is enabled by this preset.
    public var usesAspheric: Bool {
        switch self {
        case .fastest, .balanced, .high: false
        case .maximum: true
        }
    }
}

#if os(iOS)
    import CoreGraphics

    extension LiquidLensQuality {
        /// Capture-scale value the preset chooses for `LiquidGlassConfiguration`.
        /// Lower scales sample the backdrop at lower resolution, trading
        /// fidelity for frame-time reduction (4× less work at 0.5×).
        ///
        /// Returned as `CGFloat` so it slots directly into
        /// `LiquidGlassConfiguration.captureScale` without conversion.
        public var captureScale: CGFloat {
            switch self {
            case .fastest: 0.25
            case .balanced: 0.5
            case .high: 0.75
            case .maximum: 1.0
            }
        }
    }
#endif
