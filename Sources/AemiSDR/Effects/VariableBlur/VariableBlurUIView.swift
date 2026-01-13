//
//  VariableBlurUIView.swift
//  AemiSDR
//

#if os(iOS)
    import OSLog
    import UIKit

    /// A UIVisualEffectView subclass that applies variable blur effects using Metal shaders.
    ///
    /// VariableBlurUIView creates blur effects where intensity varies across the view
    /// based on a mask image. It leverages Core Animation filters for hardware-accelerated
    /// variable blur effects.
    ///
    /// ## Features
    /// - Variable blur intensity controlled by mask images generated from Metal shaders
    /// - Multiple mask types: linear gradients, rounded rectangles, and superellipse squircles
    /// - Hardware-accelerated rendering using Core Animation filters
    /// - Automatic mask regeneration and caching based on view size changes
    /// - Support for both linear and eased transition functions
    /// - Configurable maximum blur radius and fade parameters
    ///
    /// The blur effect reads the mask image's alpha values to determine blur intensity:
    /// - Alpha 1.0 (white) = maximum blur radius
    /// - Alpha 0.0 (black) = no blur (clear)
    /// - Intermediate values = proportional blur intensity
    open class VariableBlurUIView: UIVisualEffectView {
        // MARK: - Private Properties

        private let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: String(describing: VariableBlurUIView.self)
        )

        private var configuredMaxBlurRadius: CGFloat
        private var configuredMaskType: MaskType
        private var configuredStartOffset: CGFloat
        private var configuredCornerRadius: CGFloat
        private var configuredFadeWidth: CGFloat
        private var variableBlurFilter: NSObject?

        private var currentScale: CGFloat {
            window?.screen.scale ?? UIScreen.main.scale
        }

        // MARK: - Initialization

        /// Creates a new variable blur view with the specified configuration.
        ///
        /// - Parameters:
        ///   - maxBlurRadius: Maximum blur radius in points.
        ///   - maskType: The type of mask to generate.
        ///   - startOffset: Start position for gradients or transition control.
        ///   - cornerRadius: Corner radius for rounded shapes.
        ///   - fadeWidth: Width of fade transition in points.
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
            isUserInteractionEnabled = false
            updateMask(for: bounds.size)
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Configuration

        /// Updates the blur configuration and regenerates the mask if necessary.
        ///
        /// This method compares the new configuration against the current one and only
        /// triggers a mask regeneration if actual changes are detected.
        ///
        /// - Parameters:
        ///   - maxBlurRadius: Maximum blur radius in points.
        ///   - maskType: The type of mask to generate.
        ///   - startOffset: Start position for gradients or transition control.
        ///   - cornerRadius: Corner radius for rounded shapes.
        ///   - fadeWidth: Fade transition width.
        public func updateConfiguration(
            maxBlurRadius: CGFloat,
            maskType: MaskType,
            startOffset: CGFloat,
            cornerRadius: CGFloat,
            fadeWidth: CGFloat
        ) {
            let needsUpdate =
                configuredMaxBlurRadius != maxBlurRadius
                || configuredMaskType != maskType
                || configuredStartOffset != startOffset
                || configuredCornerRadius != cornerRadius
                || configuredFadeWidth != fadeWidth

            if needsUpdate {
                configuredMaxBlurRadius = maxBlurRadius
                configuredMaskType = maskType
                configuredStartOffset = startOffset
                configuredCornerRadius = cornerRadius
                configuredFadeWidth = fadeWidth
                updateMask(for: bounds.size)
            }
        }

        // MARK: - UIView Lifecycle

        override open func didMoveToWindow() {
            guard let window, let backdropLayer = subviews.first?.layer else { return }
            backdropLayer.setValue(window.screen.scale, forKey: _InternedKeys.scale)
            updateMask(for: bounds.size)
        }

        override open func layoutSubviews() {
            super.layoutSubviews()
            updateMask(for: bounds.size)
        }

        override open func traitCollectionDidChange(_: UITraitCollection?) {
            // Intentionally empty to avoid crashes with filter APIs
        }
    }

    // MARK: - Filter Setup

    extension VariableBlurUIView {
        fileprivate func setupVariableBlurFilter() {
            guard let filterClass = NSClassFromString(_InternedKeys.caFilterClass) as? NSObject.Type else {
                logger.error("Failed to locate filter class.")
                return
            }

            guard
                let variableBlur = unsafe filterClass.perform(
                    NSSelectorFromString(_InternedKeys.filterWithType),
                    with: _InternedKeys.variableBlur
                ).takeUnretainedValue() as? NSObject
            else {
                logger.error("Failed to create variable blur filter instance.")
                return
            }

            variableBlur.setValue(configuredMaxBlurRadius, forKey: _InternedKeys.inputRadius)
            variableBlur.setValue(true, forKey: _InternedKeys.inputNormalizeEdges)

            let backdropLayer = subviews.first?.layer
            backdropLayer?.filters = [variableBlur]

            for subview in subviews.dropFirst() {
                subview.alpha = 0
            }

            variableBlurFilter = variableBlur
        }
    }

    // MARK: - Mask Generation

    extension VariableBlurUIView {
        fileprivate func updateMask(for size: CGSize) {
            setupVariableBlurFilter()

            guard size.width > 0, size.height > 0 else { return }

            guard let gradientImage = generateMaskImage(size: size, scale: currentScale) else {
                logger.error("Failed to generate mask image")
                return
            }

            variableBlurFilter?.setValue(gradientImage, forKey: _InternedKeys.inputMaskImage)
        }

        fileprivate func generateMaskImage(size: CGSize, scale: CGFloat) -> CGImage? {
            let scaledWidth = max(1, ceil(size.width * scale))
            let scaledHeight = max(1, ceil(size.height * scale))
            let extent = CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)

            switch configuredMaskType {
            case .linearTopToBottom:
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.linearMask,
                    extent: extent,
                    arguments: [scaledWidth, scaledHeight, configuredStartOffset, 0.0]
                )

            case .linearBottomToTop:
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.linearMask,
                    extent: extent,
                    arguments: [scaledWidth, scaledHeight, configuredStartOffset, 1.0]
                )

            case .easeInTopToBottom:
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.easeInMask,
                    extent: extent,
                    arguments: [scaledWidth, scaledHeight, configuredStartOffset, 0.0]
                )

            case .easeInBottomToTop:
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.easeInMask,
                    extent: extent,
                    arguments: [scaledWidth, scaledHeight, configuredStartOffset, 1.0]
                )

            case .roundedRectangle:
                let scaledCornerRadius = configuredCornerRadius * scale
                let scaledFadeWidth = configuredFadeWidth * scale
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.roundedRectMask,
                    extent: extent,
                    arguments: [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth]
                )

            case .easedRoundedRectangle:
                let scaledCornerRadius = configuredCornerRadius * scale
                let scaledFadeWidth = configuredFadeWidth * scale
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.roundedRectEaseMask,
                    extent: extent,
                    arguments: [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth]
                )

            case .superellipseSquircle:
                let scaledCornerRadius = configuredCornerRadius * scale
                let scaledFadeWidth = configuredFadeWidth * scale
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.superellipseMask,
                    extent: extent,
                    arguments: [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth, 2]
                )

            case .easedSuperellipseSquircle:
                let scaledCornerRadius = configuredCornerRadius * scale
                let scaledFadeWidth = configuredFadeWidth * scale
                return VariableBlurCache.generateCGImage(
                    kernel: VariableBlurCache.superellipseEaseMask,
                    extent: extent,
                    arguments: [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth, 2]
                )
            }
        }
    }
#endif
