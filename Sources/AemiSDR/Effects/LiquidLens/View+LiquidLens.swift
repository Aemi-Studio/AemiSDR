//
//  View+LiquidLens.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI

    extension View {

        // MARK: - Auto-capture (continuous)

        /// Applies a physics-based liquid lens distortion effect that automatically
        /// captures the view's content as the source texture.
        ///
        /// Uses a UIKit view-hierarchy snapshot to capture the content and renders
        /// the distorted version as a transparent overlay. When `continuousCapture`
        /// is `true` (the default), a `CADisplayLink` re-captures at `refreshRate` fps,
        /// keeping the lens in sync with background changes.
        ///
        /// - Parameters:
        ///   - clipShape: Optional shape path provider to mask the overlay to match the
        ///     parent view's clip shape. Use ``LiquidLensClipShape`` helpers or pass a closure.
        ///   - continuousCapture: When `true`, continuously re-snapshots the background.
        ///   - refreshRate: Target frames per second for continuous capture (1–120, default 30).
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquidLens(
            center: SIMD2<Float> = .zero,
            halfSize: SIMD2<Float> = SIMD2(150, 150),
            strength: Float = 1.0,
            lensCurvature: Float = 0.5,
            cornerRadius: LiquidLensCornerRadius = .points(0),
            falloff: LiquidLensFalloff = .easeInOut,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 0.5,
            chromaticAmount: Float = 1.0,
            material: LiquidLensMaterial = .crownGlass,
            useRadialDirection: Bool = true,
            clipShape: ShapePathProvider? = nil,
            continuousCapture: Bool = true,
            refreshRate: Int = 30,
            captureScale: CGFloat = 1.0
        ) -> some View {
            overlay {
                _LiquidLensOverlay(
                    configuration: LiquidLensConfiguration(
                        center: center,
                        halfSize: halfSize,
                        strength: strength,
                        lensCurvature: lensCurvature,
                        cornerRadius: cornerRadius,
                        falloff: falloff,
                        falloffLength: falloffLength,
                        falloffIntensity: falloffIntensity,
                        chromaticAmount: chromaticAmount,
                        material: material,
                        useRadialDirection: useRadialDirection,
                        overlayMode: true
                    ),
                    clipShapePath: clipShape,
                    continuousCapture: continuousCapture,
                    refreshRate: max(1, min(refreshRate, 120)),
                    captureScale: max(0.25, min(captureScale, 3.0))
                )
                .allowsHitTesting(false)
            }
        }

        /// Auto-capture overload that accepts a SwiftUI `Shape` for clip masking.
        @available(iOS 16.0, *)
        @ViewBuilder
        public func liquidLens<S: Shape>(
            center: SIMD2<Float> = .zero,
            halfSize: SIMD2<Float> = SIMD2(150, 150),
            strength: Float = 1.0,
            lensCurvature: Float = 0.5,
            cornerRadius: LiquidLensCornerRadius = .points(0),
            falloff: LiquidLensFalloff = .easeInOut,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 0.5,
            chromaticAmount: Float = 1.0,
            material: LiquidLensMaterial = .crownGlass,
            useRadialDirection: Bool = true,
            clipShape shape: S,
            continuousCapture: Bool = true,
            refreshRate: Int = 30,
            captureScale: CGFloat = 1.0
        ) -> some View {
            liquidLens(
                center: center,
                halfSize: halfSize,
                strength: strength,
                lensCurvature: lensCurvature,
                cornerRadius: cornerRadius,
                falloff: falloff,
                falloffLength: falloffLength,
                falloffIntensity: falloffIntensity,
                chromaticAmount: chromaticAmount,
                material: material,
                useRadialDirection: useRadialDirection,
                clipShape: { rect in shape.path(in: rect).cgPath },
                continuousCapture: continuousCapture,
                refreshRate: refreshRate,
                captureScale: captureScale
            )
        }

        // MARK: - Explicit image

        /// Applies a physics-based liquid lens distortion effect using an explicit source image.
        ///
        /// Use this overload when you have a pre-rendered image to distort, or when
        /// you want manual control over the source texture.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquidLens(
            image: UIImage,
            center: SIMD2<Float> = .zero,
            halfSize: SIMD2<Float> = SIMD2(150, 150),
            strength: Float = 1.0,
            lensCurvature: Float = 0.5,
            cornerRadius: LiquidLensCornerRadius = .points(0),
            falloff: LiquidLensFalloff = .easeInOut,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 0.5,
            chromaticAmount: Float = 1.0,
            material: LiquidLensMaterial = .crownGlass,
            useRadialDirection: Bool = true,
            clipShape: ShapePathProvider? = nil
        ) -> some View {
            overlay {
                LiquidLensView(
                    image: image,
                    configuration: LiquidLensConfiguration(
                        center: center,
                        halfSize: halfSize,
                        strength: strength,
                        lensCurvature: lensCurvature,
                        cornerRadius: cornerRadius,
                        falloff: falloff,
                        falloffLength: falloffLength,
                        falloffIntensity: falloffIntensity,
                        chromaticAmount: chromaticAmount,
                        material: material,
                        useRadialDirection: useRadialDirection
                    ),
                    clipShapePath: clipShape
                )
                .allowsHitTesting(false)
            }
        }

        /// Explicit image overload that accepts a SwiftUI `Shape` for clip masking.
        @available(iOS 16.0, *)
        @ViewBuilder
        public func liquidLens<S: Shape>(
            image: UIImage,
            center: SIMD2<Float> = .zero,
            halfSize: SIMD2<Float> = SIMD2(150, 150),
            strength: Float = 1.0,
            lensCurvature: Float = 0.5,
            cornerRadius: LiquidLensCornerRadius = .points(0),
            falloff: LiquidLensFalloff = .easeInOut,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 0.5,
            chromaticAmount: Float = 1.0,
            material: LiquidLensMaterial = .crownGlass,
            useRadialDirection: Bool = true,
            clipShape shape: S
        ) -> some View {
            liquidLens(
                image: image,
                center: center,
                halfSize: halfSize,
                strength: strength,
                lensCurvature: lensCurvature,
                cornerRadius: cornerRadius,
                falloff: falloff,
                falloffLength: falloffLength,
                falloffIntensity: falloffIntensity,
                chromaticAmount: chromaticAmount,
                material: material,
                useRadialDirection: useRadialDirection,
                clipShape: { rect in shape.path(in: rect).cgPath }
            )
        }
    }
#endif
