//
//  VisualEffectConfiguration.swift
//  AemiSDR
//

import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// A complete configuration for a custom visual blur effect.
///
/// This struct exposes all 15 private `_UICustomBlurEffect` properties,
/// enabling full control over the blur rendering pipeline.
///
/// Use the static presets to get system-matching configurations:
/// ```swift
/// VisualEffectView(configuration: .light)
/// VisualEffectView(configuration: .ultraThinMaterial)
/// ```
///
/// Or create custom configurations:
/// ```swift
/// var config = VisualEffectConfiguration()
/// config.blurRadius = 20
/// config.saturationDeltaFactor = 1.8
/// ```
public struct VisualEffectConfiguration: Sendable, Equatable {
    // MARK: - Core

    /// The blur radius in points. Default is `0`.
    public var blurRadius: CGFloat

    /// The scale factor for the effect. Default is `1`.
    public var scale: CGFloat

    // MARK: - Color Tint

    /// Optional tint color applied over the blur. Default is `nil`.
    public var colorTint: Color?

    /// Alpha value for the tint color. Default is `0`.
    public var colorTintAlpha: CGFloat

    // MARK: - Saturation

    /// Multiplier for the saturation of the backdrop content. Default is `0`.
    public var saturationDeltaFactor: CGFloat

    // MARK: - Grayscale Tint

    /// Intensity of the grayscale tint layer. Default is `0`.
    public var grayscaleTintLevel: CGFloat

    /// Alpha of the grayscale tint layer. Default is `0`.
    public var grayscaleTintAlpha: CGFloat

    // MARK: - Color Burn Tint

    /// Intensity of the color burn tint layer. Default is `0`.
    public var colorBurnTintLevel: CGFloat

    /// Alpha of the color burn tint layer. Default is `0`.
    public var colorBurnTintAlpha: CGFloat

    // MARK: - Darkening

    /// Alpha of the darkening tint. Default is `0`.
    public var darkeningTintAlpha: CGFloat

    /// Hue of the darkening tint. Default is `0`.
    public var darkeningTintHue: CGFloat

    /// Saturation of the darkening tint. Default is `0`.
    public var darkeningTintSaturation: CGFloat

    // MARK: - Other

    /// Zoom level applied to the backdrop. Default is `0`.
    public var zoom: CGFloat

    /// Whether to lighten using grayscale with source-over compositing. Default is `false`.
    public var lightenGrayscaleWithSourceOver: Bool

    /// Whether to darken using source-over compositing. Default is `false`.
    public var darkenWithSourceOver: Bool

    // MARK: - Initialization

    /// Creates a configuration with the specified properties.
    public init(
        blurRadius: CGFloat = 0,
        scale: CGFloat = 1,
        colorTint: Color? = nil,
        colorTintAlpha: CGFloat = 0,
        saturationDeltaFactor: CGFloat = 0,
        grayscaleTintLevel: CGFloat = 0,
        grayscaleTintAlpha: CGFloat = 0,
        colorBurnTintLevel: CGFloat = 0,
        colorBurnTintAlpha: CGFloat = 0,
        darkeningTintAlpha: CGFloat = 0,
        darkeningTintHue: CGFloat = 0,
        darkeningTintSaturation: CGFloat = 0,
        zoom: CGFloat = 0,
        lightenGrayscaleWithSourceOver: Bool = false,
        darkenWithSourceOver: Bool = false
    ) {
        self.blurRadius = blurRadius
        self.scale = scale
        self.colorTint = colorTint
        self.colorTintAlpha = colorTintAlpha
        self.saturationDeltaFactor = saturationDeltaFactor
        self.grayscaleTintLevel = grayscaleTintLevel
        self.grayscaleTintAlpha = grayscaleTintAlpha
        self.colorBurnTintLevel = colorBurnTintLevel
        self.colorBurnTintAlpha = colorBurnTintAlpha
        self.darkeningTintAlpha = darkeningTintAlpha
        self.darkeningTintHue = darkeningTintHue
        self.darkeningTintSaturation = darkeningTintSaturation
        self.zoom = zoom
        self.lightenGrayscaleWithSourceOver = lightenGrayscaleWithSourceOver
        self.darkenWithSourceOver = darkenWithSourceOver
    }

    // MARK: - Presets

    /// A clear configuration with no visual effect applied.
    public static let clear = VisualEffectConfiguration()
}

// MARK: - System Style Presets

#if os(iOS)
    extension VisualEffectConfiguration {
        /// Creates a configuration matching the system's visual effect style.
        ///
        /// This reads property values at runtime from `_UIBackdropViewSettings`
        /// so it automatically matches the current OS version.
        ///
        /// - Parameter style: The blur effect style to match.
        /// - Returns: A configuration with values matching the system style.
        public static func systemStyle(_ style: UIBlurEffect.Style) -> VisualEffectConfiguration {
            guard
                let settingsClass = NSClassFromString(_InternedKeys.backdropViewSettingsClass) as? NSObject.Type,
                let settings = settingsClass.perform(
                    Selector(_InternedKeys.settingsForStyle),
                    with: style.rawValue
                )?.takeUnretainedValue() as? NSObject
            else {
                return .clear
            }

            var config = VisualEffectConfiguration()

            if let value = settings.value(forKey: _InternedKeys.blurRadius) as? CGFloat {
                config.blurRadius = value
            }
            if let value = settings.value(forKey: _InternedKeys.scale) as? CGFloat {
                config.scale = value
            }
            if let value = settings.value(forKey: _InternedKeys.saturationDeltaFactor) as? CGFloat {
                config.saturationDeltaFactor = value
            }
            if let value = settings.value(forKey: _InternedKeys.grayscaleTintLevel) as? CGFloat {
                config.grayscaleTintLevel = value
            }
            if let value = settings.value(forKey: _InternedKeys.grayscaleTintAlpha) as? CGFloat {
                config.grayscaleTintAlpha = value
            }
            if let value = settings.value(forKey: _InternedKeys.colorBurnTintLevel) as? CGFloat {
                config.colorBurnTintLevel = value
            }
            if let value = settings.value(forKey: _InternedKeys.colorBurnTintAlpha) as? CGFloat {
                config.colorBurnTintAlpha = value
            }
            if let value = settings.value(forKey: _InternedKeys.darkeningTintAlpha) as? CGFloat {
                config.darkeningTintAlpha = value
            }
            if let value = settings.value(forKey: _InternedKeys.darkeningTintHue) as? CGFloat {
                config.darkeningTintHue = value
            }
            if let value = settings.value(forKey: _InternedKeys.darkeningTintSaturation) as? CGFloat {
                config.darkeningTintSaturation = value
            }
            if let value = settings.value(forKey: _InternedKeys.zoom) as? CGFloat {
                config.zoom = value
            }
            if settings.value(forKey: _InternedKeys.usesGrayscaleTintView) as? Bool == true {
                config.lightenGrayscaleWithSourceOver = true
            }
            if settings.value(forKey: _InternedKeys.usesColorBurnTintView) as? Bool == true {
                config.darkenWithSourceOver = true
            }

            // Extract color tint if the style uses one
            if settings.value(forKey: _InternedKeys.usesColorTintView) as? Bool == true,
               let color = settings.value(forKey: _InternedKeys.colorTint) as? UIColor
            {
                config.colorTint = Color(color)
                config.colorTintAlpha = settings.value(forKey: _InternedKeys.colorTintAlpha) as? CGFloat ?? 0
            }

            return config
        }

        // MARK: - Named Presets

        /// Configuration matching `UIBlurEffect.Style.light`.
        public static var light: VisualEffectConfiguration { systemStyle(.light) }

        /// Configuration matching `UIBlurEffect.Style.dark`.
        public static var dark: VisualEffectConfiguration { systemStyle(.dark) }

        /// Configuration matching `UIBlurEffect.Style.extraLight`.
        public static var extraLight: VisualEffectConfiguration { systemStyle(.extraLight) }

        /// Configuration matching `UIBlurEffect.Style.systemUltraThinMaterial`.
        public static var ultraThinMaterial: VisualEffectConfiguration { systemStyle(.systemUltraThinMaterial) }

        /// Configuration matching `UIBlurEffect.Style.systemThinMaterial`.
        public static var thinMaterial: VisualEffectConfiguration { systemStyle(.systemThinMaterial) }

        /// Configuration matching `UIBlurEffect.Style.systemMaterial`.
        public static var material: VisualEffectConfiguration { systemStyle(.systemMaterial) }

        /// Configuration matching `UIBlurEffect.Style.systemThickMaterial`.
        public static var thickMaterial: VisualEffectConfiguration { systemStyle(.systemThickMaterial) }

        /// Configuration matching `UIBlurEffect.Style.systemChromeMaterial`.
        public static var chromeMaterial: VisualEffectConfiguration { systemStyle(.systemChromeMaterial) }
    }
#endif
