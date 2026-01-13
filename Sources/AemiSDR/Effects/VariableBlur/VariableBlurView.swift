//
//  VariableBlurView.swift
//  AemiSDR
//

#if os(iOS)
    import CoreImage
    import CoreImage.CIFilterBuiltins
    import SwiftUI
    import UIKit

    /// A SwiftUI view that creates variable blur effects using Metal shaders.
    ///
    /// VariableBlurView serves as a SwiftUI wrapper around VariableBlurUIView, providing
    /// declarative access to sophisticated variable blur capabilities powered by Metal
    /// shaders and private Core Animation filters. This view creates blur effects where
    /// the blur intensity varies across different regions based on generated mask patterns.
    ///
    /// Key Features:
    /// - SwiftUI-native declarative API with UIViewRepresentable backing
    /// - Multiple mask types: linear gradients, rounded rectangles, and superellipse squircles
    /// - Convenience initializers for common blur configurations
    /// - Hardware-accelerated Metal shader rendering with private CAFilter integration
    /// - Automatic view updates when parameters change
    /// - Configurable maximum blur radius and transition parameters
    ///
    /// The blur intensity at each pixel is determined by the alpha value of the generated mask:
    /// - Alpha 1.0 (white) = maximum blur radius
    /// - Alpha 0.0 (black) = no blur (clear)
    /// - Intermediate values = proportional blur intensity
    ///
    /// Usage Examples:
    /// ```swift
    /// // Linear gradient blur
    /// VariableBlurView(maxBlurRadius: 25, type: .linearTopToBottom, startOffset: 0.3)
    ///
    /// // Rounded rectangle blur
    /// VariableBlurView(maxBlurRadius: 20, cornerRadius: 16, fadeWidth: 40)
    ///
    /// // Superellipse squircle blur
    /// VariableBlurView(cornerRadius: 20, exponent: 2, transition: .eased)
    /// ```
    public struct VariableBlurView: UIViewRepresentable {
        // MARK: - Configuration Properties

        /// The maximum radius of the blur to be applied
        public var maxBlurRadius: CGFloat = 3

        /// The type of mask to generate
        public var maskType: MaskType = .linearTopToBottom

        /// For linear gradients: offset from edge as fraction of dimension.
        /// For shaped masks: controls the transition smoothness.
        public var startOffset: CGFloat = 0

        /// Corner radius in points (for rounded rectangle and squircle masks)
        public var cornerRadius: CGFloat = UIScreen.displayCornerRadius

        /// The width of the fade from clear (center) to fully blurred (edges), in points
        public var fadeWidth: CGFloat = 16

        // MARK: - Initializers

        /// Creates a basic variable blur view with linear gradient configuration.
        ///
        /// This initializer is ideal for creating simple linear gradient blur effects
        /// that transition from clear to maximum blur across a specified direction.
        ///
        /// - Parameters:
        ///   - maxBlurRadius: Maximum blur radius in points (default: 3)
        ///   - maskType: The type of linear mask to create (default: .linearTopToBottom)
        ///   - startOffset: Position where the blur begins as fraction (0.0-1.0)
        public init(
            maxBlurRadius: CGFloat = 3,
            type maskType: MaskType = .linearTopToBottom,
            startOffset: CGFloat = 0
        ) {
            self.maxBlurRadius = maxBlurRadius
            self.maskType = maskType
            self.startOffset = startOffset
        }

        /// Creates a variable blur view configured for superellipse (squircle) shapes.
        ///
        /// Superellipse shapes provide a more organic, iOS-like rounded appearance
        /// compared to standard rounded rectangles. The exponent parameter controls
        /// the "squareness" of the shape.
        ///
        /// - Parameters:
        ///   - maxBlurRadius: Maximum blur radius in points (default: 3)
        ///   - cornerRadius: Effective corner radius in points (default: UIScreen.displayCornerRadius)
        ///   - fadeWidth: Width of the fade transition in points (default: 16)
        ///   - startOffset: Transition control parameter (default: 0)
        ///   - transition: Transformation function type - linear or eased (default: .eased)
        public init(
            maxBlurRadius: CGFloat = 3,
            cornerRadius: CGFloat = UIScreen.displayCornerRadius,
            fadeWidth: CGFloat = 16,
            startOffset: CGFloat = 0,
            transition: TransitionAlgorithm = .eased
        ) {
            self.maxBlurRadius = maxBlurRadius
            maskType =
                switch transition {
                case .linear: .superellipseSquircle
                case .eased: .easedSuperellipseSquircle
                }
            self.startOffset = startOffset
            self.cornerRadius = cornerRadius
            self.fadeWidth = fadeWidth
        }

        /// Creates a variable blur view with unified corner styling.
        ///
        /// This unified initializer automatically determines whether to use circular
        /// (standard rounded rectangle) or continuous (superellipse/squircle) corner styling
        /// based on the provided RoundedCornerStyle. This eliminates the need for separate
        /// initializers and provides a cleaner API.
        ///
        /// - Parameters:
        ///   - cornerStyle: The corner style to apply (default: .continuous)
        ///   - maxBlurRadius: Maximum blur radius in points (default: 3)
        ///   - cornerRadius: Corner radius in points (default: UIScreen.displayCornerRadius)
        ///   - fadeWidth: Width of the fade transition in points (default: 16)
        ///   - startOffset: Transition control parameter (default: 0)
        ///   - transition: Transformation function type - linear or eased (default: .eased)
        public init(
            _ cornerStyle: RoundedCornerStyle = .continuous,
            maxBlurRadius: CGFloat = 3,
            cornerRadius: CGFloat = UIScreen.displayCornerRadius,
            fadeWidth: CGFloat = 16,
            startOffset: CGFloat = 0,
            transition: TransitionAlgorithm = .eased
        ) {
            self.maxBlurRadius = maxBlurRadius
            maskType =
                switch (cornerStyle, transition) {
                case (.circular, .linear): .roundedRectangle
                case (.circular, .eased): .easedRoundedRectangle
                case (.continuous, .linear): .superellipseSquircle
                case (.continuous, .eased): .easedSuperellipseSquircle
                case (_, _): .easedSuperellipseSquircle
                }
            self.startOffset = startOffset
            self.cornerRadius = cornerRadius
            self.fadeWidth = fadeWidth
        }

        // MARK: - UIViewRepresentable Implementation

        /// Creates the underlying UIView instance.
        ///
        /// This method is called once when the SwiftUI view is first created.
        /// It instantiates the VariableBlurUIView with the current configuration.
        ///
        /// - Parameter context: The representable context provided by SwiftUI
        /// - Returns: A configured VariableBlurUIView instance
        public func makeUIView(context _: Context) -> VariableBlurUIView {
            VariableBlurUIView(
                maxBlurRadius: maxBlurRadius,
                maskType: maskType,
                startOffset: startOffset,
                cornerRadius: cornerRadius,
                fadeWidth: fadeWidth
            )
        }

        /// Updates the UIView when SwiftUI state changes.
        ///
        /// This method is called whenever any of the view's properties change,
        /// ensuring the underlying UIView stays synchronized with the SwiftUI state.
        /// The VariableBlurUIView will only regenerate the blur mask if the configuration
        /// has actually changed.
        ///
        /// - Parameters:
        ///   - uiView: The existing VariableBlurUIView instance to update
        ///   - context: The representable context provided by SwiftUI
        public func updateUIView(_ uiView: VariableBlurUIView, context _: Context) {
            uiView.updateConfiguration(
                maxBlurRadius: maxBlurRadius,
                maskType: maskType,
                startOffset: startOffset,
                cornerRadius: cornerRadius,
                fadeWidth: fadeWidth
            )
        }
    }
#endif
