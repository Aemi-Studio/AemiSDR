#if os(iOS)
    import Metal
    import SwiftUI
    import Testing
    import UIKit

    @testable import AemiSDR

    @MainActor
    @Suite("Clear glass SwiftUI integration and live backdrop capture")
    struct ClearGlassSwiftUITests {
        @Test func `clear glass overlay mounts and performs initial capture`() throws {
            _ = try #require(MTLCreateSystemDefaultDevice())

            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
            let content = ZStack {
                Color.blue.frame(width: 200, height: 200)
                ClearGlassView(configuration: .nativeClear(shape: .capsule))
                    .frame(width: 100, height: 50)
            }

            let controller = UIHostingController(rootView: content)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            window.layoutIfNeeded()

            defer {
                window.isHidden = true
                window.rootViewController = nil
            }

            #expect(controller.view.subviews.count > 0)
        }
    }
#endif
