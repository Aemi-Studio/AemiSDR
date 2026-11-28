import SwiftUI

/// The host of the live luma check (ADR-0010): a scene on screen, nothing else.
@main
struct LumaCheckApp: App {
    var body: some Scene {
        WindowGroup { Color.white.ignoresSafeArea() }
    }
}
