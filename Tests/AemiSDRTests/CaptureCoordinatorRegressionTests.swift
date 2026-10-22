#if os(iOS)
    import Metal
    import QuartzCore
    import Testing
    import UIKit

    @testable import AemiSDR

    @MainActor
    @Suite("Capture retry and foreground lifecycle", .serialized)
    struct CaptureCoordinatorRegressionTests {
        @Test(arguments: [false, true])
        func `foregrounding before continuous capture is enabled does not strand a later display link`(
            wasContinuous: Bool
        ) throws {
            var scheduled: CADisplayLink?
            let coordinator = BackdropCaptureCoordinator(
                makeDisplayLink: { proxy in
                    let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
                    scheduled = link
                    return link
                }, refreshRatePolicy: { _ in 30 })
            defer { coordinator.tearDown() }
            coordinator.continuousCapture = wasContinuous
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            coordinator.continuousCapture = true
            coordinator.startDisplayLink()
            let link = try #require(scheduled)
            #expect(!link.isPaused)
            #expect(link.preferredFrameRateRange.preferred == 30)
        }

        @available(iOS 26.0, *)
        @Test func `a first capture without a Metal device does not mark the source as captured`() throws {
            let effect = DevicePendingView(frame: CGRect(x: 10, y: 12, width: 37, height: 29))
            let fixture = CaptureFixture(effect: effect)
            let coordinator = RecordingCaptureCoordinator()
            coordinator.effectView = effect
            defer {
                coordinator.consumeAll()
                coordinator.tearDown()
                fixture.window.isHidden = true
            }
            try #require(effect.window != nil)
            try #require((effect.layer as? CAMetalLayer)?.device == nil)
            coordinator.captureOnce()
            #expect(coordinator.delivered == 0)
            #expect(!coordinator.hasCaptured)
        }

        @available(iOS 26.0, *)
        @Test func `a capture dropped because every slot is held is retried when a slot becomes available`() throws {
            _ = try #require(MTLCreateSystemDefaultDevice())
            let effect = UIView(frame: CGRect(x: 10, y: 12, width: 37, height: 29))
            let fixture = CaptureFixture(effect: effect)
            let source = fixture.source
            let coordinator = RecordingCaptureCoordinator()
            coordinator.effectView = effect
            defer {
                coordinator.consumeAll()
                coordinator.tearDown()
                fixture.window.isHidden = true
            }
            try #require(effect.window != nil)
            coordinator.captureOnce()
            try #require(coordinator.delivered == 1)
            coordinator.forceCaptureEveryFrame = true
            coordinator.captureOnce()
            coordinator.captureOnce()
            try #require(coordinator.delivered == 3)
            coordinator.forceCaptureEveryFrame = false
            let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
                UIColor.blue.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            }
            source.layer.contents = image.cgImage
            coordinator.captureOnce()
            #expect(coordinator.delivered == 3, "the exhausted ring must drop this attempt")
            coordinator.consumeFirst()
            coordinator.captureOnce()
            #expect(coordinator.delivered == 4, "a failed attempt must not cache a successful content signature")
            withExtendedLifetime(fixture.window) {}
        }
    }

    @MainActor
    private struct CaptureFixture {
        let window: UIWindow
        let source: UIView

        init(effect: UIView) {
            if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
                window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 160, height: 140)
            } else {
                window = UIWindow(frame: CGRect(x: 0, y: 0, width: 160, height: 140))
            }
            let controller = UIViewController()
            window.rootViewController = controller
            controller.view.frame = window.bounds
            source = UIView(frame: controller.view.bounds)
            source.backgroundColor = .red
            controller.view.addSubview(source)
            controller.view.addSubview(effect)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
    }

    @MainActor
    private final class DevicePendingView: UIView {
        override class var layerClass: AnyClass { DevicePendingLayer.self }
    }

    /// The simulator eagerly supplies a default device; this stand-in models a surface still awaiting its renderer.
    private final class DevicePendingLayer: CAMetalLayer {
        override var device: MTLDevice? {
            get { nil }
            set {
                // Keep the device unavailable while testing initial-capture retry.
            }
        }
    }

    @MainActor
    private final class RecordingCaptureCoordinator: BackdropCaptureCoordinator {
        private var held: [ConsumableTexture] = []
        private(set) var delivered = 0

        override func processTexture(_ captured: ConsumableTexture) {
            delivered += 1
            held.append(captured)
        }

        func consumeFirst() { held.removeFirst().onConsumed() }

        func consumeAll() {
            let captures = held
            held.removeAll()
            for capture in captures { capture.onConsumed() }
        }
    }
#endif
