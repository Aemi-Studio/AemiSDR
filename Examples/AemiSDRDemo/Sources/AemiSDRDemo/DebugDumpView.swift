import AemiSDR
import SwiftUI

#if canImport(UIKit)
    import UIKit

    // MARK: - iOS Debug Dump

    struct DebugDumpView: View {
        @State private var dumpOutput = "Tap 'Run Dump' to inspect internal state"
        @State private var blurRadius: CGFloat = 20
        @State private var saturation: CGFloat = 1.8
        @State private var scale: CGFloat = 1
        @State private var grayscale: CGFloat = 0.5
        @State private var darkening: CGFloat = 0.3

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("iOS VisualEffect Debug")
                        .font(.title2.bold())

                    Button("Run Dump") {
                        dumpOutput = runiOSDump()
                    }
                    .buttonStyle(.borderedProminent)

                    Text(dumpOutput)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding()
            }
            .navigationTitle("Debug")
            .onAppear {
                dumpOutput = runiOSDump()
            }
        }

        private func runiOSDump() -> String {
            var lines: [String] = []

            func log(_ s: String) {
                lines.append(s)
                print(s)
            }

            // --- Test 1: Create _UICustomBlurEffect and inspect it ---
            log("=== TEST 1: _UICustomBlurEffect class ===")
            if let cls = NSClassFromString("_UICustomBlurEffect") as? UIBlurEffect.Type {
                let customEffect = cls.init()
                log("Created _UICustomBlurEffect: \(customEffect)")
                log("Class: \(NSStringFromClass(type(of: customEffect)))")

                let kvcKeys = [
                    "blurRadius", "scale", "saturationDeltaFactor",
                    "grayscaleTintLevel", "grayscaleTintAlpha",
                    "colorBurnTintLevel", "colorBurnTintAlpha",
                    "darkeningTintAlpha", "darkeningTintHue", "darkeningTintSaturation",
                    "zoom", "lightenGrayscaleWithSourceOver", "darkenWithSourceOver",
                    "colorTint", "colorTintAlpha",
                ]

                log("--- Default KVC values ---")
                for key in kvcKeys {
                    let val = (customEffect as NSObject).value(forKey: key)
                    log("  \(key) = \(String(describing: val))")
                }

                // Set custom values
                (customEffect as NSObject).setValue(blurRadius, forKey: "blurRadius")
                (customEffect as NSObject).setValue(saturation, forKey: "saturationDeltaFactor")
                (customEffect as NSObject).setValue(scale, forKey: "scale")
                (customEffect as NSObject).setValue(grayscale, forKey: "grayscaleTintLevel")
                (customEffect as NSObject).setValue(darkening, forKey: "darkeningTintAlpha")

                log("--- After setting values ---")
                for key in kvcKeys {
                    let val = (customEffect as NSObject).value(forKey: key)
                    log("  \(key) = \(String(describing: val))")
                }
            } else {
                log("ERROR: Could not find _UICustomBlurEffect class")
            }

            // --- Test 2: Create VisualEffectUIView with config and dump its state ---
            log("")
            log("=== TEST 2: VisualEffectUIView with configuration ===")
            let config = VisualEffectConfiguration(
                blurRadius: blurRadius,
                scale: scale,
                saturationDeltaFactor: saturation,
                grayscaleTintLevel: grayscale,
                darkeningTintAlpha: darkening
            )
            let vfxView = VisualEffectUIView(configuration: config)
            vfxView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            vfxView.layoutIfNeeded()

            log("effect: \(String(describing: vfxView.effect))")
            if let eff = vfxView.effect {
                log("effect class: \(NSStringFromClass(type(of: eff)))")
            }

            dumpSubviews(of: vfxView, indent: 0, log: { log($0) })

            // --- Test 3: Create with nil effect, then call setters individually ---
            log("")
            log("=== TEST 3: Individual property setters ===")
            let vfxView2 = VisualEffectUIView(effect: nil)
            vfxView2.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            vfxView2.layoutIfNeeded()

            log("-- Before any setters --")
            log("effect: \(String(describing: vfxView2.effect))")
            dumpSubviews(of: vfxView2, indent: 0, log: { log($0) })

            log("-- Setting blurRadius = \(blurRadius) --")
            vfxView2.blurRadius = blurRadius
            vfxView2.layoutIfNeeded()
            log("effect: \(String(describing: vfxView2.effect))")
            log("effect class: \(NSStringFromClass(type(of: vfxView2.effect!)))")
            dumpSubviews(of: vfxView2, indent: 0, log: { log($0) })

            log("-- Setting saturationDeltaFactor = \(saturation) --")
            vfxView2.saturationDeltaFactor = saturation
            vfxView2.layoutIfNeeded()
            log("effect: \(String(describing: vfxView2.effect))")
            log("effect class: \(NSStringFromClass(type(of: vfxView2.effect!)))")
            dumpSubviews(of: vfxView2, indent: 0, log: { log($0) })

            log("-- Setting scale = \(self.scale) --")
            vfxView2.scale = self.scale
            vfxView2.layoutIfNeeded()

            log("-- Setting grayscaleTintLevel = \(grayscale) --")
            vfxView2.grayscaleTintLevel = grayscale
            vfxView2.layoutIfNeeded()

            log("-- Setting darkeningTintAlpha = \(darkening) --")
            vfxView2.darkeningTintAlpha = darkening
            vfxView2.layoutIfNeeded()

            log("-- Final state --")
            dumpSubviews(of: vfxView2, indent: 0, log: { log($0) })

            // --- Test 4: What does prepareForChanges do? ---
            log("")
            log("=== TEST 4: Effect identity after prepareForChanges ===")
            let vfxView3 = VisualEffectUIView(effect: nil)
            vfxView3.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            log("Before: effect = \(String(describing: vfxView3.effect))")

            // Set blur to trigger prepareForChanges
            vfxView3.blurRadius = 10
            log("After blurRadius=10: effect class = \(NSStringFromClass(type(of: vfxView3.effect!)))")
            log("  Is _UICustomBlurEffect? \(NSStringFromClass(type(of: vfxView3.effect!)).contains("Custom"))")

            // Now read the KVC values off the ACTUAL effect
            if let eff = vfxView3.effect as NSObject? {
                log("  Actual effect KVC values:")
                for key in ["blurRadius", "scale", "saturationDeltaFactor", "grayscaleTintLevel", "darkeningTintAlpha"] {
                    if let val = eff.value(forKey: key) {
                        log("    \(key) = \(val)")
                    } else {
                        log("    \(key) = <not KVC-compliant>")
                    }
                }
            }

            // --- Test 5: Using _UICustomBlurEffect as the effect directly ---
            log("")
            log("=== TEST 5: _UICustomBlurEffect as effect directly ===")
            if let cls = NSClassFromString("_UICustomBlurEffect") as? UIBlurEffect.Type {
                let customEffect = cls.init()
                (customEffect as NSObject).setValue(blurRadius, forKey: "blurRadius")
                (customEffect as NSObject).setValue(saturation, forKey: "saturationDeltaFactor")
                (customEffect as NSObject).setValue(scale, forKey: "scale")
                (customEffect as NSObject).setValue(grayscale, forKey: "grayscaleTintLevel")
                (customEffect as NSObject).setValue(0.5 as CGFloat, forKey: "grayscaleTintAlpha")
                (customEffect as NSObject).setValue(darkening, forKey: "darkeningTintAlpha")

                let vfxView4 = UIVisualEffectView(effect: nil)
                vfxView4.frame = CGRect(x: 0, y: 0, width: 200, height: 200)

                log("Setting effect = _UICustomBlurEffect with values")
                vfxView4.effect = customEffect
                vfxView4.layoutIfNeeded()

                log("effect class: \(NSStringFromClass(type(of: vfxView4.effect!)))")
                dumpSubviews(of: vfxView4, indent: 0, log: { log($0) })

                // Try nil + re-set trick
                log("-- nil + re-set trick --")
                vfxView4.effect = nil
                vfxView4.effect = customEffect
                vfxView4.layoutIfNeeded()
                dumpSubviews(of: vfxView4, indent: 0, log: { log($0) })
            }

            // --- Test 6: What _UIBackdropViewSettings gives us ---
            log("")
            log("=== TEST 6: _UIBackdropViewSettings for .light ===")
            if let settingsClass = NSClassFromString("_UIBackdropViewSettings") as? NSObject.Type {
                let sel = NSSelectorFromString("settingsForStyle:")
                if settingsClass.responds(to: sel),
                   let settings = unsafe settingsClass.perform(sel, with: UIBlurEffect.Style.light.rawValue)?
                    .takeUnretainedValue() as? NSObject
                {
                    let keys = [
                        "blurRadius", "scale", "saturationDeltaFactor",
                        "grayscaleTintLevel", "grayscaleTintAlpha",
                        "colorBurnTintLevel", "colorBurnTintAlpha",
                        "darkeningTintAlpha", "darkeningTintHue", "darkeningTintSaturation",
                        "zoom", "usesGrayscaleTintView", "usesColorTintView", "usesColorBurnTintView",
                        "lightenGrayscaleWithSourceOver", "darkenWithSourceOver",
                    ]
                    for key in keys {
                        if let val = settings.value(forKey: key) {
                            log("  \(key) = \(val)")
                        }
                    }
                }
            }

            // --- Test 7: Directly manipulate backdrop filters ---
            log("")
            log("=== TEST 7: Direct filter manipulation ===")
            let vfxView5 = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            vfxView5.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            vfxView5.layoutIfNeeded()

            log("Created UIVisualEffectView with UIBlurEffect(style: .light)")
            dumpSubviews(of: vfxView5, indent: 0, log: { log($0) })

            // Find backdrop and try to find all available filters
            for sub in vfxView5.subviews {
                let className = NSStringFromClass(type(of: sub))
                if className.contains("Backdrop") {
                    log("")
                    log("--- Detailed backdrop filter dump ---")
                    if let filters = sub.value(forKeyPath: "filters") as? [NSObject] {
                        for (i, filter) in filters.enumerated() {
                            let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                            log("filter[\(i)]: \(filterType)")
                            log("  class: \(NSStringFromClass(type(of: filter)))")

                            // Dump all properties we can find
                            if let reqVals = filter.value(forKeyPath: "requestedValues") as? [String: Any] {
                                log("  requestedValues: \(reqVals)")
                            }
                            // Try common input keys
                            for inputKey in ["inputRadius", "inputAmount", "inputNormalizeEdges", "inputMaskImage"] {
                                if let val = filter.value(forKey: inputKey) {
                                    log("  \(inputKey) = \(val)")
                                }
                            }
                        }
                    }
                }
            }

            return lines.joined(separator: "\n")
        }

        private func dumpSubviews(of view: UIView, indent: Int, log: (String) -> Void) {
            let prefix = String(repeating: "  ", count: indent)
            for sub in view.subviews {
                let className = NSStringFromClass(type(of: sub))
                log("\(prefix)subview: \(className) frame=\(sub.frame)")

                if className.contains("Backdrop") {
                    // Dump filters
                    if let filters = sub.value(forKeyPath: "filters") as? [NSObject] {
                        for filter in filters {
                            let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                            var detail = "\(prefix)  filter: \(filterType)"
                            if let reqVals = filter.value(forKeyPath: "requestedValues") as? [String: Any] {
                                detail += " requestedValues=\(reqVals)"
                            }
                            log(detail)
                        }
                    } else {
                        log("\(prefix)  filters: nil or not [NSObject]")
                    }

                    // Check if there's a requestedScaleHint
                    if let scaleHint = sub.value(forKeyPath: "requestedScaleHint") {
                        log("\(prefix)  requestedScaleHint = \(scaleHint)")
                    }
                }

                if className.contains("Subview") || className.contains("Overlay") {
                    // Dump view effects
                    if let effects = sub.value(forKeyPath: "viewEffects") as? [NSObject] {
                        for eff in effects {
                            let filterType = eff.value(forKeyPath: "filterType") as? String ?? "unknown"
                            log("\(prefix)  viewEffect: \(filterType)")
                            if let color = eff.value(forKeyPath: "color") {
                                log("\(prefix)    color = \(color)")
                            }
                        }
                    }
                    log("\(prefix)  backgroundColor = \(String(describing: sub.backgroundColor))")
                }

                // Recurse
                dumpSubviews(of: sub, indent: indent + 1, log: log)
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    // MARK: - macOS Debug Dump

    struct DebugDumpView: View {
        @State private var dumpOutput = "Tap 'Run Dump' to inspect internal state"
        @State private var blurRadius: CGFloat = 20
        @State private var saturation: CGFloat = 1.8
        @State private var scale: CGFloat = 1
        @State private var grayscale: CGFloat = 0.5
        @State private var darkening: CGFloat = 0.3

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("macOS VisualEffect Debug")
                        .font(.title2.bold())

                    Button("Run Dump") {
                        dumpOutput = runMacOSDump()
                    }
                    .buttonStyle(.borderedProminent)

                    Text(dumpOutput)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding()
            }
            .onAppear {
                dumpOutput = runMacOSDump()
            }
        }

        @MainActor
        private func runMacOSDump() -> String {
            var lines: [String] = []

            func log(_ s: String) {
                lines.append(s)
                print(s)
            }

            // --- Test 1: Create NSVisualEffectView and inspect _backdropLayer ---
            log("=== TEST 1: NSVisualEffectView basic state ===")
            let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
            view.material = .popover
            view.blendingMode = .behindWindow
            view.state = .active
            view.wantsLayer = true

            log("Before layout:")
            log("  responds to _backdropLayer: \(view.responds(to: NSSelectorFromString("_backdropLayer")))")

            if let backdrop = view.value(forKey: "_backdropLayer") as? CALayer {
                log("  _backdropLayer exists: \(NSStringFromClass(type(of: backdrop)))")
            } else {
                log("  _backdropLayer: nil")
            }

            // Force layout
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()

            log("")
            log("After layoutSubtreeIfNeeded + displayIfNeeded:")
            if let backdrop = view.value(forKey: "_backdropLayer") as? CALayer {
                log("  _backdropLayer: \(NSStringFromClass(type(of: backdrop)))")
                dumpBackdropLayer(backdrop, log: { log($0) })
            } else {
                log("  _backdropLayer: STILL nil after layout")
            }

            // --- Test 2: Dump all layer hierarchy ---
            log("")
            log("=== TEST 2: Layer hierarchy ===")
            if let layer = view.layer {
                dumpLayerHierarchy(layer, indent: 0, log: { log($0) })
            } else {
                log("  view.layer is nil")
            }

            // --- Test 3: Try setting filter values ---
            log("")
            log("=== TEST 3: Setting filter values ===")
            if let backdrop = view.value(forKey: "_backdropLayer") as? CALayer {
                // Try setting blur
                if let filters = backdrop.value(forKeyPath: "filters") as? [NSObject] {
                    for filter in filters {
                        let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                        if filterType == "gaussianBlur" {
                            log("  Setting gaussianBlur.inputRadius = \(blurRadius)")
                            filter.setValue(blurRadius, forKey: "inputRadius")
                            if let readBack = filter.value(forKey: "inputRadius") {
                                log("  Read back: \(readBack)")
                            }
                        }
                        if filterType == "colorSaturate" {
                            log("  Setting colorSaturate.inputAmount = \(saturation)")
                            filter.setValue(saturation, forKey: "inputAmount")
                            if let readBack = filter.value(forKey: "inputAmount") {
                                log("  Read back: \(readBack)")
                            }
                        }
                        if filterType == "colorBrightness" {
                            let brightnessVal = grayscale - 1.0
                            log("  Setting colorBrightness.inputAmount = \(brightnessVal)")
                            filter.setValue(brightnessVal, forKey: "inputAmount")
                            if let readBack = filter.value(forKey: "inputAmount") {
                                log("  Read back: \(readBack)")
                            }
                        }
                    }

                    // Try setting scale on backdrop
                    log("  Setting backdrop.scale = \(scale)")
                    backdrop.setValue(scale, forKey: "scale")
                    if let readBack = backdrop.value(forKey: "scale") {
                        log("  Read back: \(readBack)")
                    }

                    // Check if we need to force re-render
                    log("")
                    log("--- After setting values, re-reading ---")
                    for filter in filters {
                        let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                        log("  filter: \(filterType)")
                        for inputKey in ["inputRadius", "inputAmount"] {
                            if let val = filter.value(forKey: inputKey) {
                                log("    \(inputKey) = \(val)")
                            }
                        }
                    }
                }

                // Do we need to set needs display?
                log("")
                log("--- Forcing display ---")
                backdrop.setNeedsDisplay()
                view.needsDisplay = true
                view.displayIfNeeded()

                // Re-read
                if let filters = backdrop.value(forKeyPath: "filters") as? [NSObject] {
                    for filter in filters {
                        let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                        log("  filter: \(filterType)")
                        for inputKey in ["inputRadius", "inputAmount"] {
                            if let val = filter.value(forKey: inputKey) {
                                log("    \(inputKey) = \(val)")
                            }
                        }
                    }
                }
            }

            // --- Test 4: What happens with our VisualEffectView (SwiftUI) ---
            log("")
            log("=== TEST 4: Introspect system materials ===")
            for material in [
                NSVisualEffectView.Material.popover,
                .titlebar,
                .sheet,
                .hudWindow,
                .headerView,
            ] {
                let testView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
                testView.material = material
                testView.blendingMode = .behindWindow
                testView.state = .active
                testView.wantsLayer = true
                testView.layoutSubtreeIfNeeded()
                testView.displayIfNeeded()

                log("Material \(material.rawValue):")
                if let backdrop = testView.value(forKey: "_backdropLayer") as? CALayer {
                    if let filters = backdrop.value(forKeyPath: "filters") as? [NSObject] {
                        for filter in filters {
                            let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                            var vals: [String] = []
                            for inputKey in ["inputRadius", "inputAmount"] {
                                if let val = filter.value(forKey: inputKey) {
                                    vals.append("\(inputKey)=\(val)")
                                }
                            }
                            log("  \(filterType): \(vals.joined(separator: ", "))")
                        }
                    }
                    if let scaleVal = backdrop.value(forKey: "scale") {
                        log("  scale: \(scaleVal)")
                    }
                } else {
                    log("  _backdropLayer: nil")
                }
            }

            // --- Test 5: Check if CABackdropLayer filters are being overwritten by the system ---
            log("")
            log("=== TEST 5: Do filter modifications persist after display? ===")
            let testView2 = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
            testView2.material = .popover
            testView2.blendingMode = .behindWindow
            testView2.state = .active
            testView2.wantsLayer = true
            testView2.layoutSubtreeIfNeeded()
            testView2.displayIfNeeded()

            if let backdrop = testView2.value(forKey: "_backdropLayer") as? CALayer {
                // Read initial
                var initialBlur: Any?
                if let filters = backdrop.value(forKeyPath: "filters") as? [NSObject] {
                    for filter in filters {
                        if filter.value(forKeyPath: "filterType") as? String == "gaussianBlur" {
                            initialBlur = filter.value(forKey: "inputRadius")
                            log("Initial gaussianBlur.inputRadius = \(String(describing: initialBlur))")
                            filter.setValue(50.0, forKey: "inputRadius")
                            log("Set to 50.0")
                            if let readBack = filter.value(forKey: "inputRadius") {
                                log("Immediate read back: \(readBack)")
                            }
                        }
                    }
                }

                // Display again
                testView2.displayIfNeeded()

                if let filters = backdrop.value(forKeyPath: "filters") as? [NSObject] {
                    for filter in filters {
                        if filter.value(forKeyPath: "filterType") as? String == "gaussianBlur" {
                            if let afterDisplay = filter.value(forKey: "inputRadius") {
                                log("After displayIfNeeded: \(afterDisplay)")
                            }
                        }
                    }
                }

                // Layout again
                testView2.layoutSubtreeIfNeeded()

                if let filters = backdrop.value(forKeyPath: "filters") as? [NSObject] {
                    for filter in filters {
                        if filter.value(forKeyPath: "filterType") as? String == "gaussianBlur" {
                            if let afterLayout = filter.value(forKey: "inputRadius") {
                                log("After layoutSubtreeIfNeeded: \(afterLayout)")
                            }
                        }
                    }
                }
            }

            // --- Test 6: Try CATransaction to commit filter changes ---
            log("")
            log("=== TEST 6: CATransaction commit ===")
            if let backdrop = view.value(forKey: "_backdropLayer") as? CALayer {
                if let filters = backdrop.value(forKeyPath: "filters") as? [NSObject] {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    for filter in filters {
                        let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                        if filterType == "gaussianBlur" {
                            filter.setValue(35.0, forKey: "inputRadius")
                            log("Set gaussianBlur.inputRadius = 35.0 inside CATransaction")
                        }
                    }
                    // Re-set the filters array to force commit
                    backdrop.setValue(filters, forKey: "filters")
                    CATransaction.commit()

                    // Read back
                    if let readFilters = backdrop.value(forKeyPath: "filters") as? [NSObject] {
                        for filter in readFilters {
                            if filter.value(forKeyPath: "filterType") as? String == "gaussianBlur" {
                                if let val = filter.value(forKey: "inputRadius") {
                                    log("After CATransaction commit + re-set filters: \(val)")
                                }
                            }
                        }
                    }
                }
            }

            return lines.joined(separator: "\n")
        }

        private func dumpBackdropLayer(_ layer: CALayer, log: (String) -> Void) {
            log("  class: \(NSStringFromClass(type(of: layer)))")

            if let scale = layer.value(forKey: "scale") {
                log("  scale: \(scale)")
            }

            if let filters = layer.value(forKeyPath: "filters") as? [NSObject] {
                log("  filters count: \(filters.count)")
                for (i, filter) in filters.enumerated() {
                    let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                    log("  filter[\(i)]: type=\(filterType) class=\(NSStringFromClass(type(of: filter)))")

                    // Dump all known input keys
                    for inputKey in ["inputRadius", "inputAmount", "inputNormalizeEdges"] {
                        if let val = filter.value(forKey: inputKey) {
                            log("    \(inputKey) = \(val)")
                        }
                    }
                }
            } else {
                log("  filters: nil or not [NSObject]")
            }

            if let bgFilters = layer.value(forKeyPath: "backgroundFilters") as? [NSObject] {
                log("  backgroundFilters count: \(bgFilters.count)")
                for (i, filter) in bgFilters.enumerated() {
                    let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                    log("  backgroundFilter[\(i)]: type=\(filterType)")
                }
            }

            // Check sublayers
            if let sublayers = layer.sublayers {
                log("  sublayers count: \(sublayers.count)")
                for (i, sub) in sublayers.enumerated() {
                    log("  sublayer[\(i)]: \(NSStringFromClass(type(of: sub))) bg=\(String(describing: sub.backgroundColor))")
                }
            }
        }

        private func dumpLayerHierarchy(_ layer: CALayer, indent: Int, log: (String) -> Void) {
            let prefix = String(repeating: "  ", count: indent)
            log("\(prefix)layer: \(NSStringFromClass(type(of: layer))) frame=\(layer.frame)")

            if let filters = layer.value(forKeyPath: "filters") as? [NSObject], !filters.isEmpty {
                for filter in filters {
                    let filterType = filter.value(forKeyPath: "filterType") as? String ?? "unknown"
                    log("\(prefix)  filter: \(filterType)")
                }
            }

            if let sublayers = layer.sublayers {
                for sub in sublayers {
                    dumpLayerHierarchy(sub, indent: indent + 1, log: log)
                }
            }
        }
    }
#endif
