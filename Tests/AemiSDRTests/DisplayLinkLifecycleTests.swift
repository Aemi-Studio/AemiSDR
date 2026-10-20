#if os(iOS)
    import Testing
    import UIKit

    @testable import AemiSDR

    @MainActor
    @Suite("Display link lifecycle")
    struct DisplayLinkLifecycleTests {
        @Test func `a link with a live owner stays scheduled`() {
            let owner = BackdropCaptureCoordinator()
            weak var observedProxy: DisplayLinkProxy?
            weak var scheduledLink: CADisplayLink?
            autoreleasepool {
                let proxy = DisplayLinkProxy(target: owner)
                observedProxy = proxy
                let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
                scheduledLink = link
                link.add(to: .main, forMode: .common)
                proxy.fire(link)
            }
            #expect(observedProxy != nil)
            scheduledLink?.invalidate()
            withExtendedLifetime(owner) {}
        }

        @Test func `a link whose owner disappeared invalidates itself instead of retaining its forwarding target`()
            throws
        {
            weak var observedProxy: DisplayLinkProxy?
            weak var observedLink: CADisplayLink?
            try autoreleasepool {
                var owner: BackdropCaptureCoordinator? = BackdropCaptureCoordinator()
                let proxy = DisplayLinkProxy(target: try #require(owner))
                observedProxy = proxy
                let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
                observedLink = link
                link.add(to: .main, forMode: .common)
                owner = nil
                #expect(proxy.target == nil)
                proxy.fire(link)
            }
            // The main run loop retains a scheduled link, which retains its target. Releasing both proves that
            // the orphan callback removed the link rather than merely doing nothing on every display tick.
            #expect(observedProxy == nil)
            // Clean up even on the red implementation, so the test never leaves a scheduled orphan behind.
            observedLink?.invalidate()
        }
    }
#endif
