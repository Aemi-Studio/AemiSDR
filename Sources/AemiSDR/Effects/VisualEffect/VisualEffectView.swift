//
//  VisualEffectView.swift
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
    /// VisualEffectView(colorTint: .white, colorTintAlpha: 0.5, blurRadius: 18)
    ///     .frame(width: 200, height: 100)
    /// ```
    ///
    /// - Warning: This implementation uses private APIs and may break in future iOS versions.
    public struct VisualEffectView: UIViewRepresentable {
        // MARK: - Configuration Properties

        /// Optional tint color applied over the blur
        public let colorTint: Color?

        /// Alpha value for the tint color (0.0 to 1.0)
        public let colorTintAlpha: CGFloat

        /// The blur radius in points
        public let blurRadius: CGFloat

        /// Scale factor for the effect
        public let scale: CGFloat

        // MARK: - Initialization

        /// Creates a visual effect view with customizable blur properties.
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
        }

        // MARK: - UIViewRepresentable Implementation

        /// Creates the underlying UIView instance.
        ///
        /// - Parameter context: The representable context provided by SwiftUI
        /// - Returns: A configured VisualEffectUIView instance
        public func makeUIView(context _: Context) -> VisualEffectUIView {
            let view = VisualEffectUIView(
                colorTint: colorTint.map { UIColor($0) },
                colorTintAlpha: colorTintAlpha,
                blurRadius: blurRadius,
                scale: scale
            )
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            return view
        }

        /// Updates the UIView when SwiftUI state changes.
        ///
        /// - Parameters:
        ///   - uiView: The existing VisualEffectUIView instance to update
        ///   - context: The representable context provided by SwiftUI
        public func updateUIView(_ uiView: VisualEffectUIView, context _: Context) {
            uiView.updateConfiguration(
                colorTint: colorTint.map { UIColor($0) },
                colorTintAlpha: colorTintAlpha,
                blurRadius: blurRadius,
                scale: scale
            )
        }
    }

#elseif canImport(AppKit)
    import AppKit

    // MARK: - SwiftUI View (macOS)

    /// A SwiftUI view that provides customizable blur effects using AppKit's visual effect system.
    ///
    /// On macOS, this uses `NSVisualEffectView` with material-based blurring.
    /// Note that macOS does not support the same level of blur customization as iOS.
    public struct VisualEffectView: NSViewRepresentable {
        // MARK: - Configuration Properties

        /// Optional tint color applied over the blur
        public let colorTint: Color?

        /// Alpha value for the tint color (0.0 to 1.0)
        public let colorTintAlpha: CGFloat

        /// The blur radius (used to select material on macOS)
        public let blurRadius: CGFloat

        /// Scale factor (unused on macOS)
        public let scale: CGFloat

        // MARK: - Initialization

        /// Creates a visual effect view with customizable blur properties.
        ///
        /// - Parameters:
        ///   - colorTint: Optional tint color applied over the blur. Default is `nil`.
        ///   - colorTintAlpha: Alpha value for the tint color. Default is `0`.
        ///   - blurRadius: The blur radius (used to select material). Default is `0`.
        ///   - scale: Scale factor (unused on macOS). Default is `1`.
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
        }

        // MARK: - NSViewRepresentable Implementation

        /// Creates the underlying NSView instance.
        ///
        /// - Parameter context: The representable context provided by SwiftUI
        /// - Returns: A configured NSVisualEffectView instance
        public func makeNSView(context _: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.autoresizingMask = [.width, .height]
            configureView(view)
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
            view.blendingMode = .behindWindow
            view.state = .active

            // Map blur radius to material - higher blur = thicker material
            if blurRadius > 15 {
                view.material = .hudWindow
            } else if blurRadius > 8 {
                view.material = .popover
            } else {
                view.material = .headerView
            }
        }
    }
#endif
