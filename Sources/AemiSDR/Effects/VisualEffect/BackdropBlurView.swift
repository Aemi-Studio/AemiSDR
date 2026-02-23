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
        // MARK: - Configuration Properties

        /// Optional tint color applied over the blur
        public let colorTint: Color?

        /// Alpha value for the tint color (0.0 to 1.0)
        public let colorTintAlpha: CGFloat

        /// The blur radius in points
        public let blurRadius: CGFloat

        /// Scale factor for the effect
        public let scale: CGFloat

        /// Full configuration, when using the configuration-based API
        private let configuration: BackdropBlurConfiguration?

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
            self.colorTint = colorTint
            self.colorTintAlpha = colorTintAlpha
            self.blurRadius = blurRadius
            self.scale = scale
            self.configuration = nil
        }

        /// Creates a backdrop blur view from a full configuration.
        ///
        /// - Parameter configuration: The configuration specifying all effect properties.
        public init(configuration: BackdropBlurConfiguration) {
            self.configuration = configuration
            self.colorTint = configuration.colorTint
            self.colorTintAlpha = configuration.colorTintAlpha
            self.blurRadius = configuration.blurRadius
            self.scale = configuration.scale
        }

        // MARK: - UIViewRepresentable Implementation

        /// Creates the underlying UIView instance.
        ///
        /// - Parameter context: The representable context provided by SwiftUI
        /// - Returns: A configured VisualEffectUIView instance
        public func makeUIView(context _: Context) -> VisualEffectUIView {
            let view: VisualEffectUIView
            if let configuration {
                view = VisualEffectUIView(configuration: configuration)
            } else {
                view = VisualEffectUIView(
                    colorTint: colorTint.map { UIColor($0) },
                    colorTintAlpha: colorTintAlpha,
                    blurRadius: blurRadius,
                    scale: scale
                )
            }
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            return view
        }

        /// Updates the UIView when SwiftUI state changes.
        ///
        /// - Parameters:
        ///   - uiView: The existing VisualEffectUIView instance to update
        ///   - context: The representable context provided by SwiftUI
        public func updateUIView(_ uiView: VisualEffectUIView, context _: Context) {
            if let configuration {
                uiView.updateConfiguration(configuration)
            } else {
                uiView.updateConfiguration(
                    colorTint: colorTint.map { UIColor($0) },
                    colorTintAlpha: colorTintAlpha,
                    blurRadius: blurRadius,
                    scale: scale
                )
            }
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
        // MARK: - Configuration Properties

        /// Optional tint color applied over the blur
        public let colorTint: Color?

        /// Alpha value for the tint color (0.0 to 1.0)
        public let colorTintAlpha: CGFloat

        /// The blur radius in points
        public let blurRadius: CGFloat

        /// Scale factor for the effect
        public let scale: CGFloat

        /// Full configuration, when using the configuration-based API
        private let configuration: BackdropBlurConfiguration?

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
            self.colorTint = colorTint
            self.colorTintAlpha = colorTintAlpha
            self.blurRadius = blurRadius
            self.scale = scale
            self.configuration = nil
        }

        /// Creates a backdrop blur view from a full configuration.
        ///
        /// - Parameter configuration: The configuration specifying all effect properties.
        public init(configuration: BackdropBlurConfiguration) {
            self.configuration = configuration
            self.colorTint = configuration.colorTint
            self.colorTintAlpha = configuration.colorTintAlpha
            self.blurRadius = configuration.blurRadius
            self.scale = configuration.scale
        }

        // MARK: - NSViewRepresentable Implementation

        /// Creates the underlying NSView instance.
        ///
        /// - Parameter context: The representable context provided by SwiftUI
        /// - Returns: A configured NSVisualEffectView instance
        public func makeNSView(context _: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.autoresizingMask = [.width, .height]
            view.blendingMode = .behindWindow
            view.state = .active
            view.material = .popover
            return view
        }

        /// Updates the NSView when SwiftUI state changes.
        ///
        /// - Parameters:
        ///   - nsView: The existing NSVisualEffectView instance to update
        ///   - context: The representable context provided by SwiftUI
        public func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
            configureView(nsView)
        }

        // MARK: - Private Helpers

        private func configureView(_ view: NSVisualEffectView) {
            let config = configuration ?? BackdropBlurConfiguration(
                blurRadius: blurRadius,
                scale: scale,
                colorTint: colorTint,
                colorTintAlpha: colorTintAlpha
            )

            // Defer filter application to avoid re-entrant constraint updates.
            // SwiftUI calls updateNSView during layout passes; modifying the
            // layer tree at that point crashes on macOS 26+.
            DispatchQueue.main.async { [config] in
                // If the backdrop layer isn't available yet (view not in
                // a window), skip — the material's default blur is fine
                // and we'll apply on the next updateNSView cycle.
                guard view.backdropLayer != nil else { return }

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
