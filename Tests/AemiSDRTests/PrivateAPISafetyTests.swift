#if os(iOS)
    import Abysm
    import Testing
    import UIKit

    @testable import AemiSDR

    @MainActor
    @Suite("Private API safety and policy kill-switch", .serialized)
    struct PrivateAPISafetyTests {
        @Test func `requestedValues get and set on plain NSObject returns nil without raising`() {
            let plain = NSObject()
            #expect(plain.requestedValues == nil)
            // Setting values on an object lacking the key must not raise an uncatchable NSUnknownKeyException
            plain.requestedValues = ["test": 123]
            #expect(plain.requestedValues == nil)
        }

        @Test func `disabling PrivateAPIPolicy suppresses private classes and filters`() {
            let wasEnabled = PrivateAPIPolicy.isEnabled
            defer { PrivateAPIPolicy.isEnabled = wasEnabled }

            PrivateAPIPolicy.isEnabled = false
            #expect(!PrivateAPIPolicy.isEnabled)
            #expect(BackdropCaptureView.layerClass is CALayer.Type)

            let blurView = VariableBlurUIView(maxBlurRadius: 20)
            blurView.layoutSubviews()
            #expect(
                blurView.filterAssignmentCount == 0, "when private API is disabled, no CAFilter is created or assigned")

            let visualEffect = VisualEffectUIView(effect: UIBlurEffect(style: .light))
            visualEffect.colorTint = .red
            #expect(visualEffect.colorTint == nil, "private tint filters must not be assigned when policy is disabled")

            PrivateAPIPolicy.isEnabled = true
            #expect(PrivateAPIPolicy.isEnabled)
        }

        @Test func `canary: all expected private symbols resolve or are recorded`() {
            RuntimeAccess.resetResolutions()
            _ = UIScreen.main.displayCornerRadii
            let failures = RuntimeAccess.failures
            #expect(failures.isEmpty, "canary found unexpected private API resolution failures: \(failures)")
        }
    }
#endif
