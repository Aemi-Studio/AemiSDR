//
//  MPSBlurConfiguration.swift
//  AemiSDR
//

#if os(iOS)
    import CoreGraphics

    /// Configuration for the MPS Gaussian blur backdrop effect.
    ///
    /// Unlike the `BackdropBlurConfiguration` which drives `UIVisualEffectView`,
    /// this effect uses `MPSImageGaussianBlur` on a Metal pipeline for a pure
    /// GPU blur with no UIKit dependencies beyond capture.
    public struct MPSBlurConfiguration: Sendable, Equatable, Hashable {
        /// Gaussian sigma (blur radius). Default `20`.
        public var blurRadius: Float

        /// Whether the effect continuously recaptures backdrop content. Default `true`.
        public var continuousCapture: Bool

        /// Capture refresh rate in frames per second. Default `60`.
        public var refreshRate: Int

        /// Capture scale factor (lower = faster but blurrier). Default `0.5`.
        public var captureScale: CGFloat

        public init(
            blurRadius: Float = 20,
            continuousCapture: Bool = true,
            refreshRate: Int = 60,
            captureScale: CGFloat = 0.5
        ) {
            self.blurRadius = blurRadius
            self.continuousCapture = continuousCapture
            self.refreshRate = refreshRate
            self.captureScale = captureScale
        }
    }

    extension MPSBlurConfiguration {
        /// Balanced preset for general use.
        public static let standard = MPSBlurConfiguration()

        /// Frosted glass appearance with larger radius and lower capture scale.
        public static let frosted = MPSBlurConfiguration(
            blurRadius: 30,
            captureScale: 0.4
        )

        /// Heavy blur with large radius and very low capture scale.
        public static let heavy = MPSBlurConfiguration(
            blurRadius: 50,
            captureScale: 0.3
        )
    }

    extension MPSBlurConfiguration {
        @usableFromInline
        internal var clampedRefreshRate: Int {
            max(1, min(refreshRate, 120))
        }

        @usableFromInline
        internal var clampedCaptureScale: CGFloat {
            max(0.1, min(captureScale, 3.0))
        }
    }
#endif
