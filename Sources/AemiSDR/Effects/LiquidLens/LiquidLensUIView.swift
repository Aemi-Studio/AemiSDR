//
//  LiquidLensUIView.swift
//  AemiSDR
//

#if os(iOS)
    import Metal
    import OSLog
    import QuartzCore
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
    /// let view = LiquidLensUIView(configuration: .init(radius: 200, strength: 1.5))
    /// view.setSourceImage(someImage)
    /// ```
    open class LiquidLensUIView: UIView {

        // MARK: - Properties

        private let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: "LiquidLensUIView"
        )

        private var renderer: LiquidLensRenderer?
        private var sourceTexture: MTLTexture?
        private var configuration: LiquidLensConfiguration

        /// Optional shape path provider for masking the Metal layer to match the parent view's clip shape.
        var clipShapePath: ShapePathProvider? {
            didSet { updateClipMask() }
        }

        override open class var layerClass: AnyClass { CAMetalLayer.self }

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
            metalLayer.pixelFormat = .bgra8Unorm
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
            sourceTexture = renderer.makeTexture(from: image)
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
        public func setSourceTexture(_ texture: MTLTexture) {
            sourceTexture = texture
            renderIfNeeded()
        }

        /// Captures the given view's rendered content and uses it as the source texture.
        public func captureContent(of view: UIView) {
            guard bounds.width > 0, bounds.height > 0 else { return }
            let scale = window?.screen.scale ?? UIScreen.main.scale
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
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
            renderIfNeeded()
        }

        // MARK: - UIView Lifecycle

        override open func layoutSubviews() {
            super.layoutSubviews()
            let scale = window?.screen.scale ?? UIScreen.main.scale
            metalLayer.contentsScale = scale
            metalLayer.drawableSize = CGSize(
                width: bounds.width * scale,
                height: bounds.height * scale
            )
            updateClipMask()
            renderIfNeeded()
        }

        override open func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            let scale = window?.screen.scale ?? UIScreen.main.scale
            metalLayer.contentsScale = scale
            metalLayer.drawableSize = CGSize(
                width: bounds.width * scale,
                height: bounds.height * scale
            )
            renderIfNeeded()
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
            guard let renderer, let sourceTexture else { return }
            guard bounds.width > 0, bounds.height > 0 else { return }
            guard let drawable = metalLayer.nextDrawable() else { return }

            let textureSize = SIMD2<Float>(
                Float(metalLayer.drawableSize.width),
                Float(metalLayer.drawableSize.height)
            )
            let uniforms = configuration.toUniforms(
                textureSize: textureSize,
                scale: Float(metalLayer.contentsScale)
            )

            renderer.render(
                sourceTexture: sourceTexture,
                uniforms: uniforms,
                drawable: drawable
            )
        }
    }
#endif
