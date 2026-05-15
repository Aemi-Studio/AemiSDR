//
//  _LiquidLensOverlay.swift
//  AemiSDR
//

#if os(iOS)
    import QuartzCore
    import SwiftUI
    import UIKit

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
        var forceCaptureEveryFrame: Bool = false

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeUIView(context: Context) -> LiquidLensUIView {
            let view = LiquidLensUIView(configuration: configuration)
            view.clipShapePath = clipShapePath
            context.coordinator.effectView = view
            context.coordinator.clipShapePath = clipShapePath
            context.coordinator.continuousCapture = continuousCapture
            context.coordinator.refreshRate = refreshRate
            context.coordinator.captureScale = captureScale
            context.coordinator.forceCaptureEveryFrame = forceCaptureEveryFrame

            // Trigger the initial capture from the UIView's lifecycle once it
            // has a window and a non-zero size. Avoids the previous
            // `asyncAfter(0.1)` timing hack which popped on fast devices and
            // misaligned on slow ones.
            let shouldStartContinuous = continuousCapture
            view.onReadyForFirstCapture = { [weak coordinator = context.coordinator] in
                coordinator?.captureOnce()
                if shouldStartContinuous {
                    coordinator?.startDisplayLink()
                }
            }
            view.onContentHierarchyChanged = { [weak coordinator = context.coordinator] in
                coordinator?.invalidateContentLookupCaches()
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
            context.coordinator.forceCaptureEveryFrame = forceCaptureEveryFrame

            if continuousCapture && !wasCapturing {
                context.coordinator.startDisplayLink()
            } else if !continuousCapture && wasCapturing {
                context.coordinator.stopDisplayLink()
            } else if continuousCapture {
                context.coordinator.updateDisplayLinkRate()
            }

            if configChanged || !context.coordinator.hasCaptured {
                // updateUIView runs on MainActor; capturing directly avoids the
                // one-runloop-tick lag of an async dispatch and prevents a
                // double-fire alongside `onReadyForFirstCapture`.
                context.coordinator.captureOnce()
            }
        }

        static func dismantleUIView(_: LiquidLensUIView, coordinator: Coordinator) {
            coordinator.tearDown()
        }

        @MainActor
        final class Coordinator: BackdropCaptureCoordinator {
            var lastConfiguration: LiquidLensConfiguration?
            var clipShapePath: ShapePathProvider?

            override func processTexture(_ captured: ConsumableTexture) {
                (effectView as? LiquidLensUIView)?.setSourceTexture(
                    captured.texture,
                    onConsumed: captured.onConsumed
                )
            }
        }
    }
#endif
