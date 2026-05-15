//
//  View+LiquidLens.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI

    extension View {
        /// Applies a full-surface liquid glass effect as a background.
        ///
        /// To override the chromatic amplifier, construct a `LiquidGlassConfiguration`
        /// with a custom `chromaticAmount` and pass it in.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquidBackground(
            _ configuration: LiquidGlassConfiguration = .regular,
            shape: ShapePathProvider? = nil,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = true
        ) -> some View {
            background {
                LiquidGlassView(
                    configuration: configuration,
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
            shape: S,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = true
        ) -> some View {
            let resolvedCornerRadius = cornerRadius
                ?? LiquidShapeCornerRadiusResolver.inferCornerRadius(from: shape)

            liquidBackground(
                configuration,
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
            shape: ShapePathProvider? = nil,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = true
        ) -> some View {
            overlay {
                LiquidGlassView(
                    configuration: configuration,
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
            shape: S,
            cornerRadius: LiquidLensCornerRadius? = nil,
            ignoreSafeArea: Bool = true
        ) -> some View {
            let resolvedCornerRadius = cornerRadius
                ?? LiquidShapeCornerRadiusResolver.inferCornerRadius(from: shape)

            liquidOverlay(
                configuration,
                shape: { rect in shape.path(in: rect).cgPath },
                cornerRadius: resolvedCornerRadius,
                ignoreSafeArea: ignoreSafeArea
            )
        }
    }
#endif
