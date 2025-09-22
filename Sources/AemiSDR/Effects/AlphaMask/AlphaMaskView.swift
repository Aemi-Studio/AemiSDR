//
//  AlphaMaskView.swift
//  AemiSDR
//
//  Alpha mask implementation using the same shaders as VariableBlur
//  for destination-out compositing effects
//

#if os(iOS)
    import CoreImage
    import QuartzCore
    import SwiftUI
    import UIKit

    /**
     * A SwiftUI view that creates alpha masks for destination-out compositing effects.
     *
     * AlphaMaskView serves as a SwiftUI wrapper around AlphaMaskUIView, providing
     * declarative access to sophisticated alpha masking capabilities powered by
     * Metal shaders. This view creates masks that can selectively hide or reveal
     * content placed behind it.
     *
     * Key Features:
     * - SwiftUI-native declarative API with UIViewRepresentable backing
     * - Multiple mask types: linear gradients, rounded rectangles, and superellipse squircles
     * - Convenience initializers for common mask configurations
     * - Hardware-accelerated Metal shader rendering
     * - Automatic view updates when parameters change
     *
     * Usage Examples:
     * ```swift
     * // Linear gradient mask
     * AlphaMaskView(type: .linearTopToBottom, startOffset: 0.2)
     *
     * // Rounded rectangle mask
     * AlphaMaskView(cornerRadius: 20, fadeWidth: 40)
     *
     * // Superellipse squircle mask
     * AlphaMaskView(cornerRadius: 16, exponent: 2, transition: .eased)
     * ```
     */
    public struct AlphaMaskView: UIViewRepresentable {
        // MARK: - Configuration Properties

        /// The type of mask to generate
        public var maskType: MaskType = .linearTopToBottom

        /// For linear gradients: offset from edge as fraction of dimension.
        /// For shaped masks: controls the transition smoothness.
        public var startOffset: CGFloat = 0

        /// Corner radius in points (for rounded rectangle and squircle masks)
        public var cornerRadius: CGFloat = UIScreen.displayCornerRadius

        /// The width of the fade transition, in points
        public var fadeWidth: CGFloat = 16

        /// Whether to invert the mask (true = destination-out, false = normal mask)
        public var inverted: Bool = true

        // MARK: - Initializers

        /**
         * Creates a basic alpha mask view with linear gradient configuration.
         *
         * This initializer is ideal for creating simple linear gradient masks
         * that transition from transparent to opaque across a specified direction.
         *
         * - Parameters:
         *   - maskType: The type of linear mask to create (default: .linearTopToBottom)
         *   - startOffset: Position where the gradient begins as fraction (0.0-1.0)
         *   - inverted: Whether to invert the mask effect (default: true)
         */
        public init(
            type maskType: MaskType = .linearTopToBottom,
            startOffset: CGFloat = 0,
            inverted: Bool = true
        ) {
            self.maskType = maskType
            self.startOffset = startOffset
            self.inverted = inverted
        }

        /**
         * Creates an alpha mask view configured for superellipse (squircle) shapes.
         *
         * Superellipse shapes provide a more organic, iOS-like rounded appearance
         * compared to standard rounded rectangles. The exponent parameter controls
         * the "squareness" of the shape.
         *
         * - Parameters:
         *   - cornerRadius: Effective corner radius in points (default: UIScreen.displayCornerRadius)
         *   - fadeWidth: Width of the fade transition in points (default: 16)
         *   - inverted: Whether to invert the mask effect (default: true)
         *   - transition: Transformation function type - linear or eased (default: .eased)
         */
        public init(
            cornerRadius: CGFloat = UIScreen.displayCornerRadius,
            fadeWidth: CGFloat = 16,
            inverted: Bool = true,
            transition: TransitionAlgorithm = .eased
        ) {
            maskType = switch transition {
            case .linear: .superellipseSquircle
            case .eased: .easedSuperellipseSquircle
            }
            self.cornerRadius = cornerRadius
            self.fadeWidth = fadeWidth
            self.inverted = inverted
        }

        /**
         * Creates an alpha mask view with unified corner styling.
         *
         * This unified initializer automatically determines whether to use circular
         * (standard rounded rectangle) or continuous (superellipse/squircle) corner styling
         * based on the provided RoundedCornerStyle. This eliminates the need for separate
         * initializers and provides a cleaner API.
         *
         * - Parameters:
         *   - cornerStyle: The corner style to apply (default: .continuous)
         *   - cornerRadius: Corner radius in points (default: UIScreen.displayCornerRadius)
         *   - fadeWidth: Width of the fade transition in points (default: 16)
         *   - inverted: Whether to invert the mask effect (default: true)
         *   - transition: Transformation function type - linear or eased (default: .eased)
         */
        public init(
            _ cornerStyle: RoundedCornerStyle = .continuous,
            cornerRadius: CGFloat = UIScreen.displayCornerRadius,
            fadeWidth: CGFloat = 16,
            inverted: Bool = true,
            transition: TransitionAlgorithm = .eased
        ) {
            maskType = switch (cornerStyle, transition) {
            case (.circular, .linear): .roundedRectangle
            case (.circular, .eased): .easedRoundedRectangle
            case (.continuous, .linear): .superellipseSquircle
            case (.continuous, .eased): .easedSuperellipseSquircle
            case (_, _): .easedSuperellipseSquircle
            }
            self.cornerRadius = cornerRadius
            self.fadeWidth = fadeWidth
            self.inverted = inverted
        }

        // MARK: - UIViewRepresentable Implementation

        /**
         * Creates the underlying UIView instance.
         *
         * This method is called once when the SwiftUI view is first created.
         * It instantiates the AlphaMaskUIView with the current configuration.
         *
         * - Parameter context: The representable context provided by SwiftUI
         * - Returns: A configured AlphaMaskUIView instance
         */
        public func makeUIView(context _: Context) -> AlphaMaskUIView {
            AlphaMaskUIView(
                maskType: maskType,
                startOffset: startOffset,
                cornerRadius: cornerRadius,
                fadeWidth: fadeWidth,
                inverted: inverted
            )
        }

        /**
         * Updates the UIView when SwiftUI state changes.
         *
         * This method is called whenever any of the view's properties change,
         * ensuring the underlying UIView stays synchronized with the SwiftUI state.
         * The AlphaMaskUIView will only regenerate the mask if the configuration
         * has actually changed.
         *
         * - Parameters:
         *   - uiView: The existing AlphaMaskUIView instance to update
         *   - context: The representable context provided by SwiftUI
         */
        public func updateUIView(_ uiView: AlphaMaskUIView, context _: Context) {
            uiView.updateConfiguration(
                maskType: maskType,
                startOffset: startOffset,
                cornerRadius: cornerRadius,
                fadeWidth: fadeWidth,
                inverted: inverted
            )
        }
    }
#endif
