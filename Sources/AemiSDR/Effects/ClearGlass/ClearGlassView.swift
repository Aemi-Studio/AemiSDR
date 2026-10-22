#if os(iOS)
    import SwiftUI

    /// A background-style clear glass surface that auto-sizes to its container.
    public struct ClearGlassView: View {
        public var configuration: ClearGlassConfiguration
        public var continuousCapture: Bool
        public var refreshRate: Int
        public var captureScale: CGFloat
        public var forceCaptureEveryFrame: Bool

        public init(
            configuration: ClearGlassConfiguration = .nativeClear(shape: .capsule),
            continuousCapture: Bool = false,
            refreshRate: Int = 60,
            captureScale: CGFloat = 1.0,
            forceCaptureEveryFrame: Bool = false
        ) {
            self.configuration = configuration
            self.continuousCapture = continuousCapture
            self.refreshRate = refreshRate
            self.captureScale = captureScale
            self.forceCaptureEveryFrame = forceCaptureEveryFrame
        }

        public var body: some View {
            GeometryReader { proxy in
                _ClearGlassOverlay(
                    configuration: configuration,
                    continuousCapture: continuousCapture,
                    refreshRate: refreshRate,
                    captureScale: captureScale,
                    forceCaptureEveryFrame: forceCaptureEveryFrame
                )
                .allowsHitTesting(false)
            }
        }
    }

    extension View {
        /// Overlays a clear glass effect matching the given configuration.
        public func clearGlass(
            _ configuration: ClearGlassConfiguration = .nativeClear(shape: .capsule),
            continuous: Bool = false
        ) -> some View {
            overlay(ClearGlassView(configuration: configuration, continuousCapture: continuous))
        }
    }
#endif
