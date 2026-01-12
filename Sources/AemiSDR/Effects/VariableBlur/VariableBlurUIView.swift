//
//  VariableBlurUIView.swift
//  AemiSDR
//
// Created by Guillaume Coquard on 20.09.25.
//

#if os(iOS)
    import OSLog
    import UIKit

    /**
     * A subclass of UIVisualEffectView that applies variable blur effects using Metal shaders.
     *
     * VariableBlurUIView creates sophisticated blur effects where the blur intensity varies
     * across the view based on a mask image. It leverages Core Animation filters
     * to achieve hardware-accelerated variable blur effects.
     *
     * Key Features:
     * - Variable blur intensity controlled by mask images generated from Metal shaders
     * - Multiple mask types: linear gradients, rounded rectangles, and superellipse squircles
     * - Hardware-accelerated rendering using Core Animation filters
     * - Automatic mask regeneration and caching based on view size changes
     * - Support for both linear and eased (smooth) transition functions
     * - Configurable maximum blur radius and fade parameters
     *
     * The blur effect reads the mask image's alpha values to determine blur intensity:
     * - Alpha 1.0 (white) = maximum blur radius
     * - Alpha 0.0 (black) = no blur (clear)
     * - Intermediate values = proportional blur intensity
     */
    open class VariableBlurUIView: UIVisualEffectView {
        // MARK: - Logging

        /**
         * Logger instance for VariableBlur-related operations.
         *
         * Uses OSLog with a subsystem identifier for the AemiSDR framework
         * and sets the category to VariableBlurUIView for clear identification
         * of variable blur related logs.
         */
        private let logger = Logger(subsystem: "studio.aemi.AemiSDR", category: String(describing: VariableBlurUIView.self))

        // MARK: - Configuration Properties

        /// Maximum blur radius in points - the strongest blur applied where mask alpha is 1.0
        private var configuredMaxBlurRadius: CGFloat

        /// The type of mask shape to generate (linear, rounded rectangle, superellipse, etc.)
        private var configuredMaskType: MaskType

        /// Start offset for linear gradients (as fraction) or transition smoothness for shaped masks
        private var configuredStartOffset: CGFloat

        /// Corner radius in points for rounded rectangle and superellipse masks
        private var configuredCornerRadius: CGFloat

        /// Width of the fade transition zone in points
        private var configuredFadeWidth: CGFloat

        /// Reference to the filter instance for variable blur
        private var variableBlurFilter: NSObject?

        /// Current display scale, used for pixel-accurate mask generation
        private var currentScale: CGFloat {
            window?.screen.scale ?? UIScreen.main.scale
        }

        // MARK: - Initialization

        /**
         * Creates a new variable blur view with the specified configuration.
         *
         * - Parameters:
         *   - maxBlurRadius: Maximum blur radius in points (default: 20)
         *   - maskType: The type of mask to generate (default: linear top-to-bottom)
         *   - startOffset: Start position for gradients or transition control (default: 0)
         *   - cornerRadius: Corner radius for rounded shapes (default: UIScreen.displayCornerRadius)
         *   - fadeWidth: Width of fade transition in points (default: 16)
         */
        public init(
            maxBlurRadius: CGFloat = 20,
            maskType: MaskType = .linearTopToBottom,
            startOffset: CGFloat = 0,
            cornerRadius: CGFloat = UIScreen.displayCornerRadius,
            fadeWidth: CGFloat = 16
        ) {
            configuredMaxBlurRadius = maxBlurRadius
            configuredMaskType = maskType
            configuredStartOffset = startOffset
            configuredCornerRadius = cornerRadius
            configuredFadeWidth = fadeWidth

            super.init(effect: UIBlurEffect(style: .regular))

            // Disable interaction since this is a visual effect view
            isUserInteractionEnabled = false

            // Generate initial mask
            updateMask(for: bounds.size)
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Configuration Updates

        /**
         * Updates the blur configuration and regenerates the mask if necessary.
         *
         * This method compares the new configuration against the current one and only
         * triggers a mask regeneration if actual changes are detected. This optimization
         * prevents unnecessary GPU work during animations or frequent updates.
         *
         * - Parameters:
         *   - maxBlurRadius: Maximum blur radius in points
         *   - maskType: The type of mask to generate
         *   - startOffset: Start position for gradients or transition control
         *   - cornerRadius: Corner radius for rounded shapes
         *   - fadeWidth: Fade transition width
         */
        public func updateConfiguration(
            maxBlurRadius: CGFloat,
            maskType: MaskType,
            startOffset: CGFloat,
            cornerRadius: CGFloat,
            fadeWidth: CGFloat
        ) {
            let needsUpdate = configuredMaxBlurRadius != maxBlurRadius ||
                configuredMaskType != maskType ||
                configuredStartOffset != startOffset ||
                configuredCornerRadius != cornerRadius ||
                configuredFadeWidth != fadeWidth

            if needsUpdate {
                configuredMaxBlurRadius = maxBlurRadius
                configuredMaskType = maskType
                configuredStartOffset = startOffset
                configuredCornerRadius = cornerRadius
                configuredFadeWidth = fadeWidth

                // Force mask regeneration with new parameters
                updateMask(for: bounds.size)
            }
        }

        // MARK: - Private Filter Setup

        /**
         * Sets up the filter for variable blur functionality.
         *
         * This method uses runtime reflection to access Core Animation APIs
         * that enable variable blur effects. The filter is applied to the backdrop
         * layer and configured with the current blur radius and edge normalization.
         */
        private func setupVariableBlurFilter() {
            // Access the filter class using runtime reflection
            guard let filterClass = NSClassFromString(InternedKeys.caFilterClass) as? NSObject.Type else {
                logger.error("Failed to locate filter class.")
                return
            }

            // Create a variable blur filter instance
            guard let variableBlur = unsafe filterClass.perform(
                NSSelectorFromString(InternedKeys.filterWithType),
                with: InternedKeys.variableBlur
            ).takeUnretainedValue() as? NSObject else {
                logger.error("Failed to create variable blur filter instance.")
                return
            }

            // Configure the filter's static parameters
            variableBlur.setValue(configuredMaxBlurRadius, forKey: InternedKeys.inputRadius)
            variableBlur.setValue(true, forKey: InternedKeys.inputNormalizeEdges)

            // Apply the filter to the backdrop layer (first subview's layer)
            let backdropLayer = subviews.first?.layer
            backdropLayer?.filters = [variableBlur]

            // Remove the default dimming/tint overlay by making additional subviews transparent
            for subview in subviews.dropFirst() {
                subview.alpha = 0
            }

            // Store reference for later mask updates
            variableBlurFilter = variableBlur
        }

        // MARK: - Mask Generation and Caching

        /**
         * Updates the blur mask for the specified size, with optional forced regeneration.
         *
         * This is the core method that manages mask generation and caching. It compares
         * the current parameters against the last generation to avoid unnecessary work.
         *
         * - Parameters:
         *   - size: The target size for the mask
         */
        private func updateMask(for size: CGSize) {
            setupVariableBlurFilter()

            guard size.width > 0, size.height > 0 else { return }

            let gradientImage = generateMaskImage(size: size, scale: currentScale)

            guard let gradientImage else {
                logger.error("Failed to generate mask image")
                return
            }

            variableBlurFilter?.setValue(gradientImage, forKey: InternedKeys.inputMaskImage)
        }

        /**
         * Generates the actual mask image using Metal shaders.
         *
         * This method calls the appropriate shader kernel based on the configured mask type
         * and returns a CGImage that can be used as a blur mask. All generation happens
         * on the GPU for optimal performance.
         *
         * - Parameters:
         *   - size: The size in points for the mask
         *   - scale: Display scale for pixel-accurate rendering
         * - Returns: A CGImage containing the blur mask, or nil if generation fails
         */
        private func generateMaskImage(size: CGSize, scale: CGFloat) -> CGImage? {
            let scaledWidth = max(1, ceil(size.width * scale))
            let scaledHeight = max(1, ceil(size.height * scale))
            let extent = CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)

            switch configuredMaskType {
            case .linearTopToBottom:
                let args: [Any] = [scaledWidth, scaledHeight, configuredStartOffset, 0.0]
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.linearMask,
                    extent: extent,
                    arguments: args
                )

            case .linearBottomToTop:
                let args: [Any] = [scaledWidth, scaledHeight, configuredStartOffset, 1.0]
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.linearMask,
                    extent: extent,
                    arguments: args
                )

            case .easeInTopToBottom:
                let args: [Any] = [scaledWidth, scaledHeight, configuredStartOffset, 0.0]
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.easeInMask,
                    extent: extent,
                    arguments: args
                )

            case .easeInBottomToTop:
                let args: [Any] = [scaledWidth, scaledHeight, configuredStartOffset, 1.0]
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.easeInMask,
                    extent: extent,
                    arguments: args
                )

            case .roundedRectangle:
                let scaledCornerRadius = configuredCornerRadius * scale
                let scaledFadeWidth = configuredFadeWidth * scale
                let args: [Any] = [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth]
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.roundedRectMask,
                    extent: extent,
                    arguments: args
                )

            case .easedRoundedRectangle:
                let scaledCornerRadius = configuredCornerRadius * scale
                let scaledFadeWidth = configuredFadeWidth * scale
                let args: [Any] = [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth]
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.roundedRectEaseMask,
                    extent: extent,
                    arguments: args
                )

            case .superellipseSquircle:
                let scaledCornerRadius = configuredCornerRadius * scale
                let scaledFadeWidth = configuredFadeWidth * scale
                let args: [Any] = [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth, 2]
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.superellipseMask,
                    extent: extent,
                    arguments: args
                )

            case .easedSuperellipseSquircle:
                let scaledCornerRadius = configuredCornerRadius * scale
                let scaledFadeWidth = configuredFadeWidth * scale
                let args: [Any] = [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth, 2]
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.superellipseEaseMask,
                    extent: extent,
                    arguments: args
                )
            }
        }

        // MARK: - UIView Lifecycle Overrides

        /**
         * Responds to window changes by updating the backdrop layer scale and regenerating the mask.
         *
         * This ensures the blur effect maintains proper scaling when moved between displays
         * with different scale factors (e.g., Retina vs. non-Retina displays).
         */
        override open func didMoveToWindow() {
            guard let window, let backdropLayer = subviews.first?.layer else { return }

            // Update the backdrop layer's scale to match the new window's screen
            backdropLayer.setValue(window.screen.scale, forKey: "scale")

            // Regenerate mask for the new display scale
            updateMask(for: bounds.size)
        }

        /**
         * Responds to layout changes by updating the mask if necessary.
         *
         * This ensures the blur mask always matches the current view bounds and maintains
         * pixel-perfect accuracy across different screen sizes and orientations.
         */
        override open func layoutSubviews() {
            super.layoutSubviews()
            updateMask(for: bounds.size)
        }

        /**
         * Intentionally empty trait collection change handler.
         *
         * Calling super here can cause issues with filter APIs,
         * so we override to prevent the default behavior.
         */
        override open func traitCollectionDidChange(_: UITraitCollection?) {
            // Intentionally left blank to avoid crashes with filter APIs
        }
    }
#endif
