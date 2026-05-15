//
//  BackdropCaptureCoordinator.swift
//  AemiSDR
//

#if os(iOS)
    import QuartzCore
    import UIKit

    /// Base coordinator that manages `CADisplayLink`-driven backdrop capture via
    /// `BackdropCaptureView` and `ZeroCopyTextureBridge`.
    ///
    /// On pre-iOS 26, inserts a `BackdropCaptureView` (backed by `CABackdropLayer`)
    /// as a sibling below the effect view and rasterizes it via `drawHierarchy`.
    ///
    /// On iOS 26+, `CABackdropLayer` no longer exposes captured content through
    /// `drawHierarchy` or `layer.render(in:)`. The coordinator falls back to
    /// capturing the content sibling view directly — the SwiftUI view behind the
    /// effect in the `.background`/`.overlay` container.
    ///
    /// Subclasses override `processTexture(_:)` to route the captured `MTLTexture`
    /// to their specific rendering pipeline.
    @MainActor
    class BackdropCaptureCoordinator {
        /// The effect view this coordinator manages capture for.
        /// Set by the owning `UIViewRepresentable`.
        weak var effectView: UIView?

        var hasCaptured = false
        var continuousCapture = false
        var refreshRate: Int = 30
        var captureScale: CGFloat = 1.0

        private var displayLink: CADisplayLink?
        private var displayLinkProxy: DisplayLinkProxy?
        private var backgroundObserver: NSObjectProtocol?
        private var foregroundObserver: NSObjectProtocol?
        private var isPaused = false
        private var bridge: ZeroCopyTextureBridge?
        private var captureView: BackdropCaptureView?
        private var captureViewHasRendered = false
        private var isCapturing = false

        // Cheap content-change signature for the iOS 26 capture path.
        // When the captured content sibling hasn't visibly changed since the
        // last capture, the (expensive) `drawHierarchy` raster pass is skipped.
        private var lastContentSignature: ContentSignature?

        private struct ContentSignature: Equatable {
            let bounds: CGRect
            let subviewCount: Int
            let sublayerCount: Int
            let contentsIdentifier: ObjectIdentifier?
        }

        init() {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.pauseDisplayLink()
                }
            }
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.resumeDisplayLink()
                }
            }
        }

        // MARK: - Override Point

        /// Called with a captured texture each frame. Subclasses must override to
        /// route `captured.texture` to their rendering pipeline AND to invoke
        /// `captured.onConsumed` (typically via `MTLCommandBuffer.addCompletedHandler`)
        /// once the GPU finishes reading. Failing to invoke `onConsumed` will
        /// eventually stall the bridge's slot ring.
        func processTexture(_ captured: ConsumableTexture) {
            // Subclasses override
        }

        // MARK: - BackdropCaptureView Management (pre-iOS 26)

        /// Inserts or updates the `BackdropCaptureView` as a sibling below the effect view.
        private func ensureCaptureView() {
            guard let effectView, let superview = effectView.superview else { return }

            if captureView == nil {
                let view = BackdropCaptureView()
                if captureScale < 1.0 {
                    view.setReducedBitDepth(true)
                }
                view.setCaptureScale(captureScale)
                captureView = view
                captureViewHasRendered = false
            }

            guard let captureView else { return }

            if captureView.superview !== superview {
                captureView.removeFromSuperview()
                superview.insertSubview(captureView, belowSubview: effectView)
            }
            captureView.frame = effectView.frame
        }

        private func removeCaptureView() {
            captureView?.removeFromSuperview()
            captureView = nil
        }

        // MARK: - Display Link

        func startDisplayLink() {
            guard displayLink == nil else {
                updateDisplayLinkRate()
                return
            }
            // Route the display-link callback through a weak proxy so the link
            // does not retain the coordinator. If `tearDown()` is missed (e.g.
            // SwiftUI replaces the representable mid-flight), the coordinator
            // can still deallocate and the proxy's weak target becomes nil.
            let proxy = DisplayLinkProxy(target: self)
            let link = unsafe CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
            applyFrameRate(to: link)
            link.add(to: .main, forMode: .common)
            displayLink = link
            displayLinkProxy = proxy
        }

        func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
            displayLinkProxy = nil
        }

        func updateDisplayLinkRate() {
            guard let displayLink else { return }
            applyFrameRate(to: displayLink)
        }

        private func applyFrameRate(to link: CADisplayLink) {
            let fps = refreshRate
            if #available(iOS 15.0, *) {
                let fpsFloat = Float(fps)
                link.preferredFrameRateRange = CAFrameRateRange(
                    minimum: fpsFloat, maximum: fpsFloat, preferred: fpsFloat
                )
            } else {
                link.preferredFramesPerSecond = fps
            }
        }

        private func pauseDisplayLink() {
            isPaused = true
            displayLink?.isPaused = true
        }

        private func resumeDisplayLink() {
            guard continuousCapture else { return }
            isPaused = false
            displayLink?.isPaused = false
        }

        fileprivate func displayLinkFired(_ link: CADisplayLink) {
            guard let effectView, effectView.window != nil else { return }
            guard effectView.bounds.width > 0, effectView.bounds.height > 0 else { return }
            performCapture()
        }

        // MARK: - Capture

        /// Performs a single capture (used for initial load and config changes).
        func captureOnce() {
            guard let effectView else { return }
            guard effectView.bounds.width > 0, effectView.bounds.height > 0 else { return }
            guard effectView.window != nil else { return }

            performCapture()
            hasCaptured = true
        }

        private func performCapture() {
            guard !isCapturing else { return }
            isCapturing = true
            defer { isCapturing = false }

            if #available(iOS 26, *) {
                performContentSiblingCapture()
            } else {
                performBackdropLayerCapture()
            }
        }

        // MARK: - iOS 26+ Content Sibling Capture

        /// On iOS 26, CABackdropLayer no longer exposes captured content through any
        /// CPU-accessible path. Instead, find the content sibling in the SwiftUI
        /// overlay/background container and capture it directly via `drawHierarchy`.
        @available(iOS 26, *)
        private func performContentSiblingCapture() {
            guard let effectView else { return }
            guard let contentView = findContentSibling(for: effectView) else { return }

            let screenScale = effectView.displayScale
            let scale = screenScale * captureScale
            let frameInContent = effectView.convert(effectView.bounds, to: contentView)

            let pixelWidth = Int(frameInContent.width * scale)
            let pixelHeight = Int(frameInContent.height * scale)
            guard pixelWidth > 0, pixelHeight > 0 else { return }

            // Skip the (expensive) drawHierarchy raster when the captured view's
            // cheap visual signature is unchanged. A typical app screen is static
            // between user inputs; this saves a full hierarchy rasterisation per
            // display-link tick.
            let signature = ContentSignature(
                bounds: contentView.bounds,
                subviewCount: contentView.subviews.count,
                sublayerCount: contentView.layer.sublayers?.count ?? 0,
                contentsIdentifier: contentView.layer.contents.map { ObjectIdentifier($0 as AnyObject) }
            )
            if signature == lastContentSignature && hasCaptured { return }
            lastContentSignature = signature

            ensureBridge()

            let bgColor = resolveBackgroundColor(for: contentView, traitCollection: contentView.traitCollection)

            if let captured = bridge?.render(width: pixelWidth, height: pixelHeight, actions: { ctx in
                ctx.saveGState()
                // Pre-fill with resolved background to avoid black through transparent areas
                ctx.setFillColor(bgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
                // Flip Quartz (bottom-left origin) → UIKit (top-left origin)
                ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
                ctx.scaleBy(x: 1, y: -1)
                ctx.scaleBy(x: scale, y: scale)
                // Offset to capture only the effect view's portion
                ctx.translateBy(x: -frameInContent.origin.x, y: -frameInContent.origin.y)
                UIGraphicsPushContext(ctx)
                contentView.drawHierarchy(in: contentView.bounds, afterScreenUpdates: false)
                UIGraphicsPopContext()
                ctx.restoreGState()
            }) {
                processTexture(captured)
            }
        }

        /// Finds the content sibling view in a SwiftUI background/overlay container.
        ///
        /// SwiftUI `.background`/`.overlay` creates a container with the content view
        /// as the first child and the modifier view(s) as subsequent children. By
        /// capturing only the content sibling, we avoid a feedback loop where the
        /// effect's output is re-captured as input.
        private func findContentSibling(for view: UIView) -> UIView? {
            var current = view.superview
            while let parent = current {
                if parent.subviews.count >= 2 {
                    for sibling in parent.subviews where !view.isDescendant(of: sibling) {
                        return sibling
                    }
                    return parent
                }
                current = parent.superview
            }
            return nil
        }

        /// Walks the view hierarchy to find the first non-clear background color.
        ///
        /// Resolves dynamic colors against the captured view's trait collection so
        /// the fill reflects the current dark/light appearance rather than the
        /// caller's environment.
        private func resolveBackgroundColor(for view: UIView, traitCollection: UITraitCollection) -> CGColor {
            var current: UIView? = view
            while let v = current {
                if let bg = v.backgroundColor, bg != .clear {
                    return bg.resolvedColor(with: traitCollection).cgColor
                }
                current = v.superview
            }
            return UIColor.systemBackground.resolvedColor(with: traitCollection).cgColor
        }

        // MARK: - Pre-iOS 26 BackdropLayer Capture

        /// Pre-iOS 26: use `CABackdropLayer`-backed capture view for efficient
        /// window-server-level compositing via `drawHierarchy`.
        private func performBackdropLayerCapture() {
            guard let effectView else { return }

            ensureCaptureView()
            guard let captureView else { return }

            let screenScale = effectView.displayScale
            let scale = screenScale * captureScale

            let pixelWidth = Int(captureView.bounds.width * scale)
            let pixelHeight = Int(captureView.bounds.height * scale)
            guard pixelWidth > 0, pixelHeight > 0 else { return }

            ensureBridge()

            if let captured = bridge?.render(width: pixelWidth, height: pixelHeight, actions: { ctx in
                ctx.saveGState()
                ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
                ctx.scaleBy(x: 1, y: -1)
                ctx.scaleBy(x: scale, y: scale)
                let needsScreenUpdate = !self.captureViewHasRendered
                UIGraphicsPushContext(ctx)
                captureView.drawHierarchy(in: captureView.bounds, afterScreenUpdates: needsScreenUpdate)
                UIGraphicsPopContext()
                self.captureViewHasRendered = true
                ctx.restoreGState()
            }) {
                processTexture(captured)
            }
        }

        // MARK: - Bridge

        private func ensureBridge() {
            guard bridge == nil, let effectView else { return }
            let device: MTLDevice?
            if let metalLayer = effectView.layer as? CAMetalLayer {
                device = metalLayer.device
            } else {
                device = MTLCreateSystemDefaultDevice()
            }
            if let device {
                bridge = ZeroCopyTextureBridge(device: device)
            }
        }

        // MARK: - Cleanup

        func tearDown() {
            stopDisplayLink()
            removeCaptureView()
            if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
            if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
            backgroundObserver = nil
            foregroundObserver = nil
        }

        // Defense-in-depth for missed `tearDown()` (e.g. SwiftUI replacing the
        // representable mid-flight without invoking `dismantleUIView`). Without
        // this, the `CADisplayLink` keeps firing into the no-op weak-proxy
        // forever and the notification observers accumulate over the app's
        // lifetime. Both `CADisplayLink.invalidate()` and
        // `NotificationCenter.removeObserver(_:)` are documented thread-safe,
        // so the deinit is safe whichever thread releases the last reference.
        deinit {
            displayLink?.invalidate()
            if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
            if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        }
    }

    /// Weak forwarding target for `CADisplayLink`.
    ///
    /// `CADisplayLink` retains its `target` strongly. When the coordinator is
    /// the direct target, missing a `tearDown()` keeps the coordinator alive
    /// indefinitely and the display link keeps firing. Routing through this
    /// proxy means the link retains the proxy (cheap, no observers) while the
    /// coordinator may deallocate normally.
    @MainActor
    private final class DisplayLinkProxy: NSObject {
        weak var target: BackdropCaptureCoordinator?

        init(target: BackdropCaptureCoordinator) {
            self.target = target
        }

        @objc func fire(_ link: CADisplayLink) {
            target?.displayLinkFired(link)
        }
    }
#endif
