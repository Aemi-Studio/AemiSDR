#if os(iOS)
    import QuartzCore
    import SwiftUI
    import UIKit

    /// UIViewRepresentable that captures its parent content view's appearance
    /// and renders clear glass refraction and blur as an overlay.
    struct _ClearGlassOverlay: UIViewRepresentable {
        var configuration: ClearGlassConfiguration
        var continuousCapture: Bool
        var refreshRate: Int
        var captureScale: CGFloat = 1.0
        var forceCaptureEveryFrame: Bool = false

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeUIView(context: Context) -> ClearGlassUIView {
            let view = ClearGlassUIView(configuration: configuration)
            context.coordinator.effectView = view
            context.coordinator.continuousCapture = continuousCapture
            context.coordinator.refreshRate = refreshRate
            context.coordinator.captureScale = captureScale
            context.coordinator.forceCaptureEveryFrame = forceCaptureEveryFrame

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

        func updateUIView(_ uiView: ClearGlassUIView, context: Context) {
            let configChanged = context.coordinator.lastConfiguration != configuration
            uiView.configuration = configuration
            context.coordinator.lastConfiguration = configuration

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

            if configChanged {
                DispatchQueue.main.async {
                    context.coordinator.captureOnce()
                }
            }
        }

        static func dismantleUIView(_: ClearGlassUIView, coordinator: Coordinator) {
            coordinator.tearDown()
        }

        @MainActor
        final class Coordinator: BackdropCaptureCoordinator {
            var lastConfiguration: ClearGlassConfiguration?

            override func processTexture(_ captured: ConsumableTexture) {
                (effectView as? ClearGlassUIView)?.setSourceTexture(
                    captured.texture,
                    onConsumed: captured.onConsumed
                )
            }
        }
    }
#endif
