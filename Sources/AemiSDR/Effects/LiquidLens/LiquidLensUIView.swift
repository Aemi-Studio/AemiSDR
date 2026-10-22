//
//  LiquidLensUIView.swift
//  AemiSDR
//

#if os(iOS)
    import Metal
    import OSLog
    import QuartzCore
    import Synchronization
    import UIKit

    /// A `UIView` backed by `CAMetalLayer` that renders the physics-based liquid lens effect.
    ///
    /// This view converts a source `CGImage` into a Metal texture, applies the liquid lens
    /// fragment shader with configurable parameters, and presents the result directly
    /// via `CAMetalLayer`. Because the layer uses `isOpaque = false` with a clear background,
    /// SwiftUI `.clipShape()` and other masking composites work naturally.
    ///
    /// ## Usage
    /// ```swift
    /// let view = LiquidLensUIView(configuration: .init(halfSize: SIMD2(200, 200), strength: 1.5))
    /// view.setSourceImage(someImage)
    /// ```
    open class LiquidLensUIView: UIView {
        // MARK: - Properties

        private let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: "LiquidLensUIView"
        )

        /// Test seam: counts the number of render attempts dispatched by layout, configuration, or metric changes.
        var renderAttemptCount: Int = 0

        /// Test seam: the number of drawables currently being processed by the GPU.
        var inFlightDrawableCount: Int { inFlightDrawables.load(ordering: .relaxed) }

        private var needsRender = true
        private let inFlightDrawables = Atomic<Int>(0)

        private var renderer: LiquidLensRenderer?
        private var source: TextureSourceLease?
        private var configuration: LiquidLensConfiguration

        /// Optional shape path provider for masking the Metal layer to match the parent view's clip shape.
        var clipShapePath: ShapePathProvider? {
            didSet {
                needsRender = true
                updateClipMask()
            }
        }

        /// Fired once when the view first becomes ready for capture (has a window
        /// and a non-zero size). Used by `_LiquidLensOverlay` to trigger the
        /// initial capture exactly when the SwiftUI hierarchy has laid out,
        /// replacing a hard-coded `asyncAfter(0.1)` timing hack.
        var onReadyForFirstCapture: (() -> Void)?
        private var didFireReady = false

        /// Fires when the view's superview chain or trait collection has
        /// changed, signalling that the `BackdropCaptureCoordinator`'s cached
        /// content sibling / background color may be stale. Bound by
        /// `_LiquidLensOverlay` to the coordinator's
        /// `invalidateContentLookupCaches()`.
        var onContentHierarchyChanged: (() -> Void)?

        override open class var layerClass: AnyClass { CAMetalLayer.self }

        // Safe by construction: `layerClass` above returns `CAMetalLayer.self`,
        // so `layer` is guaranteed to be a `CAMetalLayer`. A subclass that
        // overrides `layerClass` would invalidate this — `open` permits
        // subclassing, so a future maintainer adding a subclass must override
        // both or accept the trap. The cost of `as?` per render is non-zero.
        // swift-format-ignore: NeverForceUnwrap
        private var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

        // MARK: - Initialization

        public init(configuration: LiquidLensConfiguration = .init()) {
            self.configuration = configuration
            super.init(frame: .zero)

            renderer = LiquidLensRenderer()

            guard let device = renderer?.device else {
                logger.error("Metal renderer unavailable; LiquidLensUIView will not render.")
                return
            }

            metalLayer.device = device
            // Pixel format selection — see also `LiquidLensRenderer.pipelinePixelFormat`.
            // On real iOS devices (A14+/M-series): 10-bit extended-range sRGB +
            //   Display P3 colorspace preserves wide-gamut backdrop content.
            // On the iOS simulator: `bgra10_xr_srgb` reports "not blendable" at
            //   pipeline-state validation time. Fall back to `bgra8Unorm_srgb`
            //   (8-bit sRGB, blendable everywhere) and skip the P3 tag.
            #if targetEnvironment(simulator)
                metalLayer.pixelFormat = .bgra8Unorm_srgb
            #else
                metalLayer.pixelFormat = .bgra10_xr_srgb
                metalLayer.colorspace = CGColorSpace(name: CGColorSpace.displayP3)
            #endif
            metalLayer.isOpaque = false
            metalLayer.framebufferOnly = true

            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Public API

        /// Sets the source image to be distorted by the lens effect.
        public func setSourceImage(_ image: CGImage) {
            guard let renderer else { return }
            source = renderer.makeTexture(from: image).map { TextureSourceLease(texture: $0) }
            needsRender = true
            renderIfNeeded()
        }

        /// Sets the source image from a `UIImage`.
        public func setSourceImage(_ image: UIImage) {
            guard let cgImage = image.cgImage else {
                logger.warning("UIImage has no CGImage backing; ignoring.")
                return
            }
            setSourceImage(cgImage)
        }

        /// Sets a pre-existing Metal texture as the source, bypassing `makeTexture` conversion.
        ///
        /// Use this with ``ZeroCopyTextureBridge`` to avoid per-frame texture allocations.
        ///
        /// - Parameters:
        ///   - texture: The Metal texture to render with.
        ///   - onConsumed: Called once after the source is replaced or the view is destroyed AND all GPU reads
        ///     using it have completed. The callback may run on a completion thread. The producer must not
        ///     overwrite the texture until this callback, including when the view cannot obtain a drawable yet.
        public func setSourceTexture(_ texture: MTLTexture, onConsumed: (@Sendable () -> Void)? = nil) {
            source = TextureSourceLease(texture: texture, onConsumed: onConsumed)
            needsRender = true
            renderIfNeeded()
        }

        /// Captures the given view's rendered content and uses it as the source texture.
        public func captureContent(of view: UIView) {
            guard bounds.width > 0, bounds.height > 0 else { return }
            let format = UIGraphicsImageRendererFormat()
            format.scale = displayScale
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
            let image = renderer.image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
            }
            setSourceImage(image)
        }

        /// Updates the lens configuration, re-rendering only if the configuration changed.
        public func updateConfiguration(_ newConfiguration: LiquidLensConfiguration) {
            guard configuration != newConfiguration else { return }
            configuration = newConfiguration
            needsRender = true
            renderIfNeeded()
        }

        // MARK: - UIView Lifecycle

        /// Last drawable size + contents scale pushed to the `CAMetalLayer`.
        /// `layoutSubviews` and `didMoveToWindow` both fire on the same first
        /// attach, so the metric write + render is gated on a real change to
        /// avoid two identical render passes back-to-back.
        private var lastDrawableSize: CGSize = .zero
        private var lastContentsScale: CGFloat = 0

        @discardableResult
        private func syncDrawableMetrics() -> Bool {
            let scale = displayScale
            let size = CGSize(
                width: bounds.width * scale,
                height: bounds.height * scale
            )
            guard size != lastDrawableSize || scale != lastContentsScale else { return false }
            metalLayer.contentsScale = scale
            metalLayer.drawableSize = size
            lastDrawableSize = size
            lastContentsScale = scale
            needsRender = true
            return true
        }

        override open func layoutSubviews() {
            super.layoutSubviews()
            syncDrawableMetrics()
            updateClipMask()
            // Always attempt a render: `renderIfNeeded` is a no-op when no source texture is set yet.
            // Gating this on `metricsChanged` skipped the retry that lets a
            // late-arriving source texture redraw on the next layout pass —
            // visible as "starts blank, fixes on interaction" the first time
            // the view becomes visible after the lens was added.
            renderIfNeeded()
            fireReadyIfPossible()
        }

        override open func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            onContentHierarchyChanged?()
            syncDrawableMetrics()
            renderIfNeeded()
            fireReadyIfPossible()
        }

        override open func didMoveToSuperview() {
            super.didMoveToSuperview()
            onContentHierarchyChanged?()
        }

        override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            // Background color resolution depends on traitCollection (dark/light).
            // The coordinator caches the resolved CGColor; invalidate on change.
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                onContentHierarchyChanged?()
            }
        }

        private func fireReadyIfPossible() {
            guard !didFireReady,
                window != nil,
                bounds.width > 0,
                bounds.height > 0
            else { return }
            didFireReady = true
            onReadyForFirstCapture?()
        }

        // MARK: - Clip Masking

        private func updateClipMask() {
            guard bounds.width > 0, bounds.height > 0 else { return }
            if let clipShapePath {
                let maskLayer = (layer.mask as? CAShapeLayer) ?? CAShapeLayer()
                maskLayer.frame = bounds
                maskLayer.path = clipShapePath(bounds)
                if layer.mask == nil {
                    layer.mask = maskLayer
                }
            } else {
                layer.mask = nil
            }
        }

        // MARK: - Rendering

        private func renderIfNeeded() {
            guard needsRender else { return }
            renderAttemptCount += 1
            // Keep the source reserved on an early exit: a later layout/configuration update may retry it.
            // Replacement or view destruction drops that hold; GPU submissions own independent holds below.
            guard let renderer, let source else { return }
            guard metalLayer.drawableSize.width > 0, metalLayer.drawableSize.height > 0 else { return }
            let maxDrawables = max(1, metalLayer.maximumDrawableCount - 1)
            guard inFlightDrawables.load(ordering: .relaxed) < maxDrawables else { return }
            guard let drawable = metalLayer.nextDrawable() else { return }

            let textureSize = SIMD2<Float>(
                Float(metalLayer.drawableSize.width),
                Float(metalLayer.drawableSize.height)
            )
            let uniforms = configuration.toUniforms(
                textureSize: textureSize,
                scale: Float(metalLayer.contentsScale)
            )

            let read = source.beginRead()
            inFlightDrawables.wrappingAdd(1, ordering: .relaxed)
            needsRender = false

            renderer.render(
                sourceTexture: source.texture,
                uniforms: uniforms,
                pipelineKey: configuration.pipelineKey(),
                drawable: drawable,
                onCompleted: { [weak self] in
                    read.finish()
                    guard let self else { return }
                    self.inFlightDrawables.wrappingSubtract(1, ordering: .relaxed)
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.needsRender else { return }
                        self.renderIfNeeded()
                    }
                }
            )
        }
    }
#endif
