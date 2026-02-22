//
//  View+LiquidLens.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI

    extension View {

        // MARK: - Configuration-based (primary implementations)

        /// Applies a liquid lens distortion overlay with auto-capture using a configuration object.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquidLens(
            configuration: LiquidLensConfiguration,
            clipShape: ShapePathProvider? = nil,
            continuousCapture: Bool = true,
            refreshRate: Int = 30,
            captureScale: CGFloat = 1.0
        ) -> some View {
            overlay {
                _LiquidLensOverlay(
                    configuration: LiquidLensConfiguration(
                        center: configuration.center,
                        halfSize: configuration.halfSize,
                        strength: configuration.strength,
                        lensCurvature: configuration.lensCurvature,
                        cornerRadius: configuration.cornerRadius,
                        falloff: configuration.falloff,
                        falloffLength: configuration.falloffLength,
                        falloffIntensity: configuration.falloffIntensity,
                        chromaticAmount: configuration.chromaticAmount,
                        material: configuration.material,
                        useRadialDirection: configuration.useRadialDirection,
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

        /// Applies a liquid lens distortion overlay using an explicit source image and a configuration object.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquidLens(
            image: UIImage,
            configuration: LiquidLensConfiguration,
            clipShape: ShapePathProvider? = nil
        ) -> some View {
            overlay {
                LiquidLensView(
                    image: image,
                    configuration: configuration,
                    clipShapePath: clipShape
                )
                .allowsHitTesting(false)
            }
        }

        // MARK: - Auto-capture (parameter-list wrappers)

        /// Applies a physics-based liquid lens distortion effect that automatically
        /// captures the view's content as the source texture.
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
            liquidLens(
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
                clipShape: clipShape,
                continuousCapture: continuousCapture,
                refreshRate: refreshRate,
                captureScale: captureScale
            )
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

        // MARK: - Explicit image (parameter-list wrappers)

        /// Applies a physics-based liquid lens distortion effect using an explicit source image.
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
            liquidLens(
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
                clipShape: clipShape
            )
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
