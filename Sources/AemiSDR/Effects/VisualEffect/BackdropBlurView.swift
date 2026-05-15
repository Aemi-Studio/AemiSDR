//
//  BackdropBlurView.swift
//  AemiSDR
//

import SwiftUI

#if canImport(UIKit)
    import UIKit

    // MARK: - SwiftUI View (iOS)

    /// A SwiftUI view that provides customizable blur effects.
    ///
    /// This view wraps `VisualEffectUIView` to provide fine-grained control over
    /// blur radius, color tint, and scale factor.
    ///
    /// Key Features:
    /// - Customizable blur radius without predefined blur styles
    /// - Optional color tint overlay with adjustable alpha
    /// - Scale factor control for effect intensity
    /// - SwiftUI-native declarative API
    ///
    /// Usage:
    /// ```swift
    /// BackdropBlurView(colorTint: .white, colorTintAlpha: 0.5, blurRadius: 18)
    ///     .frame(width: 200, height: 100)
    /// ```
    ///
    /// Or use a full configuration with system presets:
    /// ```swift
    /// BackdropBlurView(configuration: .light)
    /// BackdropBlurView(configuration: .ultraThinMaterial)
    /// ```
    ///
    /// - Warning: This implementation uses private APIs and may break in future iOS versions.
    public struct BackdropBlurView: UIViewRepresentable {

        /// Single source of truth for the effect state. The scalar-parameter
        /// init below funnels into this via a synthesised configuration.
        private let configuration: BackdropBlurConfiguration

        // MARK: - Initialization

        /// Creates a backdrop blur view with customizable blur properties.
        ///
        /// - Parameters:
        ///   - colorTint: Optional tint color applied over the blur. Default is `nil`.
        ///   - colorTintAlpha: Alpha value for the tint color. Default is `0`.
        ///   - blurRadius: The blur radius. Default is `0`.
        ///   - scale: Scale factor for the effect. Default is `1`.
        public init(
            colorTint: Color? = nil,
            colorTintAlpha: CGFloat = 0,
            blurRadius: CGFloat = 0,
            scale: CGFloat = 1
        ) {
            self.configuration = BackdropBlurConfiguration(
                colorTint: colorTint,
                colorTintAlpha: colorTintAlpha,
                blurRadius: blurRadius,
                scale: scale
            )
        }

        /// Creates a backdrop blur view from a full configuration.
        ///
        /// - Parameter configuration: The configuration specifying all effect properties.
        public init(configuration: BackdropBlurConfiguration) {
            self.configuration = configuration
        }

        // MARK: - UIViewRepresentable Implementation

        /// Creates the underlying UIView instance.
        public func makeUIView(context _: Context) -> VisualEffectUIView {
            let view = VisualEffectUIView(configuration: configuration)
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            return view
        }

        /// Updates the UIView when SwiftUI state changes.
        public func updateUIView(_ uiView: VisualEffectUIView, context _: Context) {
            uiView.updateConfiguration(configuration)
        }
    }

#elseif canImport(AppKit)
    import AppKit

    // MARK: - SwiftUI View (macOS)

    /// A SwiftUI view that provides customizable blur effects using AppKit's visual effect system.
    ///
    /// On macOS, this introspects `NSVisualEffectView`'s internal `CABackdropLayer` to provide
    /// the same continuous parameter control as iOS — blur radius, saturation, brightness, and tint
    /// can all be set to arbitrary values rather than being limited to discrete materials.
    public struct BackdropBlurView: NSViewRepresentable {

        private let configuration: BackdropBlurConfiguration

        // MARK: - Initialization

        /// Creates a backdrop blur view with customizable blur properties.
        ///
        /// - Parameters:
        ///   - colorTint: Optional tint color applied over the blur. Default is `nil`.
        ///   - colorTintAlpha: Alpha value for the tint color. Default is `0`.
        ///   - blurRadius: The blur radius in points. Default is `0`.
        ///   - scale: Scale factor for the effect. Default is `1`.
        public init(
            colorTint: Color? = nil,
            colorTintAlpha: CGFloat = 0,
            blurRadius: CGFloat = 0,
            scale: CGFloat = 1
        ) {
            self.configuration = BackdropBlurConfiguration(
                colorTint: colorTint,
                colorTintAlpha: colorTintAlpha,
                blurRadius: blurRadius,
                scale: scale
            )
        }

        /// Creates a backdrop blur view from a full configuration.
        public init(configuration: BackdropBlurConfiguration) {
            self.configuration = configuration
        }

        // MARK: - NSViewRepresentable Implementation

        public func makeNSView(context _: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.autoresizingMask = [.width, .height]
            view.blendingMode = .behindWindow
            view.state = .active
            view.material = .popover
            return view
        }

        public func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
            configureView(nsView)
        }

        // MARK: - Private Helpers

        private func configureView(_ view: NSVisualEffectView) {
            let config = configuration

            // Defer filter application to avoid re-entrant constraint updates.
            // SwiftUI calls updateNSView during layout passes; modifying the
            // layer tree at that point crashes on macOS 26+.
            DispatchQueue.main.async { [config] in
                // If the backdrop layer isn't available yet (view not in a
                // window), schedule another attempt on a subsequent runloop
                // tick. Without this retry, a view whose first configure cycle
                // fired before window attach would never apply the config until
                // SwiftUI happens to update the representable again.
                guard view.backdropLayer != nil else {
                    DispatchQueue.main.async { [config] in
                        guard view.backdropLayer != nil else { return }
                        CATransaction.begin()
                        CATransaction.setDisableActions(true)
                        Self.applyFilterValues(config, to: view)
                        Self.applyTintLayer(config, to: view)
                        CATransaction.commit()
                    }
                    return
                }

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                Self.applyFilterValues(config, to: view)
                Self.applyTintLayer(config, to: view)
                CATransaction.commit()
            }
        }

        private static func applyFilterValues(
            _ config: BackdropBlurConfiguration,
            to view: NSVisualEffectView
        ) {
            guard let backdrop = view.backdropLayer else { return }

            if let blur = view.gaussianBlurFilter {
                blur.setValue(config.blurRadius, forKey: _InternedKeys.radiusParam)
            }

            if let saturate = view.colorSaturateFilter {
                let amount = config.saturationDeltaFactor > 0 ? config.saturationDeltaFactor : 1.0
                saturate.setValue(amount, forKey: _InternedKeys.amountParam)
            }

            backdrop.setValue(config.scale, forKey: _InternedKeys.scaleFactorKey)
        }

        private static func applyTintLayer(
            _ config: BackdropBlurConfiguration,
            to view: NSVisualEffectView
        ) {
            let existingTint = view.layer?.sublayers?.first { $0.name == "AemiSDR.tint" }

            guard let tintColor = config.colorTint, config.colorTintAlpha > 0 else {
                existingTint?.removeFromSuperlayer()
                return
            }

            let tintLayer = existingTint ?? CALayer()
            tintLayer.name = "AemiSDR.tint"

            let nsColor = NSColor(tintColor).withAlphaComponent(config.colorTintAlpha)
            tintLayer.backgroundColor = nsColor.cgColor
            tintLayer.frame = view.bounds
            tintLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

            if existingTint == nil {
                view.layer?.addSublayer(tintLayer)
            }
        }
    }
#endif
