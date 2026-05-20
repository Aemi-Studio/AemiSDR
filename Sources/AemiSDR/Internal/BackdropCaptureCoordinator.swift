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
    ///
    /// ## Why CPU-side rasterization, not a Metal render pass
    ///
    /// The capture has to traverse a SwiftUI / UIKit view hierarchy that the
    /// renderer doesn't own. `drawHierarchy(in:afterScreenUpdates:)` is the
    /// only API that does this faithfully — Metal can't directly render a
    /// UIView. The output lands in an IOSurface-backed `CVPixelBuffer` (see
    /// `ZeroCopyTextureBridge`), which Metal samples as a zero-copy
    /// `CVMetalTexture`. No CPU→GPU memcpy occurs; the GPU reads the same
    /// physical pages the CPU wrote.
    ///
    /// This means tile-memory tricks (`MTLStorageMode.memoryless`,
    /// programmable blending tile reads) don't apply to the captured
    /// texture — it must live in shared memory to survive the CPU→GPU
    /// handoff. The downstream lens render is a single Metal pass over this
    /// texture, which is the minimal possible work for the given input.
    @MainActor
    class BackdropCaptureCoordinator {
        /// The effect view this coordinator manages capture for.
        /// Set by the owning `UIViewRepresentable`.
        weak var effectView: UIView?

        var hasCaptured = false
        var continuousCapture = false
        var refreshRate: Int = 30
        var captureScale: CGFloat = 1.0
        /// When true, bypass the `ContentSignature` skip and rasterize every
        /// frame. Used for backdrops whose pixels change without restructuring
        /// the view tree (e.g. animated text).
        var forceCaptureEveryFrame: Bool = false

        private var displayLink: CADisplayLink?
        private var displayLinkProxy: DisplayLinkProxy?
        private var backgroundObserver: NSObjectProtocol?
        private var foregroundObserver: NSObjectProtocol?
        private var reduceMotionObserver: NSObjectProtocol?
        private var lowPowerObserver: NSObjectProtocol?
        private var thermalObserver: NSObjectProtocol?
        /// User-initiated pause — `true` while the app is backgrounded. Set by
        /// `pauseDisplayLink` / `resumeDisplayLink` only. Kept separate from
        /// `systemPaused` so a reduce-motion / thermal pause that fires while
        /// the app is backgrounded doesn't strand the link in the paused state
        /// after the app foregrounds.
        private var userPaused = false
        /// System-state pause — `true` when `effectiveRefreshRate` resolves to 0
        /// (reduce-motion enabled or thermal `.critical`). Recomputed every
        /// time `applyFrameRate` runs.
        private var systemPaused = false
        private var bridge: ZeroCopyTextureBridge?
        private var bridgeConsumerID: BridgeConsumerID?
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

        // Cached results of the superview-walk performed every capture frame.
        // Both `findContentSibling` and `resolveBackgroundColor` walk up the
        // SwiftUI host hierarchy (10-30 levels typical) on every display-link
        // tick — at 120Hz that's thousands of subview reads/second. Cache the
        // resolved sibling and the resolved background CGColor; invalidate
        // explicitly when the hierarchy or appearance changes.
        private weak var cachedContentSibling: UIView?
        private var cachedBackgroundColor: CGColor?

        /// Bumped whenever the effect view's superview chain or trait
        /// collection may have changed. Capture path consults this before
        /// reusing cached sibling/background.
        func invalidateContentLookupCaches() {
            cachedContentSibling = nil
            cachedBackgroundColor = nil
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
            // System-state observers: each just bumps the display-link rate via
            // `updateDisplayLinkRate`, which reads `effectiveRefreshRate`.
            // `UIAccessibility.reduceMotionStatusDidChangeNotification` is
            // annotated `@unsafe` on iOS 26 SDK (it isn't on every SDK), so
            // wrap the assignment expression accordingly.
            reduceMotionObserver = unsafe NotificationCenter.default.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateDisplayLinkRate()
                }
            }
            lowPowerObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name.NSProcessInfoPowerStateDidChange,
                object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateDisplayLinkRate()
                }
            }
            thermalObserver = NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateDisplayLinkRate()
                }
            }
        }

        // MARK: - Effective Refresh Rate

        /// The frame rate the display link should actually run at, derived from
        /// the configured `refreshRate` plus system state:
        /// - Reduce Motion → 0 (paused; one initial capture only)
        /// - Thermal `.critical` → 0 (paused)
        /// - Thermal `.serious` → 30
        /// - Low Power Mode → 30 (cap)
        ///
        /// Returns 0 to signal "fully pause"; otherwise an fps value bounded
        /// by `refreshRate`.
        private var effectiveRefreshRate: Int {
            // `UIAccessibility.isReduceMotionEnabled` is `@unsafe`-annotated on
            // iOS 26 SDK because it can be queried from any thread; we're on
            // MainActor here, where the read is safe.
            if unsafe UIAccessibility.isReduceMotionEnabled { return 0 }
            let thermal = ProcessInfo.processInfo.thermalState
            if thermal == .critical { return 0 }
            var cap = refreshRate
            if thermal == .serious { cap = min(cap, 30) }
            if ProcessInfo.processInfo.isLowPowerModeEnabled { cap = min(cap, 30) }
            return max(0, cap)
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
            // ObjC API; the proxy is `@MainActor` and the link is added to the
            // main run loop below, so the selector dispatch always lands on
            // main. No `unsafe` needed under the iOS 26 SDK annotations.
            let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
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
            let fps = effectiveRefreshRate
            // `systemPaused` is a derived flag: it's true exactly when the
            // accessibility/thermal/lowPower state resolves to 0 fps. The
            // effective pause-state is `userPaused || systemPaused`, so the
            // user-paused branch (background) and system-paused branch
            // (reduce-motion, thermal `.critical`) can coexist without one
            // wiping the other.
            systemPaused = (fps <= 0)
            link.isPaused = userPaused || systemPaused
            guard fps > 0 else { return }
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
            userPaused = true
            displayLink?.isPaused = true
        }

        private func resumeDisplayLink() {
            guard continuousCapture else { return }
            userPaused = false
            // Only un-pause if the system state also permits it. A pending
            // reduce-motion / thermal-critical pause must keep the link
            // suspended even though the user-pause has cleared.
            displayLink?.isPaused = systemPaused
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
            guard let contentView = cachedOrResolvedContentSibling(for: effectView) else { return }

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
            if !forceCaptureEveryFrame {
                let signature = ContentSignature(
                    bounds: contentView.bounds,
                    subviewCount: contentView.subviews.count,
                    sublayerCount: contentView.layer.sublayers?.count ?? 0,
                    contentsIdentifier: contentView.layer.contents.map { ObjectIdentifier($0 as AnyObject) }
                )
                if signature == lastContentSignature && hasCaptured { return }
                lastContentSignature = signature
            }

            ensureBridge(width: pixelWidth, height: pixelHeight)
            guard let bridge, let consumerID = bridgeConsumerID else { return }

            let bgColor = cachedOrResolvedBackgroundColor(for: contentView)

            let captured = bridge.render(
                consumer: consumerID,
                width: pixelWidth,
                height: pixelHeight
            ) { ctx in
                ctx.saveGState()
                // Pre-fill with the resolved sibling background so regions
                // the captured view doesn't paint over (gaps between cards,
                // window system background, etc.) carry an opaque base
                // colour. Without this, transparent capture pixels make the
                // lens output transparent, and the un-refracted scene
                // beneath the lens shows through, doubling the content.
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
            }
            if let captured {
                processTexture(captured)
            }
        }

        /// Returns the cached content sibling if still valid, otherwise resolves
        /// via the superview walk. Cache validity is verified cheaply:
        /// - the cached sibling is still in the same window as the effect view
        /// - the effect view is not a descendant of the cached sibling
        ///   (i.e. the hierarchy hasn't been restructured to nest us under it)
        private func cachedOrResolvedContentSibling(for effectView: UIView) -> UIView? {
            if let cached = cachedContentSibling,
                cached.window === effectView.window,
                !effectView.isDescendant(of: cached),
                cached.superview != nil
            {
                return cached
            }
            let resolved = findContentSibling(for: effectView)
            cachedContentSibling = resolved
            // Background colour is hierarchy-dependent; invalidate it too.
            cachedBackgroundColor = nil
            return resolved
        }

        /// Returns the cached background CGColor if available, otherwise
        /// walks the hierarchy. The trait-collection-aware resolution
        /// happens once per (sibling, traitCollection) pair; the caller
        /// should call `invalidateContentLookupCaches()` on
        /// `traitCollectionDidChange`.
        private func cachedOrResolvedBackgroundColor(for view: UIView) -> CGColor {
            if let cached = cachedBackgroundColor { return cached }
            let resolved = resolveBackgroundColor(for: view, traitCollection: view.traitCollection)
            cachedBackgroundColor = resolved
            return resolved
        }

        /// Walks the view hierarchy to find the first non-clear background
        /// colour. Resolves dynamic colours against the captured view's
        /// trait collection so the fill reflects the current dark/light
        /// appearance rather than the caller's environment.
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

        /// Finds the content sibling view in a SwiftUI background/overlay container.
        ///
        /// SwiftUI `.background`/`.overlay` creates a container with the content view
        /// as the first child and the modifier view(s) as subsequent children. By
        /// capturing only the content sibling, we avoid a feedback loop where the
        /// effect's output is re-captured as input.
        ///
        /// Fallback strategy: if no sibling at any level satisfies the
        /// non-descendant predicate, return the closest parent that has
        /// multiple subviews. This can technically include the effect view's
        /// subtree (theoretical feedback loop), but in practice produces a
        /// usable capture; returning nil leaves the lens blank.
        private func findContentSibling(for view: UIView) -> UIView? {
            var fallback: UIView?
            var current = view.superview
            while let parent = current {
                if parent.subviews.count >= 2 {
                    if fallback == nil { fallback = parent }
                    for sibling in parent.subviews where !view.isDescendant(of: sibling) {
                        return sibling
                    }
                }
                current = parent.superview
            }
            return fallback
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

            ensureBridge(width: pixelWidth, height: pixelHeight)
            guard let bridge, let consumerID = bridgeConsumerID else { return }

            if let captured = bridge.render(
                consumer: consumerID, width: pixelWidth, height: pixelHeight,
                actions: { ctx in
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
                })
            {
                processTexture(captured)
            }
        }

        // MARK: - Bridge

        /// The captured dimensions this coordinator most recently rendered at.
        /// Used to size-bucket the pooled bridge.
        private var bridgeWidth: Int = 0
        private var bridgeHeight: Int = 0

        /// Lazily acquires (or rebuckets) a pooled bridge sized for the given
        /// capture dimensions. Subsequent calls with similar dimensions reuse
        /// the same physical IOSurface ring; consumers with different
        /// dimensions sit in different buckets.
        private func ensureBridge(width: Int, height: Int) {
            guard let effectView else { return }
            let device: MTLDevice?
            if let metalLayer = effectView.layer as? CAMetalLayer {
                device = metalLayer.device
            } else {
                device = MTLCreateSystemDefaultDevice()
            }
            guard let device else { return }

            // Same bucket as last time — reuse current bridge handle.
            if let existing = bridge, width == bridgeWidth, height == bridgeHeight {
                _ = existing
                return
            }

            // Dimensions changed (or first call): unregister from the old
            // bridge, acquire one from the pool for the new bucket, register.
            if let oldBridge = bridge, let oldID = bridgeConsumerID {
                oldBridge.unregister(oldID)
            }
            let pooled = ZeroCopyTextureBridgePool.bridge(for: device, width: width, height: height)
            bridge = pooled
            bridgeConsumerID = pooled.register()
            bridgeWidth = width
            bridgeHeight = height
        }

        // MARK: - Cleanup

        func tearDown() {
            stopDisplayLink()
            removeCaptureView()
            // Release this coordinator's slot bookkeeping from the pooled bridge
            // so other consumers of the same bucket don't pay for our stale
            // in-flight set.
            if let bridge, let id = bridgeConsumerID {
                bridge.unregister(id)
            }
            bridge = nil
            bridgeConsumerID = nil
            if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
            if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
            if let reduceMotionObserver { NotificationCenter.default.removeObserver(reduceMotionObserver) }
            if let lowPowerObserver { NotificationCenter.default.removeObserver(lowPowerObserver) }
            if let thermalObserver { NotificationCenter.default.removeObserver(thermalObserver) }
            backgroundObserver = nil
            foregroundObserver = nil
            reduceMotionObserver = nil
            lowPowerObserver = nil
            thermalObserver = nil
        }

        // No explicit deinit: cleanup runs from `tearDown()` which SwiftUI
        // invokes via `dismantleUIView`. The previous `isolated deinit`
        // (SE-0371) appears to interact badly with the iOS 26.5 simulator
        // runtime — XCPreviewAgent SIGABRTs ~12 s into module load when this
        // class is touched, likely due to incomplete type-metadata support
        // for isolated deinit in JIT'd preview frameworks.
        //
        // The audit's M4 concern (missed dismantleUIView → leaked display
        // link + observer tokens) is bounded: each leak is one CADisplayLink
        // and five NSObserver tokens, only when SwiftUI replaces a
        // representable mid-flight without dismantling it (rare). Documented
        // residual risk rather than blocking previews.
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
