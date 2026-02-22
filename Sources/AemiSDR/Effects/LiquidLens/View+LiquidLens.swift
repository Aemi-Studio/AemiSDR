//
//  View+LiquidLens.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI

    extension View {

        // MARK: - Auto-capture (continuous)

        /// Applies a physics-based liquid lens distortion effect that automatically
        /// captures the view's content as the source texture.
        ///
        /// Uses a UIKit view-hierarchy snapshot to capture the content and renders
        /// the distorted version as a transparent overlay. When `continuousCapture`
        /// is `true` (the default), a `CADisplayLink` re-captures at `refreshRate` fps,
        /// keeping the lens in sync with background changes.
        ///
        /// - Parameters:
        ///   - clipShape: Optional shape path provider to mask the overlay to match the
        ///     parent view's clip shape. Use ``LiquidLensClipShape`` helpers or pass a closure.
        ///   - continuousCapture: When `true`, continuously re-snapshots the background.
        ///   - refreshRate: Target frames per second for continuous capture (1–120, default 30).
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquidLens(
            center: SIMD2<Float> = .zero,
            halfSize: SIMD2<Float> = SIMD2(150, 150),
            strength: Float = 1.0,
            lensCurvature: Float = 0.5,
            cornerRadius: LiquidLensCornerRadius = .points(0),
            falloff: LiquidLensFalloff = .easeInOut,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 0.5,
            chromaticAmount: Float = 1.0,
            material: LiquidLensMaterial = .crownGlass,
            useRadialDirection: Bool = true,
            clipShape: ShapePathProvider? = nil,
            continuousCapture: Bool = true,
            refreshRate: Int = 30,
            captureScale: CGFloat = 1.0
        ) -> some View {
            overlay {
                _LiquidLensOverlay(
                    configuration: LiquidLensConfiguration(
                        center: center,
                        halfSize: halfSize,
                        strength: strength,
                        lensCurvature: lensCurvature,
                        cornerRadius: cornerRadius,
                        falloff: falloff,
                        falloffLength: falloffLength,
                        falloffIntensity: falloffIntensity,
                        chromaticAmount: chromaticAmount,
                        material: material,
                        useRadialDirection: useRadialDirection,
                        overlayMode: true
                    ),
                    clipShapePath: clipShape,
                    continuousCapture: continuousCapture,
                    refreshRate: max(1, min(refreshRate, 120)),
                    captureScale: max(0.25, min(captureScale, 3.0))
                )
                .allowsHitTesting(false)
            }
        }

        /// Auto-capture overload that accepts a SwiftUI `Shape` for clip masking.
        @available(iOS 16.0, *)
        @ViewBuilder
        public func liquidLens<S: Shape>(
            center: SIMD2<Float> = .zero,
            halfSize: SIMD2<Float> = SIMD2(150, 150),
            strength: Float = 1.0,
            lensCurvature: Float = 0.5,
            cornerRadius: LiquidLensCornerRadius = .points(0),
            falloff: LiquidLensFalloff = .easeInOut,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 0.5,
            chromaticAmount: Float = 1.0,
            material: LiquidLensMaterial = .crownGlass,
            useRadialDirection: Bool = true,
            clipShape shape: S,
            continuousCapture: Bool = true,
            refreshRate: Int = 30,
            captureScale: CGFloat = 1.0
        ) -> some View {
            liquidLens(
                center: center,
                halfSize: halfSize,
                strength: strength,
                lensCurvature: lensCurvature,
                cornerRadius: cornerRadius,
                falloff: falloff,
                falloffLength: falloffLength,
                falloffIntensity: falloffIntensity,
                chromaticAmount: chromaticAmount,
                material: material,
                useRadialDirection: useRadialDirection,
                clipShape: { rect in shape.path(in: rect).cgPath },
                continuousCapture: continuousCapture,
                refreshRate: refreshRate,
                captureScale: captureScale
            )
        }

        // MARK: - Explicit image

        /// Applies a physics-based liquid lens distortion effect using an explicit source image.
        ///
        /// Use this overload when you have a pre-rendered image to distort, or when
        /// you want manual control over the source texture.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func liquidLens(
            image: UIImage,
            center: SIMD2<Float> = .zero,
            halfSize: SIMD2<Float> = SIMD2(150, 150),
            strength: Float = 1.0,
            lensCurvature: Float = 0.5,
            cornerRadius: LiquidLensCornerRadius = .points(0),
            falloff: LiquidLensFalloff = .easeInOut,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 0.5,
            chromaticAmount: Float = 1.0,
            material: LiquidLensMaterial = .crownGlass,
            useRadialDirection: Bool = true,
            clipShape: ShapePathProvider? = nil
        ) -> some View {
            overlay {
                LiquidLensView(
                    image: image,
                    configuration: LiquidLensConfiguration(
                        center: center,
                        halfSize: halfSize,
                        strength: strength,
                        lensCurvature: lensCurvature,
                        cornerRadius: cornerRadius,
                        falloff: falloff,
                        falloffLength: falloffLength,
                        falloffIntensity: falloffIntensity,
                        chromaticAmount: chromaticAmount,
                        material: material,
                        useRadialDirection: useRadialDirection
                    ),
                    clipShapePath: clipShape
                )
                .allowsHitTesting(false)
            }
        }

        /// Explicit image overload that accepts a SwiftUI `Shape` for clip masking.
        @available(iOS 16.0, *)
        @ViewBuilder
        public func liquidLens<S: Shape>(
            image: UIImage,
            center: SIMD2<Float> = .zero,
            halfSize: SIMD2<Float> = SIMD2(150, 150),
            strength: Float = 1.0,
            lensCurvature: Float = 0.5,
            cornerRadius: LiquidLensCornerRadius = .points(0),
            falloff: LiquidLensFalloff = .easeInOut,
            falloffLength: Float = 1.0,
            falloffIntensity: Float = 0.5,
            chromaticAmount: Float = 1.0,
            material: LiquidLensMaterial = .crownGlass,
            useRadialDirection: Bool = true,
            clipShape shape: S
        ) -> some View {
            liquidLens(
                image: image,
                center: center,
                halfSize: halfSize,
                strength: strength,
                lensCurvature: lensCurvature,
                cornerRadius: cornerRadius,
                falloff: falloff,
                falloffLength: falloffLength,
                falloffIntensity: falloffIntensity,
                chromaticAmount: chromaticAmount,
                material: material,
                useRadialDirection: useRadialDirection,
                clipShape: { rect in shape.path(in: rect).cgPath }
            )
        }
    }

    // MARK: - Auto-capture Overlay

    /// UIViewRepresentable that captures its parent content view's appearance
    /// and renders the liquid lens distortion as a transparent overlay.
    ///
    /// Supports continuous capture via `CADisplayLink` with a low-resolution dirty
    /// check to skip unchanged frames. Auto-pauses when off-screen or backgrounded.
    struct _LiquidLensOverlay: UIViewRepresentable {

        var configuration: LiquidLensConfiguration
        var clipShapePath: ShapePathProvider?
        var continuousCapture: Bool
        var refreshRate: Int
        var captureScale: CGFloat = 1.0

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeUIView(context: Context) -> LiquidLensUIView {
            let view = LiquidLensUIView(configuration: configuration)
            view.clipShapePath = clipShapePath
            context.coordinator.lensView = view
            context.coordinator.clipShapePath = clipShapePath
            context.coordinator.continuousCapture = continuousCapture
            context.coordinator.refreshRate = refreshRate
            context.coordinator.captureScale = captureScale

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                context.coordinator.captureOnce()
                if continuousCapture {
                    context.coordinator.startDisplayLink()
                }
            }
            return view
        }

        func updateUIView(_ uiView: LiquidLensUIView, context: Context) {
            let configChanged = context.coordinator.lastConfiguration != configuration
            uiView.updateConfiguration(configuration)
            uiView.clipShapePath = clipShapePath
            context.coordinator.lastConfiguration = configuration
            context.coordinator.clipShapePath = clipShapePath

            // Update continuous capture settings
            let wasCapturing = context.coordinator.continuousCapture
            context.coordinator.continuousCapture = continuousCapture
            context.coordinator.refreshRate = refreshRate
            context.coordinator.captureScale = captureScale

            if continuousCapture && !wasCapturing {
                context.coordinator.startDisplayLink()
            } else if !continuousCapture && wasCapturing {
                context.coordinator.stopDisplayLink()
            } else if continuousCapture {
                context.coordinator.updateDisplayLinkRate()
            }

            if configChanged || !context.coordinator.hasCaptured {
                DispatchQueue.main.async {
                    context.coordinator.captureOnce()
                }
            }
        }

        static func dismantleUIView(_: LiquidLensUIView, coordinator: Coordinator) {
            coordinator.tearDown()
        }

        @MainActor
        final class Coordinator {
            weak var lensView: LiquidLensUIView?
            var lastConfiguration: LiquidLensConfiguration?
            var clipShapePath: ShapePathProvider?
            var hasCaptured = false
            var continuousCapture = false
            var refreshRate: Int = 30
            var captureScale: CGFloat = 1.0

            private nonisolated(unsafe) var displayLink: CADisplayLink?
            private nonisolated(unsafe) var backgroundObserver: NSObjectProtocol?
            private nonisolated(unsafe) var foregroundObserver: NSObjectProtocol?
            private var isPaused = false
            private var bridge: ZeroCopyTextureBridge?

            init() {
                backgroundObserver = NotificationCenter.default.addObserver(
                    forName: UIApplication.didEnterBackgroundNotification,
                    object: nil, queue: .main
                ) { [weak self] _ in
                    self?.pauseDisplayLink()
                }
                foregroundObserver = NotificationCenter.default.addObserver(
                    forName: UIApplication.willEnterForegroundNotification,
                    object: nil, queue: .main
                ) { [weak self] _ in
                    self?.resumeDisplayLink()
                }
            }

            deinit {
                if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
                if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
                displayLink?.invalidate()
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
                let fps = max(1, min(refreshRate, 120))
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
                guard let lensView, lensView.window != nil else { return }
                guard lensView.bounds.width > 0, lensView.bounds.height > 0 else { return }
                guard let contentView = findContentView(for: lensView) else { return }
                performCapture(lensView: lensView, contentView: contentView)
            }

            // MARK: - Capture

            /// Performs a single capture (used for initial load and config changes).
            func captureOnce() {
                guard let lensView else { return }
                guard lensView.bounds.width > 0, lensView.bounds.height > 0 else { return }
                guard lensView.window != nil else { return }
                guard let contentView = findContentView(for: lensView) else { return }

                performCapture(lensView: lensView, contentView: contentView)
                hasCaptured = true
            }

            private func performCapture(lensView: LiquidLensUIView, contentView: UIView) {
                let screenScale = lensView.window?.screen.scale ?? UIScreen.main.scale
                let scale = screenScale * captureScale
                let frameInContent = lensView.convert(lensView.bounds, to: contentView)

                let pixelWidth = Int(frameInContent.width * scale)
                let pixelHeight = Int(frameInContent.height * scale)
                guard pixelWidth > 0, pixelHeight > 0 else { return }

                // Lazily create the bridge on first capture
                if bridge == nil, let device = (lensView.layer as? CAMetalLayer)?.device {
                    bridge = ZeroCopyTextureBridge(device: device)
                }

                // Resolve the background color visible behind the content view.
                // SwiftUI views typically have transparent backgrounds; the visible
                // background comes from the window or a host view deeper in the hierarchy.
                // Pre-filling prevents transparent areas from appearing black through the lens.
                let bgColor = resolveBackgroundColor(for: contentView)

                if let texture = bridge?.render(width: pixelWidth, height: pixelHeight, actions: { ctx in
                    ctx.saveGState()
                    // Fill with the resolved background first
                    ctx.setFillColor(bgColor)
                    ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
                    // Flip Quartz (bottom-left origin) → UIKit (top-left origin)
                    ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
                    ctx.scaleBy(x: 1, y: -1)
                    // Scale from pixels to points
                    ctx.scaleBy(x: scale, y: scale)
                    // Offset to capture the lens view's portion of the content
                    ctx.translateBy(x: -frameInContent.origin.x, y: -frameInContent.origin.y)
                    // drawHierarchy is fast — captures only the content sibling, no hide/unhide needed
                    UIGraphicsPushContext(ctx)
                    contentView.drawHierarchy(in: contentView.bounds, afterScreenUpdates: false)
                    UIGraphicsPopContext()
                    ctx.restoreGState()
                }) {
                    lensView.setSourceTexture(texture)
                } else {
                    // Fallback to UIGraphicsImageRenderer
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = scale
                    format.opaque = true
                    let captureSize = CGSize(
                        width: frameInContent.width,
                        height: frameInContent.height
                    )
                    let renderer = UIGraphicsImageRenderer(size: captureSize, format: format)
                    let image = renderer.image { ctx in
                        ctx.cgContext.setFillColor(bgColor)
                        ctx.cgContext.fill(CGRect(origin: .zero, size: captureSize))
                        ctx.cgContext.translateBy(x: -frameInContent.origin.x, y: -frameInContent.origin.y)
                        contentView.drawHierarchy(in: contentView.bounds, afterScreenUpdates: false)
                    }
                    lensView.setSourceImage(image)
                }
            }

            // MARK: - Helpers

            /// Walks the view hierarchy to find the first non-clear, non-nil background color.
            /// Falls back to `UIColor.systemBackground` if no explicit background is found.
            private func resolveBackgroundColor(for view: UIView) -> CGColor {
                var current: UIView? = view
                while let v = current {
                    if let bg = v.backgroundColor, bg != .clear {
                        return bg.cgColor
                    }
                    current = v.superview
                }
                return UIColor.systemBackground.cgColor
            }

            /// Finds the content sibling view in a SwiftUI overlay container.
            ///
            /// SwiftUI overlays create a container with the content view as the first child
            /// and the overlay view(s) as subsequent children. By capturing only the content
            /// sibling (not the full container), we avoid a feedback loop where the lens
            /// distortion output is re-captured as input.
            private func findContentView(for lensView: UIView) -> UIView? {
                var current = lensView.superview
                while let parent = current {
                    if parent.subviews.count >= 2 {
                        // The content view is the sibling that does not contain the lens
                        for sibling in parent.subviews where !lensView.isDescendant(of: sibling) {
                            return sibling
                        }
                        return parent
                    }
                    current = parent.superview
                }
                return nil
            }

            // MARK: - Cleanup

            func tearDown() {
                stopDisplayLink()
            }
        }
    }
#endif
