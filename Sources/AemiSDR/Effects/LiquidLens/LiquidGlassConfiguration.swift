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

        /// When `true`, the backdrop is recaptured on every display-link tick
        /// regardless of the cheap content-change signature. Set this to `true`
        /// when the backdrop contains animated content (e.g. a `Text` counter
        /// or `AVPlayerLayer`) whose pixels change without restructuring the
        /// view tree — otherwise the signature optimisation can freeze the
        /// lens on the first frame's content.
        ///
        /// Default `false`: skip drawHierarchy when the captured view's
        /// `bounds`/subview-count/sublayer-count/contents pointer are
        /// unchanged. This is the common-case speedup.
        public var forceCaptureEveryFrame: Bool

        public init(
            strength: Float = 1.0,
            lensCurvature: Float = 1.0,
            cornerRadius: LiquidLensCornerRadius? = nil,
            falloff: LiquidLensFalloff = .exponential,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 1.0,
            chromaticAmount: Float = 30,
            material: LiquidLensMaterial = .water,
            continuousCapture: Bool = true,
            refreshRate: Int = 120,
            captureScale: CGFloat = 0.85,
            forceCaptureEveryFrame: Bool = false
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
            chromaticAmount: 8,
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
                material: material
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
