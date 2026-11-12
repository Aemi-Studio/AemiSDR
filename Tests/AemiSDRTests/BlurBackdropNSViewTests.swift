#if os(macOS)
    import AppKit
    import Testing

    @testable import AemiSDR

    /// Roadmap 0020 slice 3: the macOS view chooses the backdrop, the material or an opaque fill, and never changes its layers
    /// in the turn a recipe is given (a SwiftUI update): only on the next one.
    @MainActor @Suite("Blur backdrop view (macOS)", .serialized) struct BlurBackdropNSViewTests {
        @Test
        func `the backdrop when it can be made, the material when not, an opaque fill when transparency is reduced`() {
            #expect(BlurBackdropMode.choose(reduceTransparency: false, backdropAvailable: true) == .backdrop)
            #expect(BlurBackdropMode.choose(reduceTransparency: false, backdropAvailable: false) == .material)
            #expect(BlurBackdropMode.choose(reduceTransparency: true, backdropAvailable: true) == .opaque)
        }

        @Test func `a recipe given is not applied in the same turn, and is applied by the next`() {
            let view = BlurBackdropNSView(frame: CGRect(x: 0, y: 0, width: 200, height: 76))
            view.recipe = .variable(radius: 24, mask: .edge(.top, solid: 38, fade: 38))
            #expect(view.filterAssignmentCount == 0)
            view.applyPending()
            #expect(view.mode == .backdrop && view.filterAssignmentCount == 1)
            view.recipe = .variable(radius: 24, mask: .edge(.top, solid: 38, fade: 38))
            view.applyPending()
            #expect(view.filterAssignmentCount == 1, "an equal recipe does no filter work")
        }

        @Test func `with private API off the view is the system material, masked like the blur`() {
            let was = PrivateAPIPolicy.isEnabled
            defer { PrivateAPIPolicy.isEnabled = was }
            PrivateAPIPolicy.isEnabled = false
            let view = BlurBackdropNSView(frame: CGRect(x: 0, y: 0, width: 200, height: 76))
            view.recipe = .variable(radius: 24, mask: .edge(.top, solid: 38, fade: 38))
            view.applyPending()
            #expect(view.mode == .material)
            #expect(view.subviews.compactMap { $0 as? NSVisualEffectView }.first?.maskImage != nil)
        }
    }
#endif
