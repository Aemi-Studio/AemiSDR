//
//  BackdropBlurConfiguration.swift
//  AemiSDR
//

import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// A complete configuration for a custom visual blur effect.
///
/// On iOS this drives the private `_UICustomBlurEffect` properties; on macOS
/// it drives `CABackdropLayer` filter values.  Both paths give continuous
/// control over the blur rendering pipeline.
///
/// Use the static presets to get system-matching configurations:
/// ```swift
/// BackdropBlurView(configuration: .light)
/// BackdropBlurView(configuration: .ultraThinMaterial)
/// ```
///
/// Or create custom configurations:
/// ```swift
/// var config = BackdropBlurConfiguration()
/// config.blurRadius = 20
/// config.saturationDeltaFactor = 1.8
/// ```
public struct BackdropBlurConfiguration: Sendable, Equatable {
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
    ///
    /// Parameter order matches `BackdropBlurView.init(colorTint:colorTintAlpha:blurRadius:scale:)`
    /// and `VisualEffectUIView.init(colorTint:colorTintAlpha:blurRadius:scale:)` —
    /// tint+alpha first, then geometry. Keeps the tint pair adjacent so a
    /// caller switching between `Color?` overloads can't transpose with
    /// `blurRadius`.
    public init(
        colorTint: Color? = nil,
        colorTintAlpha: CGFloat = 0,
        blurRadius: CGFloat = 0,
        scale: CGFloat = 1,
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
    public static let clear = BackdropBlurConfiguration()
}

// MARK: - System Style Presets

#if os(iOS)
    extension BackdropBlurConfiguration {
        /// Creates a configuration matching the system's visual effect style.
        ///
        /// This reads property values at runtime from `_UIBackdropViewSettings`
        /// so it automatically matches the current OS version.
        ///
        /// - Parameter style: The blur effect style to match.
        /// - Returns: A configuration with values matching the system style.
        public static func systemStyle(_ style: UIBlurEffect.Style) -> BackdropBlurConfiguration {
            guard let settingsClass = NSClassFromString(_InternedKeys.backdropViewSettingsClass) as? NSObject.Type else {
                _PrivateAPIDiagnostics.logOnce(
                    key: "backdropViewSettingsClass",
                    "Private class `\(_InternedKeys.backdropViewSettingsClass)` not found; systemStyle presets degrade to .clear. The host iOS version may have renamed this class."
                )
                return .clear
            }
            let sel = Selector(_InternedKeys.settingsCreationSelector)
            guard settingsClass.responds(to: sel) else {
                _PrivateAPIDiagnostics.logOnce(
                    key: "settingsCreationSelector",
                    "Private selector `\(_InternedKeys.settingsCreationSelector)` not implemented by \(settingsClass); systemStyle presets degrade to .clear."
                )
                return .clear
            }
            guard
                let settings = unsafe settingsClass.perform(sel, with: style.rawValue)?
                    .takeUnretainedValue() as? NSObject
            else {
                return .clear
            }

            var config = BackdropBlurConfiguration()

            if let value = settings.value(forKey: _InternedKeys.radiusValueKey) as? CGFloat {
                config.blurRadius = value
            }
            if let value = settings.value(forKey: _InternedKeys.scaleFactorKey) as? CGFloat {
                config.scale = value
            }
            if let value = settings.value(forKey: _InternedKeys.saturationKey) as? CGFloat {
                config.saturationDeltaFactor = value
            }
            if let value = settings.value(forKey: _InternedKeys.grayLevelKey) as? CGFloat {
                config.grayscaleTintLevel = value
            }
            if let value = settings.value(forKey: _InternedKeys.grayAlphaKey) as? CGFloat {
                config.grayscaleTintAlpha = value
            }
            if let value = settings.value(forKey: _InternedKeys.burnLevelKey) as? CGFloat {
                config.colorBurnTintLevel = value
            }
            if let value = settings.value(forKey: _InternedKeys.burnAlphaKey) as? CGFloat {
                config.colorBurnTintAlpha = value
            }
            if let value = settings.value(forKey: _InternedKeys.darkAlphaKey) as? CGFloat {
                config.darkeningTintAlpha = value
            }
            if let value = settings.value(forKey: _InternedKeys.darkHueKey) as? CGFloat {
                config.darkeningTintHue = value
            }
            if let value = settings.value(forKey: _InternedKeys.darkSatKey) as? CGFloat {
                config.darkeningTintSaturation = value
            }
            if let value = settings.value(forKey: _InternedKeys.zoomKey) as? CGFloat {
                config.zoom = value
            }
            if settings.value(forKey: _InternedKeys.grayTintEnabledKey) as? Bool == true {
                config.lightenGrayscaleWithSourceOver = true
            }
            if settings.value(forKey: _InternedKeys.burnTintEnabledKey) as? Bool == true {
                config.darkenWithSourceOver = true
            }

            // Extract color tint if the style uses one
            if settings.value(forKey: _InternedKeys.tintEnabledKey) as? Bool == true,
               let color = settings.value(forKey: _InternedKeys.tintColorKey) as? UIColor
            {
                config.colorTint = Color(color)
                config.colorTintAlpha = settings.value(forKey: _InternedKeys.tintAlphaKey) as? CGFloat ?? 0
            }

            return config
        }

        // MARK: - Named Presets

        /// Configuration matching `UIBlurEffect.Style.light`.
        public static var light: BackdropBlurConfiguration { systemStyle(.light) }

        /// Configuration matching `UIBlurEffect.Style.dark`.
        public static var dark: BackdropBlurConfiguration { systemStyle(.dark) }

        /// Configuration matching `UIBlurEffect.Style.extraLight`.
        public static var extraLight: BackdropBlurConfiguration { systemStyle(.extraLight) }

        /// Configuration matching `UIBlurEffect.Style.systemUltraThinMaterial`.
        public static var ultraThinMaterial: BackdropBlurConfiguration { systemStyle(.systemUltraThinMaterial) }

        /// Configuration matching `UIBlurEffect.Style.systemThinMaterial`.
        public static var thinMaterial: BackdropBlurConfiguration { systemStyle(.systemThinMaterial) }

        /// Configuration matching `UIBlurEffect.Style.systemMaterial`.
        public static var material: BackdropBlurConfiguration { systemStyle(.systemMaterial) }

        /// Configuration matching `UIBlurEffect.Style.systemThickMaterial`.
        public static var thickMaterial: BackdropBlurConfiguration { systemStyle(.systemThickMaterial) }

        /// Configuration matching `UIBlurEffect.Style.systemChromeMaterial`.
        public static var chromeMaterial: BackdropBlurConfiguration { systemStyle(.systemChromeMaterial) }
    }

#elseif os(macOS)
    import AppKit

    @MainActor
    extension BackdropBlurConfiguration {
        /// Creates a configuration by introspecting the internal CABackdropLayer
        /// of an `NSVisualEffectView` configured with the given material.
        ///
        /// This reads filter values at runtime from the backdrop layer's CAFilter
        /// objects so it automatically matches the current OS version.
        ///
        /// - Parameter material: The macOS material to introspect.
        /// - Returns: A configuration with values extracted from the system material.
        public static func systemMaterial(_ material: NSVisualEffectView.Material) -> BackdropBlurConfiguration {
            _introspect(material: material)
        }

        // MARK: - Named Presets

        /// Configuration with light appearance (introspected from `.underWindowBackground`).
        public static var light: BackdropBlurConfiguration {
            _introspect(material: .underWindowBackground, appearance: NSAppearance(named: .aqua))
        }

        /// Configuration with dark appearance (introspected from `.underWindowBackground`).
        public static var dark: BackdropBlurConfiguration {
            _introspect(material: .underWindowBackground, appearance: NSAppearance(named: .darkAqua))
        }

        /// Configuration matching `NSVisualEffectView.Material.headerView`.
        public static var ultraThinMaterial: BackdropBlurConfiguration { systemMaterial(.headerView) }

        /// Configuration matching `NSVisualEffectView.Material.titlebar`.
        public static var thinMaterial: BackdropBlurConfiguration { systemMaterial(.titlebar) }

        /// Configuration matching `NSVisualEffectView.Material.popover`.
        public static var material: BackdropBlurConfiguration { systemMaterial(.popover) }

        /// Configuration matching `NSVisualEffectView.Material.sheet`.
        public static var thickMaterial: BackdropBlurConfiguration { systemMaterial(.sheet) }

        /// Configuration matching `NSVisualEffectView.Material.hudWindow`.
        public static var chromeMaterial: BackdropBlurConfiguration { systemMaterial(.hudWindow) }

        // MARK: - Private

        private static func _introspect(
            material: NSVisualEffectView.Material,
            appearance: NSAppearance? = nil
        ) -> BackdropBlurConfiguration {
            let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            view.material = material
            view.blendingMode = .behindWindow
            view.state = .active
            view.wantsLayer = true
            if let appearance { view.appearance = appearance }

            // Force layout so the backdrop layer hierarchy is created
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()

            var config = BackdropBlurConfiguration()

            // Read gaussianBlur inputRadius -> blurRadius
            if let blur = view.gaussianBlurFilter,
               let radius = blur.value(forKeyPath: _InternedKeys.radiusParam) as? CGFloat
            {
                config.blurRadius = radius
            }

            // Read colorSaturate inputAmount -> saturationDeltaFactor
            if let saturate = view.colorSaturateFilter,
               let amount = saturate.value(forKeyPath: _InternedKeys.amountParam) as? CGFloat
            {
                config.saturationDeltaFactor = amount
            }

            // Read colorBrightness inputAmount -> grayscaleTintLevel or darkeningTintAlpha
            if let brightness = view.colorBrightnessFilter,
               let amount = brightness.value(forKeyPath: _InternedKeys.amountParam) as? CGFloat
            {
                if amount >= 0 {
                    config.grayscaleTintLevel = amount + 1.0
                } else {
                    config.darkeningTintAlpha = -amount
                }
            }

            // Read backdrop scale
            if let backdrop = view.backdropLayer,
               let scale = backdrop.value(forKeyPath: _InternedKeys.scaleFactorKey) as? CGFloat
            {
                config.scale = scale
            }

            // Read tint from sublayer backgroundColor
            if let backdrop = view.backdropLayer {
                for sublayer in backdrop.sublayers ?? [] {
                    if let bg = sublayer.backgroundColor {
                        let nsColor = NSColor(cgColor: bg)
                        if let srgb = nsColor?.usingColorSpace(.sRGB) {
                            config.colorTint = Color(srgb)
                            config.colorTintAlpha = srgb.alphaComponent
                        }
                        break
                    }
                }
            }

            return config
        }
    }
#endif
