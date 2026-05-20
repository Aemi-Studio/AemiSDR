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
    public class VariableBlurUIView: UIVisualEffectView {
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
        private var configuredInverted: Bool
        private var configuredScale: CGFloat
        private var variableBlurFilter: NSObject?

        /// Identity of the most recently *requested* mask. Background generations
        /// publish their result back to main only when the latch still matches —
        /// any newer `updateMask` call invalidates an in-flight task by writing
        /// a different key here.
        private var pendingMaskKey: MaskCacheKey?

        /// Serializes mask CGImage generation off the main thread. A shared
        /// `.userInitiated` queue keeps cost predictable when many blur views
        /// scroll into view at once — without serialization, N simultaneous
        /// `createCGImage` calls would all compete for the same `CIContext`.
        nonisolated(unsafe) private static let backgroundQueue = DispatchQueue(
            label: "studio.aemi.AemiSDR.VariableBlurUIView.maskGen",
            qos: .userInitiated
        )

        private var currentScale: CGFloat { displayScale }

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
            fadeWidth: CGFloat = 16,
            inverted: Bool = false,
            scale: CGFloat = 1
        ) {
            configuredMaxBlurRadius = maxBlurRadius
            configuredMaskType = maskType
            configuredStartOffset = startOffset
            configuredCornerRadius = cornerRadius
            configuredFadeWidth = fadeWidth
            configuredInverted = inverted
            configuredScale = scale

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
            fadeWidth: CGFloat,
            inverted: Bool,
            scale: CGFloat
        ) {
            let scaleChanged = configuredScale != scale
            let needsUpdate =
                configuredMaxBlurRadius != maxBlurRadius
                || configuredMaskType != maskType
                || configuredStartOffset != startOffset
                || configuredCornerRadius != cornerRadius
                || configuredFadeWidth != fadeWidth
                || configuredInverted != inverted
                || scaleChanged

            if needsUpdate {
                configuredMaxBlurRadius = maxBlurRadius
                configuredMaskType = maskType
                configuredStartOffset = startOffset
                configuredCornerRadius = cornerRadius
                configuredFadeWidth = fadeWidth
                configuredInverted = inverted
                configuredScale = scale
                // Push the capture scale immediately when it changes;
                // otherwise it sticks on whatever was set in
                // `didMoveToWindow` until the layer next reattaches.
                if scaleChanged, let backdropLayer = subviews.first?.layer {
                    backdropLayer.setValue(scale, forKey: _InternedKeys.scaleFactorKey)
                }
                updateMask(for: bounds.size)
            }
        }

        // MARK: - UIView Lifecycle

        override public func didMoveToWindow() {
            guard window != nil, let backdropLayer = subviews.first?.layer else { return }
            // Honour the caller-configured capture scale instead of
            // implicitly tracking the host window's screen scale. The
            // default value (1.0) matches `BackdropBlurView`; callers
            // who want device-native sampling pass
            // `UIScreen.main.scale` (or the live environment scale)
            // explicitly through `scale:`.
            backdropLayer.setValue(configuredScale, forKey: _InternedKeys.scaleFactorKey)
            updateMask(for: bounds.size)
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            updateMask(for: bounds.size)
        }

        override public func traitCollectionDidChange(_: UITraitCollection?) {
            // Intentionally empty to avoid crashes with filter APIs
        }
    }

    // MARK: - Filter Setup

    extension VariableBlurUIView {
        fileprivate func setupVariableBlurFilter() {
            if let variableBlurFilter {
                variableBlurFilter.setValue(configuredMaxBlurRadius, forKey: _InternedKeys.radiusParam)
                variableBlurFilter.setValue(true, forKey: _InternedKeys.normalizeParam)

                // Force CA to re-evaluate by clearing then re-assigning.
                // Re-assigning the same NSObject reference is optimized away.
                let backdropLayer = subviews.first?.layer
                backdropLayer?.filters = []
                backdropLayer?.filters = [variableBlurFilter]

                for subview in subviews.dropFirst() {
                    subview.alpha = 0
                }
                return
            }

            guard let filterClass = NSClassFromString(_InternedKeys.caLayerFilterClass) as? NSObject.Type else {
                _PrivateAPIDiagnostics.logOnce(
                    key: "caLayerFilterClass",
                    "Private class `\(_InternedKeys.caLayerFilterClass)` not found; variable blur disabled. The host iOS version may have renamed this class."
                )
                return
            }

            let sel = NSSelectorFromString(_InternedKeys.filterCreationSelector)
            guard filterClass.responds(to: sel) else {
                _PrivateAPIDiagnostics.logOnce(
                    key: "filterCreationSelector",
                    "Private selector `\(_InternedKeys.filterCreationSelector)` not implemented by \(filterClass); variable blur disabled."
                )
                return
            }

            guard
                let variableBlur = unsafe filterClass.perform(sel, with: _InternedKeys.maskedBlurFilterID)
                    .takeUnretainedValue() as? NSObject
            else {
                logger.error("Failed to create variable blur filter instance.")
                return
            }

            variableBlur.setValue(configuredMaxBlurRadius, forKey: _InternedKeys.radiusParam)
            variableBlur.setValue(true, forKey: _InternedKeys.normalizeParam)

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

            // Fast path: identical mask already cached. NSCache lookup is
            // O(1) hashed, and we're staying on main to apply the filter
            // value immediately — no flicker on scroll-on / scroll-off of
            // a list of blur cells that share the same configuration.
            if let cached = MaskCache.peek(for: key) {
                pendingMaskKey = nil
                variableBlurFilter?.setValue(cached, forKey: _InternedKeys.maskParam)
                return
            }

            // Latch the requested key so a stale background result that
            // returns after a newer call can be discarded without race.
            pendingMaskKey = key

            // Snapshot the mask inputs on main so the background queue can
            // run without touching any `@MainActor` state. The CIContext and
            // shared kernels (`CIKernelCache.maskContext`, `.linearMask`, …)
            // are documented thread-safe.
            let maskType = configuredMaskType
            let startOffset = configuredStartOffset
            let cornerRadius = configuredCornerRadius
            let fadeWidth = configuredFadeWidth
            let inverted = configuredInverted

            VariableBlurUIView.backgroundQueue.async { [weak self, logger] in
                let image = Self.generateMaskImage(
                    size: size,
                    scale: scale,
                    maskType: maskType,
                    startOffset: startOffset,
                    cornerRadius: cornerRadius,
                    fadeWidth: fadeWidth,
                    inverted: inverted
                )
                guard let image else {
                    logger.error("Failed to generate mask image off main")
                    return
                }
                MaskCache.insert(image, for: key)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        guard self.pendingMaskKey == key else { return }
                        self.pendingMaskKey = nil
                        self.variableBlurFilter?.setValue(image, forKey: _InternedKeys.maskParam)
                    }
                }
            }
        }

        nonisolated private static func generateMaskImage(
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

    }
#endif
