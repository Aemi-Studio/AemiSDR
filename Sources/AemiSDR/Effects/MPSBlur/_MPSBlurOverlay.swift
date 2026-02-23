//
//  _MPSBlurOverlay.swift
//  AemiSDR
//

#if os(iOS)
    import Metal
    import SwiftUI
    import UIKit

    /// UIViewRepresentable that captures backdrop content via `BackdropCaptureCoordinator`
    /// and renders it with MPS Gaussian blur.
    struct _MPSBlurOverlay: UIViewRepresentable {

        var configuration: MPSBlurConfiguration

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeUIView(context: Context) -> UIView {
            let view = MPSBlurUIView(blurRadius: configuration.blurRadius) ?? UIView()
            context.coordinator.effectView = view
            context.coordinator.continuousCapture = configuration.continuousCapture
            context.coordinator.refreshRate = configuration.clampedRefreshRate
            context.coordinator.captureScale = configuration.clampedCaptureScale

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                context.coordinator.captureOnce()
                if configuration.continuousCapture {
                    context.coordinator.startDisplayLink()
                }
            }
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            let configChanged = context.coordinator.lastConfiguration != configuration

            if let blurView = uiView as? MPSBlurUIView {
                blurView.updateBlurRadius(configuration.blurRadius)
            }

            context.coordinator.lastConfiguration = configuration

            let wasCapturing = context.coordinator.continuousCapture
            context.coordinator.continuousCapture = configuration.continuousCapture
            context.coordinator.refreshRate = configuration.clampedRefreshRate
            context.coordinator.captureScale = configuration.clampedCaptureScale

            if configuration.continuousCapture && !wasCapturing {
                context.coordinator.startDisplayLink()
            } else if !configuration.continuousCapture && wasCapturing {
                context.coordinator.stopDisplayLink()
            } else if configuration.continuousCapture {
                context.coordinator.updateDisplayLinkRate()
            }

            if configChanged || !context.coordinator.hasCaptured {
                DispatchQueue.main.async {
                    context.coordinator.captureOnce()
                }
            }
        }

        static func dismantleUIView(_: UIView, coordinator: Coordinator) {
            coordinator.tearDown()
        }

        @MainActor
        final class Coordinator: BackdropCaptureCoordinator {
            var lastConfiguration: MPSBlurConfiguration?

            override func processTexture(_ texture: MTLTexture) {
                (effectView as? MPSBlurUIView)?.renderBlurred(sourceTexture: texture)
            }
        }
    }
#endif
