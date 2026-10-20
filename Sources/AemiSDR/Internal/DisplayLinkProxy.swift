#if os(iOS)
    import UIKit

    /// Weak forwarding target for `CADisplayLink`.
    ///
    /// `CADisplayLink` retains its `target` strongly. When the coordinator is
    /// the direct target, missing a `tearDown()` keeps the coordinator alive
    /// indefinitely and the display link keeps firing. Routing through this
    /// proxy means the link retains the proxy (cheap, no observers) while the
    /// coordinator may deallocate normally.
    @MainActor
    final class DisplayLinkProxy: NSObject {
        weak var target: BackdropCaptureCoordinator?

        init(target: BackdropCaptureCoordinator) {
            self.target = target
        }

        @objc func fire(_ link: CADisplayLink) {
            guard let target else {
                link.invalidate()
                return
            }
            target.displayLinkFired(link)
        }
    }

#endif
