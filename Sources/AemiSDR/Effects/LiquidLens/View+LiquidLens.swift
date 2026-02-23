//
//  View+LiquidLens.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI

    extension View {
        /// Applies a full-surface liquid glass effect as a background.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquid(
            _ configuration: LiquidGlassConfiguration = .regular,
            chromaticIntensity: Float? = nil,
            shape: ShapePathProvider? = nil,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = false
        ) -> some View {
            let resolvedConfiguration = resolvedLiquidConfiguration(
                configuration,
                chromaticIntensity: chromaticIntensity
            )
            liquidBackground(
                resolvedConfiguration,
                shape: shape,
                cornerRadius: cornerRadius,
                ignoreSafeArea: ignoreSafeArea
            )
        }

        /// Applies a full-surface liquid glass effect as a background using a SwiftUI shape.
        @available(iOS 16.0, *)
        @ViewBuilder
        public func liquid<S: Shape>(
            _ configuration: LiquidGlassConfiguration = .regular,
            chromaticIntensity: Float? = nil,
            shape: S,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = false
        ) -> some View {
            let resolvedConfiguration = resolvedLiquidConfiguration(
                configuration,
                chromaticIntensity: chromaticIntensity
            )
            let resolvedCornerRadius = cornerRadius
                ?? LiquidShapeCornerRadiusResolver.inferCornerRadius(from: shape)

            liquidBackground(
                resolvedConfiguration,
                shape: { rect in shape.path(in: rect).cgPath },
                cornerRadius: resolvedCornerRadius,
                ignoreSafeArea: ignoreSafeArea
            )
        }

        /// Applies a full-surface liquid glass effect as a background.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquidBackground(
            _ configuration: LiquidGlassConfiguration = .regular,
            chromaticIntensity: Float? = nil,
            shape: ShapePathProvider? = nil,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = false
        ) -> some View {
            let resolvedConfiguration = resolvedLiquidConfiguration(
                configuration,
                chromaticIntensity: chromaticIntensity
            )
            background {
                LiquidGlassView(
                    configuration: resolvedConfiguration,
                    clipShapePath: shape,
                    cornerRadius: cornerRadius
                )
                .conditionalIgnoreSafeArea(ignoreSafeArea)
            }
        }

        /// Applies a full-surface liquid glass effect as a background using a SwiftUI shape.
        @available(iOS 16.0, *)
        @ViewBuilder
        public func liquidBackground<S: Shape>(
            _ configuration: LiquidGlassConfiguration = .regular,
            chromaticIntensity: Float? = nil,
            shape: S,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = false
        ) -> some View {
            let resolvedConfiguration = resolvedLiquidConfiguration(
                configuration,
                chromaticIntensity: chromaticIntensity
            )
            let resolvedCornerRadius = cornerRadius
                ?? LiquidShapeCornerRadiusResolver.inferCornerRadius(from: shape)

            liquidBackground(
                resolvedConfiguration,
                shape: { rect in shape.path(in: rect).cgPath },
                cornerRadius: resolvedCornerRadius,
                ignoreSafeArea: ignoreSafeArea
            )
        }

        /// Applies a full-surface liquid glass effect as an overlay.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquidOverlay(
            _ configuration: LiquidGlassConfiguration = .regular,
            chromaticIntensity: Float? = nil,
            shape: ShapePathProvider? = nil,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = false
        ) -> some View {
            let resolvedConfiguration = resolvedLiquidConfiguration(
                configuration,
                chromaticIntensity: chromaticIntensity
            )
            overlay {
                LiquidGlassView(
                    configuration: resolvedConfiguration,
                    clipShapePath: shape,
                    cornerRadius: cornerRadius
                )
                .conditionalIgnoreSafeArea(ignoreSafeArea)
            }
        }

        /// Applies a full-surface liquid glass effect as an overlay using a SwiftUI shape.
        @available(iOS 16.0, *)
        @ViewBuilder
        public func liquidOverlay<S: Shape>(
            _ configuration: LiquidGlassConfiguration = .regular,
            chromaticIntensity: Float? = nil,
            shape: S,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = false
        ) -> some View {
            let resolvedConfiguration = resolvedLiquidConfiguration(
                configuration,
                chromaticIntensity: chromaticIntensity
            )
            let resolvedCornerRadius = cornerRadius
                ?? LiquidShapeCornerRadiusResolver.inferCornerRadius(from: shape)

            liquidOverlay(
                resolvedConfiguration,
                shape: { rect in shape.path(in: rect).cgPath },
                cornerRadius: resolvedCornerRadius,
                ignoreSafeArea: ignoreSafeArea
            )
        }

        private func resolvedLiquidConfiguration(
            _ configuration: LiquidGlassConfiguration,
            chromaticIntensity: Float?
        ) -> LiquidGlassConfiguration {
            guard let chromaticIntensity else { return configuration }
            var resolved = configuration
            resolved.chromaticAmount = chromaticIntensity
            return resolved
        }
    }
#endif
