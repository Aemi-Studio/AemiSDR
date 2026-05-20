//
//  LiquidGlassView.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI
    import simd

    /// A background-style liquid glass surface that auto-sizes to its container.
    ///
    /// This is the high-level API for live backdrop distortion, intended to be used
    /// as a background/overlay layer rather than as an explicitly positioned lens.
    @available(iOS 15.0, *)
    public struct LiquidGlassView: View {
        public var configuration: LiquidGlassConfiguration
        public var clipShapePath: ShapePathProvider?
        public var cornerRadius: LiquidLensCornerRadius?

        public init(
            configuration: LiquidGlassConfiguration = .regular,
            clipShapePath: ShapePathProvider? = nil,
            cornerRadius: LiquidLensCornerRadius? = nil
        ) {
            self.configuration = configuration
            self.clipShapePath = clipShapePath
            self.cornerRadius = cornerRadius
        }

        @available(iOS 16.0, *)
        public init<S: Shape>(
            configuration: LiquidGlassConfiguration = .regular,
            shape: S,
            cornerRadius: LiquidLensCornerRadius? = nil
        ) {
            self.configuration = configuration
            self.clipShapePath = { rect in shape.path(in: rect).cgPath }
            self.cornerRadius =
                cornerRadius
                ?? LiquidShapeCornerRadiusResolver.inferCornerRadius(from: shape)
        }

        public var body: some View {
            GeometryReader { proxy in
                let halfSize = SIMD2<Float>(
                    Float(proxy.size.width * 0.5),
                    Float(proxy.size.height * 0.5)
                )
                _LiquidLensOverlay(
                    configuration: configuration.lensConfiguration(
                        center: halfSize,
                        halfSize: halfSize,
                        cornerRadiusOverride: cornerRadius,
                        overlayMode: true
                    ),
                    clipShapePath: clipShapePath,
                    continuousCapture: configuration.continuousCapture,
                    refreshRate: configuration.refreshRate,
                    captureScale: configuration.captureScale,
                    forceCaptureEveryFrame: configuration.forceCaptureEveryFrame
                )
                .allowsHitTesting(false)
            }
        }
    }
#endif
