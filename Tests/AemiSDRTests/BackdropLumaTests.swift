import Abysm
import QuartzCore
import Testing

@testable import AemiSDR

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// ADR-0010: the luma of what is under a view, from a tracking backdrop. The level's band (pure), the layer made as the
/// probes found it reports (diary 2026-11-28-01), nothing private with the policy off, and, on screen, readings that
/// follow what is behind it.
@MainActor @Suite("Backdrop luma", .serialized) struct BackdropLumaTests {
    @Test func `a luma inside the band keeps the level it had; past it the level changes`() {
        #expect(LumaLevel.after(nil, luma: 0.1) == .dark && LumaLevel.after(nil, luma: 0.9) == .light)
        #expect(LumaLevel.after(nil, luma: 0.45) == .dark && LumaLevel.after(nil, luma: 0.55) == .light)
        #expect(LumaLevel.after(.dark, luma: 0.58) == .dark && LumaLevel.after(.light, luma: 0.42) == .light)
        #expect(LumaLevel.after(.dark, luma: 0.61) == .light && LumaLevel.after(.light, luma: 0.39) == .dark)
        #expect(LumaLevel.after(.light, luma: .nan) == .light)
    }

    @Test func `the layer is made as it reports: enabled, grouped, half scale, one filter, nearly transparent`() throws
    {
        let made = try #require(BackdropLumaLayer.make(groupName: "test") { _ in })
        let object = RuntimeObject(made.layer)
        #expect((try object.value(forKey: "enabled") as? NSNumber)?.boolValue == true)
        #expect((try object.value(forKey: "allowsFilteredLuma") as? NSNumber)?.boolValue == true)
        #expect((try object.value(forKey: "scale") as? NSNumber)?.doubleValue == 0.5)
        #expect(try object.value(forKey: "groupName") as? String == "test")
        #expect(made.layer.filters?.count == 1 && made.layer.opacity == 0.01)
        #expect(made.layer.delegate != nil)
        made.track(true)
        made.setInterval(0.1)
        #expect((try object.value(forKey: "tracksLuma") as? NSNumber)?.boolValue == true)
        #expect((try object.value(forKey: "lumaUpdateRate") as? NSNumber)?.doubleValue == 0.1)
        #if os(macOS)
            #expect((try object.value(forKey: "windowServerAware") as? NSNumber)?.boolValue == true)
        #endif
    }

    @Test func `the delegate answers the renderer's selector, with the system's encoding`() throws {
        let delegate = LumaDelegate { _ in }
        let selector = NSSelectorFromString("backdropLayer:didChangeLuma:")
        #expect(delegate.responds(to: selector))
        let method = try #require(class_getInstanceMethod(LumaDelegate.self, selector))
        #expect(unsafe String(cString: method_getTypeEncoding(method)!) == "v32@0:8@16d24")
    }

    @Test func `with private API off nothing is made`() {
        PrivateAPIPolicy.isEnabled = false
        defer { PrivateAPIPolicy.isEnabled = true }
        #expect(BackdropLumaLayer.make { _ in } == nil)
    }

    @Test func `readings move the level once per crossing`() {
        let sampler = LumaSampler(groupName: nil)
        var levels: [LumaLevel] = []
        sampler.onLevel = { levels.append($0) }
        for luma in [0.9, 0.55, 0.45, 0.1, 0.3, 0.7] { sampler.receive(luma) }
        #expect(levels == [.light, .dark, .light])
        #expect(sampler.luma == 0.7)
    }

    @Test func `filters are made with their inputs on both platforms, unknown keys left unwritten`() throws {
        // iOS's CAFilter has no -inputKeys: before -CAMLTypeForKey: was asked, no filter was made there at all.
        let blur = try #require(
            BlurFilterFactory.make(
                BlurFilterSpec(type: "gaussianBlur", values: [.number("inputRadius", 6), .number("inputNoSuchKey", 1)]))
        )
        #expect((try RuntimeObject(blur).value(forKey: "inputRadius") as? NSNumber)?.doubleValue == 6)
        #expect(try RuntimeObject(blur).value(forKey: "inputNoSuchKey") == nil)
        #expect(BlurFilterFactory.make(BlurFilterSpec(type: "sdrNormalize", values: [])) != nil)
    }

    #if os(macOS)
        /// Live: a window whose background changes under the sampler. The renderer must draw it, so it is on screen,
        /// above the others (an occluded window is not drawn: one run in four failed before it floated). On iOS a
        /// package's tests have no window scene, so nothing is drawn: the live check there is `Examples/LumaCheck`.
        @Test(.timeLimit(.minutes(1))) func `on screen, readings follow what is behind the view`() async throws {
            var readings: [Double] = []
            let window = NSWindow(
                contentRect: NSRect(x: 200, y: 200, width: 160, height: 120), styleMask: .borderless,
                backing: .buffered, defer: false)
            window.backgroundColor = .white
            // Above the windows on screen: an occluded window is not drawn, and so is not read.
            window.level = .floating
            let view = BackdropLumaNSView(frame: NSRect(x: 0, y: 0, width: 160, height: 120))
            window.contentView?.addSubview(view)
            window.orderFrontRegardless()
            defer { window.orderOut(nil) }
            func paint(_ white: Bool) {
                window.backgroundColor = white ? .white : .black
                window.displayIfNeeded()
                CATransaction.flush()
            }
            try #require(view.isAvailable)
            view.interval = 0.1
            CATransaction.flush()
            view.onLuma = { readings.append($0) }
            try await waitFor { readings.last.map { $0 > 0.9 } == true }
            paint(false)
            try await waitFor { readings.last.map { $0 < 0.1 } == true }
            paint(true)
            try await waitFor { readings.last.map { $0 > 0.9 } == true }
            #expect(view.level == .light, "readings \(readings), kicks \(view.kicks)")
        }
    #endif

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() { try await Task.sleep(for: .milliseconds(50)) }
        #expect(condition())
    }
}
