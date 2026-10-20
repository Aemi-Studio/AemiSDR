//
//  ClearGlassUIView.swift
//  AemiSDR
//
//  A view that is a piece of clear glass: its bounds hold the shape, and it shows the part of a source image behind
//  it, blurred, lifted and pulled at the rim as native clear glass does. See ADR-0008.
//

#if canImport(UIKit) && canImport(Metal)
    import CoreGraphics
    import Metal
    import QuartzCore
    import UIKit

    @MainActor
    public final class ClearGlassUIView: UIView {
        /// The look of the glass. Changing it redraws.
        public var configuration: ClearGlassConfiguration {
            didSet {
                guard configuration != oldValue else { return }
                if configuration.shape != oldValue.shape { field = nil }
                setNeedsRedraw()
            }
        }

        private let renderer: ClearGlassRenderer?
        private var source: MTLTexture?
        private var sourceOriginOverride: CGPoint?
        private var field: MTLTexture?
        private var fieldKey: String?
        private var redrawPending = false

        /// The glass is drawn in a child layer that reaches `configuration.margin` points beyond the bounds, so the dark
        /// ring outside the edge is not clipped.
        private let metalLayer = CAMetalLayer()

        public init(configuration: ClearGlassConfiguration = ClearGlassConfiguration()) {
            self.configuration = configuration
            renderer = ClearGlassRenderer()
            super.init(frame: .zero)
            commonInit()
        }

        public override init(frame: CGRect) {
            configuration = ClearGlassConfiguration()
            renderer = ClearGlassRenderer()
            super.init(frame: frame)
            commonInit()
        }

        @available(*, unavailable)
        public required init?(coder: NSCoder) { fatalError("ClearGlassUIView is created in code") }

        private func commonInit() {
            isOpaque = false
            backgroundColor = .clear
            isUserInteractionEnabled = false
            clipsToBounds = false
            layer.addSublayer(metalLayer)
            metalLayer.isOpaque = false
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.framebufferOnly = true
            metalLayer.device = renderer?.device
        }

        /// What is behind the glass. `origin` is where this view's top-left corner sits in the image, in points; when
        /// nil, the view's position in its window is used, which is right when the image covers the window.
        public func setSourceImage(_ image: CGImage, origin: CGPoint? = nil) {
            source = renderer?.makeSourceTexture(from: image)
            sourceOriginOverride = origin
            setNeedsRedraw()
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            redraw()
        }

        public override func didMoveToWindow() {
            super.didMoveToWindow()
            setNeedsRedraw()
        }

        private func setNeedsRedraw() {
            guard !redrawPending else { return }
            redrawPending = true
            // Coalesce: several changes in one turn of the run loop draw once.
            DispatchQueue.main.async { [weak self] in
                self?.redrawPending = false
                self?.redraw()
            }
        }

        private func redraw() {
            guard let renderer, let source, bounds.width > 0, bounds.height > 0 else { return }
            let scale = window?.screen.scale ?? traitCollection.displayScale
            let margin = configuration.margin
            let outer = bounds.insetBy(dx: -margin, dy: -margin)
            metalLayer.frame = outer
            metalLayer.contentsScale = scale
            metalLayer.drawableSize = CGSize(
                width: (outer.width * scale).rounded(), height: (outer.height * scale).rounded())
            let origin = sourceOriginOverride ?? convert(CGPoint.zero, to: nil)
            let uniforms = configuration.uniforms(
                size: bounds.size, scale: scale,
                sourceOrigin: CGPoint(x: (origin.x - margin) * scale, y: (origin.y - margin) * scale),
                sourceSize: CGSize(width: source.width, height: source.height))
            guard let drawable = metalLayer.nextDrawable(), let buffer = renderer.makeCommandBuffer() else { return }
            let sdf = distanceField(renderer: renderer, outer: outer.size, margin: margin, scale: scale)
            guard
                renderer.encode(
                    into: buffer, source: source, uniforms: uniforms, blur: configuration.blurPlan(scale: scale),
                    field: sdf,
                    target: drawable.texture)
            else { return }
            buffer.present(drawable)
            buffer.commit()
        }

        /// The distance texture for a path shape, rebuilt only when the path or the pixel size changes. The raster covers
        /// the whole layer, margin included, so the field is defined just outside the shape too.
        private func distanceField(renderer: ClearGlassRenderer, outer: CGSize, margin: CGFloat, scale: CGFloat)
            -> MTLTexture?
        {
            guard case .path(let path) = configuration.shape else { return nil }
            let width = Int((outer.width * scale).rounded())
            let height = Int((outer.height * scale).rounded())
            let key = "\(path.hashValue)-\(width)x\(height)-\(margin)"
            if let field, fieldKey == key { return field }
            let values = SignedDistanceField.exact(
                path: path, width: width, height: height, scale: scale, origin: CGPoint(x: margin, y: margin))
            field = renderer.makeFieldTexture(values)
            fieldKey = key
            return field
        }
    }
#endif
