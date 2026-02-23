//
//  View+BackdropBlur.swift
//  AemiSDR
//

import SwiftUI

// MARK: - Backdrop Blur Modifiers

extension View {
    /// Applies a backdrop blur configuration as a background to the view.
    ///
    /// - Parameters:
    ///   - configuration: The backdrop blur configuration to apply.
    ///   - ignoreSafeArea: Whether to ignore safe area for the blur effect (default: true)
    /// - Returns: A view with the blur effect applied as background
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @ViewBuilder public func backdropBlurBackground(
        _ configuration: BackdropBlurConfiguration,
        ignoreSafeArea: Bool = true
    ) -> some View {
        background {
            BackdropBlurView(configuration: configuration)
                .conditionalIgnoreSafeArea(ignoreSafeArea)
        }
    }

    /// Applies a backdrop blur configuration as an overlay to the view.
    ///
    /// - Parameters:
    ///   - configuration: The backdrop blur configuration to apply.
    ///   - ignoreSafeArea: Whether to ignore safe area for the blur effect (default: true)
    /// - Returns: A view with the blur effect applied as overlay
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @ViewBuilder public func backdropBlurOverlay(
        _ configuration: BackdropBlurConfiguration,
        ignoreSafeArea: Bool = true
    ) -> some View {
        overlay {
            BackdropBlurView(configuration: configuration)
                .conditionalIgnoreSafeArea(ignoreSafeArea)
        }
    }

    /// Applies a customizable blur effect as a background to the view.
    ///
    /// This modifier creates a blur effect behind the view content with
    /// fine-grained control over blur radius, color tint, and scale.
    ///
    /// - Parameters:
    ///   - blurRadius: The blur radius in points (default: 10)
    ///   - colorTint: Optional tint color applied over the blur (default: nil)
    ///   - colorTintAlpha: Alpha value for the tint color (default: 0)
    ///   - scale: Scale factor for the effect (default: 1)
    ///   - ignoreSafeArea: Whether to ignore safe area for the blur effect (default: true)
    /// - Returns: A view with the blur effect applied as background
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @ViewBuilder public func backdropBlurBackground(
        blurRadius: CGFloat = 10,
        colorTint: Color? = nil,
        colorTintAlpha: CGFloat = 0,
        scale: CGFloat = 1,
        ignoreSafeArea: Bool = true
    ) -> some View {
        background {
            BackdropBlurView(
                colorTint: colorTint,
                colorTintAlpha: colorTintAlpha,
                blurRadius: blurRadius,
                scale: scale
            )
            .conditionalIgnoreSafeArea(ignoreSafeArea)
        }
    }

    /// Applies a customizable blur effect as an overlay to the view.
    ///
    /// This modifier creates a blur effect on top of the view content with
    /// fine-grained control over blur radius, color tint, and scale.
    ///
    /// - Parameters:
    ///   - blurRadius: The blur radius in points (default: 10)
    ///   - colorTint: Optional tint color applied over the blur (default: nil)
    ///   - colorTintAlpha: Alpha value for the tint color (default: 0)
    ///   - scale: Scale factor for the effect (default: 1)
    ///   - ignoreSafeArea: Whether to ignore safe area for the blur effect (default: true)
    /// - Returns: A view with the blur effect applied as overlay
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @ViewBuilder public func backdropBlurOverlay(
        blurRadius: CGFloat = 10,
        colorTint: Color? = nil,
        colorTintAlpha: CGFloat = 0,
        scale: CGFloat = 1,
        ignoreSafeArea: Bool = true
    ) -> some View {
        overlay {
            BackdropBlurView(
                colorTint: colorTint,
                colorTintAlpha: colorTintAlpha,
                blurRadius: blurRadius,
                scale: scale
            )
            .conditionalIgnoreSafeArea(ignoreSafeArea)
        }
    }

    /// Applies a frosted glass effect as a background to the view.
    ///
    /// This is a convenience modifier that creates a typical frosted glass
    /// appearance with a white tint and moderate blur.
    ///
    /// - Parameters:
    ///   - blurRadius: The blur radius in points (default: 18)
    ///   - tintOpacity: Opacity of the white tint (default: 0.2)
    ///   - ignoreSafeArea: Whether to ignore safe area for the effect (default: true)
    /// - Returns: A view with a frosted glass background effect
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @ViewBuilder public func frostedBackdropBackground(
        blurRadius: CGFloat = 18,
        tintOpacity: CGFloat = 0.2,
        ignoreSafeArea: Bool = true
    ) -> some View {
        background {
            BackdropBlurView(
                colorTint: .white,
                colorTintAlpha: tintOpacity,
                blurRadius: blurRadius,
                scale: 1
            )
            .conditionalIgnoreSafeArea(ignoreSafeArea)
        }
    }

    /// Applies a tinted blur effect as a background to the view.
    ///
    /// This is a convenience modifier for creating colored blur backgrounds,
    /// useful for creating themed or branded blur effects.
    ///
    /// - Parameters:
    ///   - color: The tint color for the blur
    ///   - blurRadius: The blur radius in points (default: 15)
    ///   - tintOpacity: Opacity of the tint color (default: 0.3)
    ///   - ignoreSafeArea: Whether to ignore safe area for the effect (default: true)
    /// - Returns: A view with a tinted blur background effect
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @ViewBuilder public func tintedBackdropBackground(
        color: Color,
        blurRadius: CGFloat = 15,
        tintOpacity: CGFloat = 0.3,
        ignoreSafeArea: Bool = true
    ) -> some View {
        background {
            BackdropBlurView(
                colorTint: color,
                colorTintAlpha: tintOpacity,
                blurRadius: blurRadius,
                scale: 1
            )
            .conditionalIgnoreSafeArea(ignoreSafeArea)
        }
    }
}
