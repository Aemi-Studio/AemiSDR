#if os(iOS)
    import Metal
    import Testing
    import UIKit

    @testable import AemiSDR

    @MainActor
    @Suite("Liquid lens view lifecycle and render gating")
    struct LiquidLensLifecycleTests {
        @Test func `unchanged layout passes do not trigger redundant render attempts`() throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: 32, height: 32, mipmapped: false)
            let texture = try #require(device.makeTexture(descriptor: descriptor))

            let view = LiquidLensUIView()
            view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            view.setSourceTexture(texture)
            view.layoutSubviews()
            let initialAttempts = view.renderAttemptCount
            #expect(initialAttempts > 0)

            for _ in 0..<100 {
                view.layoutSubviews()
            }
            #expect(
                view.renderAttemptCount == initialAttempts,
                "100 unchanged layoutSubviews() must not attempt redundant renders (got \(view.renderAttemptCount) vs \(initialAttempts))"
            )

            // A configuration change must re-enable rendering on the next layout pass.
            view.updateConfiguration(LiquidLensConfiguration(strength: 2.0))
            #expect(view.renderAttemptCount > initialAttempts, "configuration change must trigger a render")
            let afterConfigAttempts = view.renderAttemptCount

            for _ in 0..<50 {
                view.layoutSubviews()
            }
            #expect(
                view.renderAttemptCount == afterConfigAttempts,
                "subsequent unchanged layoutSubviews() must not re-render (got \(view.renderAttemptCount) vs \(afterConfigAttempts))"
            )
        }

        @Test func `resizing the view marks it as needing a render`() throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: 32, height: 32, mipmapped: false)
            let texture = try #require(device.makeTexture(descriptor: descriptor))

            let view = LiquidLensUIView()
            view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            view.setSourceTexture(texture)
            view.layoutSubviews()
            let initialAttempts = view.renderAttemptCount

            view.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
            view.layoutSubviews()
            #expect(view.renderAttemptCount > initialAttempts, "size change must trigger a render")
        }
    }
#endif
