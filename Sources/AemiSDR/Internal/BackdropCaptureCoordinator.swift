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
    /// Inserts a `BackdropCaptureView` (backed by `CABackdropLayer`) as a sibling
    /// below the effect view. On pre-iOS 26, `drawHierarchy` on the backdrop view
    /// yields the composited content; on iOS 26+ where `drawHierarchy` returns
    /// blank, `layer.render(in:)` reads the model tree directly.
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
        private var backgroundObserver: NSObjectProtocol?
        private var foregroundObserver: NSObjectProtocol?
        private var isPaused = false
        private var bridge: ZeroCopyTextureBridge?
        private var captureView: BackdropCaptureView?
        private var captureViewHasRendered = false
        private var isCapturing = false

        init() {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.pauseDisplayLink()
                }
            }
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.resumeDisplayLink()
                }
            }
        }

        // MARK: - Override Point

        /// Called with the captured `MTLTexture` each frame. Subclasses must override
        /// to route the texture to their rendering pipeline.
        func processTexture(_ texture: MTLTexture) {
            // Subclasses override
        }

        // MARK: - BackdropCaptureView Management

        /// Inserts or updates the `BackdropCaptureView` as a sibling below the effect view.
        private func ensureCaptureView() {
            guard let effectView, let superview = effectView.superview else { return }

            if captureView == nil {
                let view = BackdropCaptureView()
                // Use reduced bit depth when capturing at less than full scale
                if captureScale < 1.0 {
                    view.setReducedBitDepth(true)
                }
                // Forward the capture scale to the backdrop layer
                view.setCaptureScale(captureScale)
                captureView = view
                captureViewHasRendered = false
            }

            guard let captureView else { return }

            if captureView.superview !== superview {
                captureView.removeFromSuperview()
                // Insert below the effect view so it captures everything behind it
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
            let link = CADisplayLink(target: self, selector: #selector(displayLinkFired))
            applyFrameRate(to: link)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
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

        @objc private func displayLinkFired(_ link: CADisplayLink) {
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

            guard let effectView else { return }

            ensureCaptureView()
            guard let captureView else { return }

            let screenScale = effectView.displayScale
            let scale = screenScale * captureScale

            let pixelWidth = Int(captureView.bounds.width * scale)
            let pixelHeight = Int(captureView.bounds.height * scale)
            guard pixelWidth > 0, pixelHeight > 0 else { return }

            ensureBridge()

            if let texture = bridge?.render(width: pixelWidth, height: pixelHeight, actions: { ctx in
                ctx.saveGState()
                ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
                ctx.scaleBy(x: 1, y: -1)
                ctx.scaleBy(x: scale, y: scale)

                if #available(iOS 26, *) {
                    // On iOS 26, CABackdropLayer no longer composites captured content
                    // into the drawable for drawHierarchy. layer.render(in:) reads the
                    // model tree directly, bypassing the broken drawable path.
                    captureView.layer.render(in: ctx)
                } else {
                    let needsScreenUpdate = !self.captureViewHasRendered
                    UIGraphicsPushContext(ctx)
                    captureView.drawHierarchy(in: captureView.bounds, afterScreenUpdates: needsScreenUpdate)
                    UIGraphicsPopContext()
                    self.captureViewHasRendered = true
                }

                ctx.restoreGState()
            }) {
                processTexture(texture)
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
    }
#endif
