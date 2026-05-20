//
//  LiquidGlassConfiguration.swift
//  AemiSDR
//

#if os(iOS)
    import CoreGraphics
    import simd

    /// High-level configuration for a background-style liquid glass effect.
    ///
    /// This wraps the lower-level lens parameters with end-user-friendly defaults.
    public struct LiquidGlassConfiguration: Sendable, Equatable, Hashable {
        /// Distortion strength. Lower values look closer to native liquid glass.
        public var strength: Float

        /// Surface curvature of the glass.
        public var lensCurvature: Float

        /// Optional corner radius for the glass shape.
        ///
        /// If omitted and a SwiftUI shape is provided, the framework attempts
        /// to infer a radius via `Mirror`.
        public var cornerRadius: LiquidLensCornerRadius?

        /// Falloff transition curve.
        public var falloff: LiquidLensFalloff

        /// Width of the edge fade zone (0–1). At 0, the effect has sharp edges;
        /// at 1, the fade extends to the center.
        public var falloffLength: Float

        /// Falloff intensity multiplier.
        public var falloffIntensity: Float

        /// Chromatic aberration intensity.
        public var chromaticAmount: Float

        /// Optical material model.
        public var material: LiquidLensMaterial

        /// Whether the effect continuously recaptures backdrop content.
        public var continuousCapture: Bool

        /// Capture refresh rate in frames per second. Clamped to `1...120` on
        /// assignment; getter returns the clamped value, so two configurations
        /// that render at the same rate hash as equal.
        public var refreshRate: Int {
            didSet {
                let clamped = max(1, min(refreshRate, 120))
                if refreshRate != clamped { refreshRate = clamped }
            }
        }

        /// Capture scale factor (quality/performance tradeoff). Clamped to
        /// `0.25...3.0` on assignment.
        public var captureScale: CGFloat {
            didSet {
                let clamped = max(0.25, min(captureScale, 3.0))
                if captureScale != clamped { captureScale = clamped }
            }
        }

        /// When `true` (the default), the backdrop is recaptured on every
        /// display-link tick. When `false`, the capture is skipped if a cheap
        /// content-change signature (bounds, subview/sublayer count, contents
        /// pointer) is unchanged.
        ///
        /// The signature is not sensitive to scroll offset, animation
        /// progress, video frames, or text-only content updates — all of
        /// these change pixels without restructuring the view tree — so the
        /// safe default is `true`. Set to `false` only when the backdrop is
        /// known to be static between user inputs and rendering every frame
        /// is a measurable cost.
        public var forceCaptureEveryFrame: Bool

        /// Soft transition band in points across the inner-rect medial axis
        /// of the SDF gradient. Forwards to
        /// `LiquidLensConfiguration.diagonalBand`.
        public var diagonalBand: Float

        /// Second-order aspheric coefficient (active when `enableAspheric` is `true`).
        public var asphericK2: Float

        /// Fourth-order aspheric coefficient (active when `enableAspheric` is `true`).
        public var asphericK4: Float

        /// Enables Fresnel transmission attenuation at the lens surface.
        /// Off by default to preserve the artistic look.
        public var enableFresnel: Bool

        /// Enables 5-wavelength spectral integration in chromatic mode.
        public var enableSpectral: Bool

        /// Enables the aspheric surface-tilt model.
        public var enableAspheric: Bool

        /// Enables per-fragment MSL `refract()` 3D refraction (slow, accurate)
        /// instead of the default scalar-deviation form (fast). See
        /// `LiquidLensConfiguration.enableHighFidelityRefraction` for the
        /// physics trade-off.
        public var enableHighFidelityRefraction: Bool

        public init(
            strength: Float = 0.5,
            lensCurvature: Float = 1.0,
            cornerRadius: LiquidLensCornerRadius? = nil,
            falloff: LiquidLensFalloff = .exponential,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 1.0,
            chromaticAmount: Float = 15,
            material: LiquidLensMaterial = .acrylic,
            continuousCapture: Bool = true,
            refreshRate: Int = 40,
            captureScale: CGFloat = 0.5,
            forceCaptureEveryFrame: Bool = true,
            diagonalBand: Float = 6.0,
            asphericK2: Float = 0.0,
            asphericK4: Float = 0.0,
            enableFresnel: Bool = false,
            enableSpectral: Bool = false,
            enableAspheric: Bool = false,
            enableHighFidelityRefraction: Bool = false
        ) {
            self.strength = strength
            self.lensCurvature = lensCurvature
            self.cornerRadius = cornerRadius
            self.falloff = falloff
            self.falloffLength = falloffLength
            self.falloffIntensity = falloffIntensity
            self.chromaticAmount = chromaticAmount
            self.material = material
            self.continuousCapture = continuousCapture
            // didSet doesn't fire from init; clamp explicitly so the stored
            // value matches the post-assignment invariant.
            self.refreshRate = max(1, min(refreshRate, 120))
            self.captureScale = max(0.25, min(captureScale, 3.0))
            self.forceCaptureEveryFrame = forceCaptureEveryFrame
            self.diagonalBand = diagonalBand
            self.asphericK2 = asphericK2
            self.asphericK4 = asphericK4
            self.enableFresnel = enableFresnel
            self.enableSpectral = enableSpectral
            self.enableAspheric = enableAspheric
            self.enableHighFidelityRefraction = enableHighFidelityRefraction
        }
    }

    extension LiquidGlassConfiguration {
        /// Balanced preset for general UI backgrounds.
        public static let regular = LiquidGlassConfiguration()

        /// Softer preset with reduced distortion and chromatic separation.
        public static let subtle = LiquidGlassConfiguration(
            strength: 0.4,
            lensCurvature: 0.6,
            falloffIntensity: 0.5,
            chromaticAmount: 1.5,
            material: .water
        )

        /// Near-clear preset with minimal distortion.
        public static let clear = LiquidGlassConfiguration(
            strength: 0.15,
            lensCurvature: 0.4,
            falloffIntensity: 0.3,
            chromaticAmount: 0.0,
            material: .water
        )
    }

    extension LiquidGlassConfiguration {
        @usableFromInline
        internal func lensConfiguration(
            center: SIMD2<Float>,
            halfSize: SIMD2<Float>,
            cornerRadiusOverride: LiquidLensCornerRadius?,
            overlayMode: Bool = false
        ) -> LiquidLensConfiguration {
            var configuration = LiquidLensConfiguration(
                center: center,
                halfSize: halfSize,
                strength: strength,
                lensCurvature: lensCurvature,
                cornerRadius: cornerRadiusOverride ?? cornerRadius ?? .points(0),
                falloff: falloff,
                falloffLength: falloffLength,
                falloffIntensity: falloffIntensity,
                chromaticAmount: chromaticAmount,
                material: material,
                diagonalBand: diagonalBand,
                asphericK2: asphericK2,
                asphericK4: asphericK4,
                enableFresnel: enableFresnel,
                enableSpectral: enableSpectral,
                enableAspheric: enableAspheric,
                enableHighFidelityRefraction: enableHighFidelityRefraction
            )
            configuration.overlayMode = overlayMode
            return configuration
        }

        // Retained for source compatibility with the older split helpers; the
        // unified `lensConfiguration(..., overlayMode:)` is now the canonical
        // entry point.
        @available(*, deprecated, renamed: "lensConfiguration(center:halfSize:cornerRadiusOverride:overlayMode:)")
        @usableFromInline
        internal func overlayLensConfiguration(
            center: SIMD2<Float>,
            halfSize: SIMD2<Float>,
            cornerRadiusOverride: LiquidLensCornerRadius?
        ) -> LiquidLensConfiguration {
            var configuration = lensConfiguration(
                center: center,
                halfSize: halfSize,
                cornerRadiusOverride: cornerRadiusOverride
            )
            configuration.overlayMode = true
            return configuration
        }
    }
#endif
