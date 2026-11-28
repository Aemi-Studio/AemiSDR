import AemiSDR
import Testing
import UIKit

/// ADR-0010 on iOS, live: `BackdropLumaUIView` in a window of the host app's scene, its background white, black, white.
@MainActor struct LiveLumaTests {
    @Test(.timeLimit(.minutes(1))) func `readings follow what is behind the view`() async throws {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first, "the host's scene")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        window.windowLevel = .alert
        window.rootViewController = UIViewController()
        let root = try #require(window.rootViewController?.view)
        root.backgroundColor = .white
        let view = BackdropLumaUIView(frame: root.bounds)
        root.addSubview(view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try #require(view.isAvailable)
        var readings: [Double] = []
        view.interval = 0.1
        view.onLuma = { readings.append($0) }
        func paint(_ white: Bool) {
            root.backgroundColor = white ? .white : .black
            CATransaction.flush()
        }
        try await waitFor { readings.last.map { $0 > 0.9 } == true }
        paint(false)
        try await waitFor { readings.last.map { $0 < 0.1 } == true }
        paint(true)
        try await waitFor { readings.last.map { $0 > 0.9 } == true }
        #expect(view.level == .light, "readings \(readings)")
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() { try await Task.sleep(for: .milliseconds(50)) }
        #expect(condition())
    }
}
