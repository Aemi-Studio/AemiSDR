#if os(iOS)
    import UIKit
    import Testing
    @testable import AemiSDR

    @MainActor
    @Suite("System blur presets")
    struct SystemBlurStyleTests {
        @Test func classicStylesDoNotUseBackdropSettingsConstants() {
            #expect(BackdropBlurConfiguration.systemStyle(.light).blurRadius == 30)
            #expect(BackdropBlurConfiguration.systemStyle(.dark).blurRadius == 20)
        }

        @Test func sameStyleAndAppearanceAreStable() {
            let first = BackdropBlurConfiguration.systemStyle(.regular, userInterfaceStyle: .dark)
            #expect(first == BackdropBlurConfiguration.systemStyle(.regular, userInterfaceStyle: .dark))
            #expect(first.blurRadius > 0)
        }

        @Test func explicitAppearancesResolveIndependently() {
            let light = BackdropBlurConfiguration.systemStyle(.regular, userInterfaceStyle: .light)
            let dark = BackdropBlurConfiguration.systemStyle(.regular, userInterfaceStyle: .dark)
            #expect(light.blurRadius == 30)
            #expect(dark.blurRadius == 20)
        }

        @Test func modernMaterialsDoNotCollapseToUltraLight() {
            let thin = BackdropBlurConfiguration.systemStyle(.systemUltraThinMaterial)
            let thick = BackdropBlurConfiguration.systemStyle(.systemThickMaterial)
            #expect(thick.blurRadius > thin.blurRadius)
            #expect(thick.saturationDeltaFactor > thin.saturationDeltaFactor)
        }
    }
#endif
