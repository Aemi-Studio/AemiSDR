//
//  AlphaMaskUIView.swift
//  AemiSDR
//

#if os(iOS)
    import OSLog
    import UIKit

    /// A UIView that renders alpha masks using Metal shaders for destination-out compositing effects.
    ///
    /// AlphaMaskUIView creates sophisticated alpha masks that can be used to selectively hide or reveal
    /// portions of content placed behind it. The view itself becomes the mask, where:
    /// - Transparent areas allow content to show through
    /// - White areas hide the content behind (destination-out effect)
    /// - The alpha channel from the Metal shaders determines the final transparency
    ///
    /// Key Features:
    /// - Multiple mask types: linear gradients, rounded rectangles, and superellipse squircles
    /// - Hardware-accelerated Metal shader rendering for optimal performance
    /// - Automatic caching and regeneration based on view size and configuration changes
    /// - Support for both linear and eased (smooth) transition functions
    /// - Configurable inversion for different masking effects
    ///
    /// The view automatically updates its mask when layout changes occur and caches the generated
    /// mask images to avoid unnecessary recomputation.
    public class AlphaMaskUIView: UIView {
        // MARK: - Configuration Properties

        /// The type of mask shape to generate (linear, rounded rectangle, superellipse, etc.)
        private var configuredMaskType: MaskType

        /// Start offset for linear gradients (as fraction) or transition smoothness for shaped masks
        private var configuredStartOffset: CGFloat

        /// Corner radius in points for rounded rectangle and superellipse masks
        private var configuredCornerRadius: CGFloat

        /// Width of the fade transition zone in points
        private var configuredFadeWidth: CGFloat

        /// Whether to invert the mask (true = destination-out effect, false = normal mask)
        private var configuredInverted: Bool

        /// Current display scale, used for pixel-accurate mask generation
        private var currentScale: CGFloat { displayScale }
        private var reusableMaskLayer: CALayer?

        /// Identity of the most recently *requested* mask. A background
        /// generation publishes its result on main only when this matches —
        /// a newer `updateMask` invalidates an in-flight task without race.
        private var pendingMaskKey: MaskCacheKey?

        /// Shared serial queue for off-main mask generation. Serialization
        /// keeps the cost predictable when many alpha-mask views appear at
        /// once (lists, transitions).
        nonisolated private static let backgroundQueue = DispatchQueue(
            label: "studio.aemi.AemiSDR.AlphaMaskUIView.maskGen",
            qos: .userInitiated
        )

        // MARK: - Initialization

        /// Creates a new alpha mask view with the specified configuration.
        ///
        /// - Parameters:
        ///   - maskType: The type of mask to generate (default: linear top-to-bottom)
        ///   - startOffset: Start position for linear gradients or transition control for shapes (default: 0)
        ///   - cornerRadius: Corner radius in points for rounded shapes (default: UIScreen.displayCornerRadius)
        ///   - fadeWidth: Width of fade transition in points (default: 16)
        ///   - inverted: Whether to invert the mask effect (default: true for destination-out)
        public init(
            maskType: MaskType = .linearTopToBottom,
            startOffset: CGFloat = 0,
            cornerRadius: CGFloat = UIScreen.displayCornerRadius,
            fadeWidth: CGFloat = 16,
            inverted: Bool = true
        ) {
            configuredMaskType = maskType
            configuredStartOffset = startOffset
            configuredCornerRadius = cornerRadius
            configuredFadeWidth = fadeWidth
            configuredInverted = inverted

            super.init(frame: .zero)

            // Configure view for optimal masking performance
            isUserInteractionEnabled = false  // No touch handling needed for mask views
            backgroundColor = .clear  // Start with clear background
            isOpaque = false  // Ensure proper alpha blending

            // Generate initial mask
            updateMask(for: bounds.size)
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Configuration Updates

        /// Updates the mask configuration and regenerates if necessary.
        ///
        /// This method compares the new configuration against the current one and only
        /// triggers a mask regeneration if actual changes are detected. This optimization
        /// prevents unnecessary GPU work during animations or frequent updates.
        ///
        /// - Parameters:
        ///   - maskType: The type of mask to generate
        ///   - startOffset: Start position for gradients or transition control
        ///   - cornerRadius: Corner radius for rounded shapes
        ///   - fadeWidth: Fade transition width
        ///   - inverted: Whether to invert the mask
        public func updateConfiguration(
            maskType: MaskType,
            startOffset: CGFloat,
            cornerRadius: CGFloat,
            fadeWidth: CGFloat,
            inverted: Bool
        ) {
            // Check if any configuration has actually changed
            let needsUpdate =
                configuredMaskType != maskType || configuredStartOffset != startOffset
                || configuredCornerRadius != cornerRadius || configuredFadeWidth != fadeWidth
                || configuredInverted != inverted

            if needsUpdate {
                configuredMaskType = maskType
                configuredStartOffset = startOffset
                configuredCornerRadius = cornerRadius
                configuredFadeWidth = fadeWidth
                configuredInverted = inverted

                // Force mask regeneration with new parameters
                updateMask(for: bounds.size)
            }
        }

        // MARK: - Mask Generation

        /// Updates the mask for the specified size, with optional forced regeneration.
        ///
        /// This is the core method that manages mask generation and caching. It compares
        /// the current parameters against the last generation to avoid unnecessary work.
        ///
        /// - Parameters:
        ///   - size: The target size for the mask
        private func updateMask(for size: CGSize) {
            guard size.width > 0, size.height > 0 else { return }

            // Set white background so the mask effect is visible
            // The alpha channel from the shader determines final transparency
            backgroundColor = .white

            let scale = currentScale
            let key = MaskCacheKey.make(
                size: size,
                scale: scale,
                maskType: configuredMaskType,
                startOffset: configuredStartOffset,
                cornerRadius: configuredCornerRadius,
                fadeWidth: configuredFadeWidth,
                inverted: configuredInverted
            )

            // Fast path: identical mask already cached. Stay on main and
            // apply to the layer immediately — no flicker on reattach or
            // common-config recycling.
            if let cached = MaskCache.peek(for: key) {
                pendingMaskKey = nil
                applyMaskImage(cached)
                return
            }

            pendingMaskKey = key

            let maskType = configuredMaskType
            let startOffset = configuredStartOffset
            let cornerRadius = configuredCornerRadius
            let fadeWidth = configuredFadeWidth
            let inverted = configuredInverted

            AlphaMaskUIView.backgroundQueue.async { [weak self] in
                let image = Self.generateAlphaMask(
                    size: size,
                    scale: scale,
                    maskType: maskType,
                    startOffset: startOffset,
                    cornerRadius: cornerRadius,
                    fadeWidth: fadeWidth,
                    inverted: inverted
                )
                guard let image else { return }
                MaskCache.insert(image, for: key)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        guard self.pendingMaskKey == key else { return }
                        self.pendingMaskKey = nil
                        self.applyMaskImage(image)
                    }
                }
            }
        }

        private func applyMaskImage(_ image: CGImage) {
            let maskLayer = reusableMaskLayer ?? CALayer()
            reusableMaskLayer = maskLayer
            maskLayer.frame = bounds
            maskLayer.contents = image
            if layer.mask !== maskLayer {
                layer.mask = maskLayer
            }
        }

        nonisolated private static func generateAlphaMask(
            size: CGSize,
            scale: CGFloat,
            maskType: MaskType,
            startOffset: CGFloat,
            cornerRadius: CGFloat,
            fadeWidth: CGFloat,
            inverted: Bool
        ) -> CGImage? {
            let scaledWidth = max(1, ceil(size.width * scale))
            let scaledHeight = max(1, ceil(size.height * scale))
            let extent = CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)
            let descriptor = maskType.kernelDescriptor(
                size: size, scale: scale, startOffset: startOffset,
                cornerRadius: cornerRadius, fadeWidth: fadeWidth,
                inverted: inverted
            )
            return CIKernelCache.generateCGImage(
                kernel: descriptor.kernel,
                extent: extent,
                arguments: descriptor.arguments,
                context: CIKernelCache.maskContext
            )
        }

        // MARK: - UIView Overrides

        /// Responds to layout changes by updating the mask if necessary.
        ///
        /// This ensures the mask always matches the current view bounds and maintains
        /// pixel-perfect accuracy across different screen sizes and orientations.
        override public func layoutSubviews() {
            super.layoutSubviews()
            updateMask(for: bounds.size)
        }
    }
#endif
