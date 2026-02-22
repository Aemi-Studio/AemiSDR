import AemiSDR
import SwiftUI

#if canImport(UIKit)
    import UIKit

    // MARK: - Effects Lab (iOS)

    struct EffectsLabView: View {
        enum Tab: String, CaseIterable {
            case variableBlur = "Variable Blur"
            case alphaMask = "Alpha Mask"
            case filterInspector = "Filter Inspector"
        }

        @State private var selectedTab: Tab = .variableBlur

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    Picker("Section", selection: $selectedTab) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    switch selectedTab {
                    case .variableBlur:
                        VariableBlurLab()
                    case .alphaMask:
                        AlphaMaskLab()
                    case .filterInspector:
                        FilterInspectorView()
                    }
                }
                .navigationTitle("Effects Lab")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
            }
        }
    }

    // MARK: - Sample Scrollable Content

    /// Rich scrollable content with text, inputs, and UI components for testing effects.
    struct SampleScrollContent: View {
        @State private var toggleA = true
        @State private var toggleB = false
        @State private var sliderVal: Double = 0.5
        @State private var textInput = ""

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    Text("The quick brown fox")
                        .font(.largeTitle.bold())
                    Text("jumps over the lazy dog")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    // Paragraph
                    Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.")
                        .font(.body)

                    Divider()

                    // Form-like controls
                    TextField("Type something...", text: $textInput)
                        .textFieldStyle(.roundedBorder)

                    Toggle("Enable notifications", isOn: $toggleA)
                    Toggle("Dark mode override", isOn: $toggleB)

                    HStack {
                        Text("Volume")
                        Slider(value: $sliderVal)
                    }

                    // Cards
                    ForEach(0..<4) { i in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill([Color.blue, .green, .orange, .purple][i])
                                .frame(width: 50, height: 50)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Item \(i + 1)")
                                    .font(.headline)
                                Text("Subtitle text for this row")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(.systemBackground).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Buttons row
                    HStack(spacing: 12) {
                        Button("Primary") {}
                            .buttonStyle(.borderedProminent)
                        Button("Secondary") {}
                            .buttonStyle(.bordered)
                        Button("Destructive", role: .destructive) {}
                            .buttonStyle(.bordered)
                    }

                    // More text
                    Text("Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // Tags
                    FlowLayout(spacing: 8) {
                        ForEach(["SwiftUI", "Metal", "CoreImage", "CAFilter", "Blur", "Alpha", "Mask", "Effect"], id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.tint.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
    }

    /// Simple horizontal flow layout for tags.
    struct FlowLayout: Layout {
        var spacing: CGFloat = 8

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
            let maxWidth = proposal.width ?? .infinity
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            for sub in subviews {
                let size = sub.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    y += rowHeight + spacing
                    x = 0
                    rowHeight = 0
                }
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            return CGSize(width: maxWidth, height: y + rowHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
            var x = bounds.minX
            var y = bounds.minY
            var rowHeight: CGFloat = 0
            for sub in subviews {
                let size = sub.sizeThatFits(.unspecified)
                if x + size.width > bounds.maxX, x > bounds.minX {
                    y += rowHeight + spacing
                    x = bounds.minX
                    rowHeight = 0
                }
                sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
    }

    // MARK: - Variable Blur Lab

    struct VariableBlurLab: View {
        @State private var maxBlurRadius: CGFloat = 20
        @State private var maskType: MaskType = .linearTopToBottom
        @State private var startOffset: CGFloat = 0
        @State private var cornerRadius: CGFloat = 40
        @State private var fadeWidth: CGFloat = 30

        private func makeVariableBlurView() -> VariableBlurView {
            var v = VariableBlurView(
                maxBlurRadius: maxBlurRadius,
                type: maskType,
                startOffset: startOffset
            )
            v.cornerRadius = cornerRadius
            v.fadeWidth = fadeWidth
            return v
        }

        var body: some View {
            VStack(spacing: 0) {
                // Preview area with variable blur overlay
                ZStack {
                    SampleScrollContent()

                    makeVariableBlurView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Label showing current config
                    VStack {
                        Text("Variable Blur")
                            .font(.headline)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                        Text("radius: \(String(format: "%.0f", maxBlurRadius)) | offset: \(String(format: "%.2f", startOffset))")
                            .font(.caption.monospaced())
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding()
                }
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 4)

                Divider().padding(.top, 8)

                // Controls
                ScrollView {
                    VStack(spacing: 14) {
                        // Mask type picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mask Type").font(.caption.bold())
                            Picker("Mask", selection: $maskType) {
                                Text("Linear T->B").tag(MaskType.linearTopToBottom)
                                Text("Linear B->T").tag(MaskType.linearBottomToTop)
                                Text("EaseIn T->B").tag(MaskType.easeInTopToBottom)
                                Text("EaseIn B->T").tag(MaskType.easeInBottomToTop)
                                Text("Rounded Rect").tag(MaskType.roundedRectangle)
                                Text("Eased Rect").tag(MaskType.easedRoundedRectangle)
                                Text("Squircle").tag(MaskType.superellipseSquircle)
                                Text("Eased Squircle").tag(MaskType.easedSuperellipseSquircle)
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                        }

                        sliderRow("Max Blur Radius", value: $maxBlurRadius, range: 0...60)
                        sliderRow("Start Offset", value: $startOffset, range: 0...1)
                        sliderRow("Corner Radius", value: $cornerRadius, range: 0...100)
                        sliderRow("Fade Width", value: $fadeWidth, range: 0...80)

                        Button("Reset") {
                            maxBlurRadius = 20
                            maskType = .linearTopToBottom
                            startOffset = 0
                            cornerRadius = 40
                            fadeWidth = 30
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
                .background(.regularMaterial)
            }
        }
    }

    // MARK: - Alpha Mask Lab

    struct AlphaMaskLab: View {
        @State private var maskType: MaskType = .linearTopToBottom
        @State private var fadeWidth: CGFloat = 60
        @State private var cornerRadius: CGFloat = 40
        @State private var inverted: Bool = true
        @State private var startOffset: CGFloat = 0.3
        @State private var showDiagnostics: Bool = false
        @State private var diagnosticOutput: String = ""

        private func makeAlphaMaskView() -> AlphaMaskView {
            var v = AlphaMaskView(
                type: maskType,
                startOffset: startOffset,
                inverted: inverted
            )
            v.cornerRadius = cornerRadius
            v.fadeWidth = fadeWidth
            return v
        }

        var body: some View {
            VStack(spacing: 0) {
                // Preview: content with alpha mask applied
                ZStack {
                    // Checkerboard background to show transparency
                    CheckerboardView()

                    // Content that should be masked
                    SampleScrollContent()
                        .mask {
                            makeAlphaMaskView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                    // Overlay label
                    VStack {
                        Text("Alpha Mask")
                            .font(.headline)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                        Text("type: \(String(describing: maskType))")
                            .font(.caption.monospaced())
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding()
                }
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 4)

                Divider()

                ScrollView {
                    VStack(spacing: 14) {
                        // Mask type
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mask Type").font(.caption.bold())
                            Picker("Mask", selection: $maskType) {
                                Text("Linear T→B").tag(MaskType.linearTopToBottom)
                                Text("Linear B→T").tag(MaskType.linearBottomToTop)
                                Text("EaseIn T→B").tag(MaskType.easeInTopToBottom)
                                Text("EaseIn B→T").tag(MaskType.easeInBottomToTop)
                                Text("Rounded Rect").tag(MaskType.roundedRectangle)
                                Text("Eased Rect").tag(MaskType.easedRoundedRectangle)
                                Text("Squircle").tag(MaskType.superellipseSquircle)
                                Text("Eased Squircle").tag(MaskType.easedSuperellipseSquircle)
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                        }

                        sliderRow("Start Offset", value: $startOffset, range: 0...1)
                        sliderRow("Fade Width", value: $fadeWidth, range: 0...120)
                        sliderRow("Corner Radius", value: $cornerRadius, range: 0...100)

                        Toggle("Inverted", isOn: $inverted)

                        // Diagnostics
                        Button("Run Alpha Mask Diagnostics") {
                            diagnosticOutput = runAlphaMaskDiagnostics()
                            showDiagnostics = true
                        }
                        .buttonStyle(.borderedProminent)

                        if showDiagnostics {
                            Text(diagnosticOutput)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Button("Reset") {
                            maskType = .linearTopToBottom
                            fadeWidth = 60
                            cornerRadius = 40
                            inverted = true
                            startOffset = 0.3
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
                .background(.regularMaterial)
            }
        }

        private func runAlphaMaskDiagnostics() -> String {
            var lines: [String] = []
            func log(_ s: String) { lines.append(s); print(s) }

            log("=== Alpha Mask Diagnostics ===")

            // Test AlphaMaskUIView directly
            log("")
            log("--- AlphaMaskUIView direct test ---")
            let maskView = AlphaMaskUIView(
                maskType: .linearTopToBottom,
                startOffset: 0.3,
                fadeWidth: 60,
                inverted: true
            )
            maskView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            maskView.layoutIfNeeded()
            log("backgroundColor: \(String(describing: maskView.backgroundColor))")
            log("isOpaque: \(maskView.isOpaque)")
            log("layer.mask: \(maskView.layer.mask != nil ? "EXISTS" : "nil")")
            if let mask = maskView.layer.mask {
                log("  mask frame: \(mask.frame)")
                log("  mask contents: \(mask.contents != nil ? "HAS IMAGE" : "nil")")
                if let contents = mask.contents {
                    log("  contents type: \(type(of: contents))")
                    if let cgImage = contents as! CGImage? {
                        log("  CGImage: \(cgImage.width)x\(cgImage.height)")
                        log("  bpc: \(cgImage.bitsPerComponent) bpp: \(cgImage.bitsPerPixel)")
                        log("  alphaInfo: \(cgImage.alphaInfo.rawValue) (\(alphaInfoName(cgImage.alphaInfo)))")
                        log("  colorSpace: \(cgImage.colorSpace?.name as String? ?? "nil")")
                        log("  bytesPerRow: \(cgImage.bytesPerRow)")

                        // Sample some pixels to check alpha gradient
                        if let dataProvider = cgImage.dataProvider, let data = dataProvider.data {
                            let ptr = CFDataGetBytePtr(data)
                            let bytesPerRow = cgImage.bytesPerRow
                            let bpp = cgImage.bitsPerPixel / 8

                            log("  --- Pixel sampling (Y axis) ---")
                            let xMid = cgImage.width / 2
                            for yFrac in stride(from: 0.0, through: 1.0, by: 0.1) {
                                let y = min(Int(Double(cgImage.height) * yFrac), cgImage.height - 1)
                                let offset = y * bytesPerRow + xMid * bpp
                                if bpp >= 4 {
                                    let r = ptr![offset]
                                    let g = ptr![offset + 1]
                                    let b = ptr![offset + 2]
                                    let a = ptr![offset + 3]
                                    log("    y=\(String(format: "%.1f", yFrac)): R=\(r) G=\(g) B=\(b) A=\(a)")
                                } else if bpp >= 2 {
                                    let v = ptr![offset]
                                    let a = ptr![offset + 1]
                                    log("    y=\(String(format: "%.1f", yFrac)): V=\(v) A=\(a)")
                                }
                            }
                        }
                    }
                }
            } else {
                log("  layer.mask is nil — mask generation likely failed")
                log("  This means Metal library or CIKernel creation failed")
            }

            // Test with different mask types
            log("")
            log("--- AlphaMaskUIView mask types ---")
            for maskType in MaskType.allCases {
                let view = AlphaMaskUIView(maskType: maskType, fadeWidth: 30, inverted: true)
                view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                view.layoutIfNeeded()
                let hasMask = view.layer.mask != nil
                let hasContents = (view.layer.mask?.contents) != nil
                log("  \(maskType): mask=\(hasMask) contents=\(hasContents)")
            }

            // Compare with a plain CAGradientLayer approach
            log("")
            log("--- Control: CAGradientLayer mask ---")
            let controlView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
            controlView.backgroundColor = .white
            let gradLayer = CAGradientLayer()
            gradLayer.frame = controlView.bounds
            gradLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
            gradLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradLayer.endPoint = CGPoint(x: 0.5, y: 1)
            controlView.layer.mask = gradLayer
            log("Control view layer.mask: \(controlView.layer.mask != nil ? "EXISTS" : "nil")")

            return lines.joined(separator: "\n")
        }

        private func alphaInfoName(_ info: CGImageAlphaInfo) -> String {
            switch info {
            case .none: return "none"
            case .premultipliedLast: return "premultipliedLast"
            case .premultipliedFirst: return "premultipliedFirst"
            case .last: return "last"
            case .first: return "first"
            case .noneSkipLast: return "noneSkipLast"
            case .noneSkipFirst: return "noneSkipFirst"
            case .alphaOnly: return "alphaOnly"
            @unknown default: return "unknown(\(info.rawValue))"
            }
        }
    }

    // MARK: - Filter Inspector

    struct FilterInspectorView: View {
        @State private var inspectorOutput = "Tap 'Inspect Filters' to dump all CAFilter info"

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button("Inspect Filters") {
                        inspectorOutput = inspectRuntimeFilters()
                    }
                    .buttonStyle(.borderedProminent)

                    Text(inspectorOutput)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .onAppear {
                inspectorOutput = inspectRuntimeFilters()
            }
        }

        private func inspectRuntimeFilters() -> String {
            var lines: [String] = []
            func log(_ s: String) { lines.append(s); print(s) }

            // --- 1. Inspect backdrop filters from UIBlurEffect styles ---
            log("=== BACKDROP FILTER INSPECTION ===")
            log("")

            for style: (String, UIBlurEffect.Style) in [
                ("light", .light),
                ("dark", .dark),
                ("extraLight", .extraLight),
                ("regular", .regular),
                ("prominent", .prominent),
                ("systemUltraThinMaterial", .systemUltraThinMaterial),
                ("systemThinMaterial", .systemThinMaterial),
                ("systemMaterial", .systemMaterial),
                ("systemThickMaterial", .systemThickMaterial),
                ("systemChromeMaterial", .systemChromeMaterial),
            ] {
                let vfx = UIVisualEffectView(effect: UIBlurEffect(style: style.1))
                vfx.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
                vfx.layoutIfNeeded()

                log("--- \(style.0) ---")

                // Backdrop filters
                if let backdrop = vfx.subviews.first(where: {
                    NSStringFromClass(type(of: $0)).contains("Backdrop")
                }) {
                    if backdrop.responds(to: NSSelectorFromString("filters")),
                       let filters = backdrop.value(forKeyPath: "filters") as? [NSObject]
                    {
                        for filter in filters {
                            let filterType = (filter.responds(to: NSSelectorFromString("filterType"))
                                ? filter.value(forKeyPath: "filterType") as? String : nil) ?? "?"
                            var details: [String] = []

                            if filter.responds(to: NSSelectorFromString("requestedValues")),
                               let reqVals = filter.value(forKeyPath: "requestedValues") as? [String: Any]
                            {
                                for (k, v) in reqVals.sorted(by: { $0.key < $1.key }) {
                                    details.append("\(k)=\(v)")
                                }
                            }

                            // Try direct KVC for known keys (must check responds(to:) — ObjC exceptions aren't caught by try?)
                            for key in ["inputRadius", "inputAmount", "inputMaskImage", "inputNormalizeEdges", "inputColor", "inputColorMatrix"] {
                                if filter.responds(to: NSSelectorFromString(key)),
                                   details.first(where: { $0.hasPrefix(key) }) == nil
                                {
                                    let val = filter.value(forKey: key) as Any
                                    details.append("\(key)=\(val)")
                                }
                            }

                            log("  filter: \(filterType) [\(details.joined(separator: ", "))]")
                        }
                    }

                    // Check requestedScaleHint
                    if backdrop.responds(to: NSSelectorFromString("requestedScaleHint")) {
                        let scaleHint = backdrop.value(forKeyPath: "requestedScaleHint") as Any
                        log("  requestedScaleHint: \(scaleHint)")
                    }
                }

                // Overlay effects
                for sub in vfx.subviews where NSStringFromClass(type(of: sub)).contains("Subview") {
                    if sub.responds(to: NSSelectorFromString("viewEffects")),
                       let effects = sub.value(forKeyPath: "viewEffects") as? [NSObject]
                    {
                        for eff in effects {
                            let ft = (eff.responds(to: NSSelectorFromString("filterType"))
                                ? eff.value(forKeyPath: "filterType") as? String : nil) ?? "?"
                            var details: [String] = []
                            if eff.responds(to: NSSelectorFromString("color")),
                               let color = eff.value(forKeyPath: "color")
                            {
                                details.append("color=\(color)")
                            }
                            log("  overlay: \(ft) [\(details.joined(separator: ", "))]")
                        }
                    }
                    if let bg = sub.backgroundColor {
                        log("  overlayBg: \(bg)")
                    }
                }

                log("")
            }

            // --- 2. Test creating various CAFilter types ---
            log("=== CAFILTER TYPE AVAILABILITY ===")
            log("")

            guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else {
                log("CAFilter class: NOT FOUND")
                return lines.joined(separator: "\n")
            }
            log("CAFilter class: FOUND")

            let filterTypes = [
                "gaussianBlur", "variableBlur", "colorSaturate", "colorBrightness",
                "colorContrast", "colorMatrix", "colorHueRotate", "colorInvert",
                "colorMonochrome", "luminanceToAlpha", "compressLuminance",
                "luminanceCurveMap", "sourceOver", "darkenSourceOver", "lightenSourceOver",
                "multiplyColor", "colorAdd", "colorBurn", "colorDodge",
                "multiply", "screen", "overlay", "darken", "lighten",
                "softLight", "hardLight", "difference", "exclusion",
                "pageCurl", "lanczosResize", "vibrantDark", "vibrantLight",
                "vibrantColorMatrix", "averageColor", "meteor",
            ]

            for filterType in filterTypes {
                if let filter = unsafe filterClass.perform(
                    NSSelectorFromString("filterWithType:"),
                    with: filterType
                )?.takeUnretainedValue() as? NSObject {
                    // Try to find what input keys it responds to
                    var keys: [String] = []
                    for key in ["inputRadius", "inputAmount", "inputColor", "inputColorMatrix",
                                "inputAngle", "inputMaskImage", "inputNormalizeEdges",
                                "inputBias", "type", "filterType", "name"]
                    {
                        if filter.responds(to: NSSelectorFromString(key)) {
                            let val = filter.value(forKey: key) as Any
                            keys.append("\(key)=\(val)")
                        }
                    }
                    log("  \(filterType): OK [\(keys.joined(separator: ", "))]")
                } else {
                    log("  \(filterType): FAILED")
                }
            }

            // --- 3. Variable blur filter details ---
            log("")
            log("=== VARIABLE BLUR FILTER DETAILS ===")

            if let variableBlur = unsafe filterClass.perform(
                NSSelectorFromString("filterWithType:"),
                with: "variableBlur"
            )?.takeUnretainedValue() as? NSObject {
                log("Created variableBlur filter: \(NSStringFromClass(type(of: variableBlur)))")

                // Set and read back values
                variableBlur.setValue(20.0, forKey: "inputRadius")
                variableBlur.setValue(true, forKey: "inputNormalizeEdges")

                if variableBlur.responds(to: NSSelectorFromString("inputRadius")) {
                    log("  inputRadius readback: \(variableBlur.value(forKey: "inputRadius") as Any)")
                }
                if variableBlur.responds(to: NSSelectorFromString("inputNormalizeEdges")) {
                    log("  inputNormalizeEdges readback: \(variableBlur.value(forKey: "inputNormalizeEdges") as Any)")
                }

                // Try setting a mask image
                let size = CGSize(width: 100, height: 100)
                UIGraphicsBeginImageContextWithOptions(size, false, 1)
                if let ctx = UIGraphicsGetCurrentContext() {
                    let colors = [UIColor.white.cgColor, UIColor.clear.cgColor] as CFArray
                    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
                        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                    }
                }
                let testImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                if let cgImage = testImage?.cgImage {
                    variableBlur.setValue(cgImage, forKey: "inputMaskImage")
                    if variableBlur.responds(to: NSSelectorFromString("inputMaskImage")) {
                        let maskBack = variableBlur.value(forKey: "inputMaskImage") as Any
                        log("  inputMaskImage readback: \(type(of: maskBack))")
                    } else {
                        log("  inputMaskImage: does not respond to selector")
                    }
                }

                // Apply to a real visual effect view and inspect
                log("")
                log("--- Applied to UIVisualEffectView ---")
                let vfx = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
                vfx.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
                vfx.layoutIfNeeded()

                if let backdrop = vfx.subviews.first {
                    let beforeFilters = (backdrop.value(forKeyPath: "filters") as? [NSObject]) ?? []
                    log("Before: \(beforeFilters.count) filters")
                    for f in beforeFilters {
                        log("  \(f.value(forKeyPath: "filterType") as? String ?? "?")")
                    }

                    // Replace filters with variableBlur
                    backdrop.layer.filters = [variableBlur]

                    let afterFilters = backdrop.layer.value(forKeyPath: "filters") as? [NSObject] ?? []
                    log("After replacing: \(afterFilters.count) layer.filters")
                    for f in afterFilters {
                        var ft = "?"
                        for tryKey in ["filterType", "type", "name"] {
                            if f.responds(to: NSSelectorFromString(tryKey)),
                               let val = f.value(forKeyPath: tryKey) as? String
                            {
                                ft = val
                                break
                            }
                        }
                        log("  \(ft)")
                    }

                    // Check backdrop.filters (KVC) vs layer.filters
                    if backdrop.responds(to: NSSelectorFromString("filters")) {
                        let kvcFilters = (backdrop.value(forKeyPath: "filters") as? [NSObject]) ?? []
                        log("KVC filters after: \(kvcFilters.count)")
                        for f in kvcFilters {
                            let ft = f.responds(to: NSSelectorFromString("filterType"))
                                ? f.value(forKeyPath: "filterType") as? String ?? "?" : "?"
                            log("  \(ft)")
                        }
                    }
                }
            }

            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Checkerboard Background

    struct CheckerboardView: View {
        let tileSize: CGFloat = 10

        var body: some View {
            Canvas { context, size in
                let cols = Int(ceil(size.width / tileSize))
                let rows = Int(ceil(size.height / tileSize))
                for row in 0..<rows {
                    for col in 0..<cols {
                        let isLight = (row + col) % 2 == 0
                        context.fill(
                            Path(CGRect(
                                x: CGFloat(col) * tileSize,
                                y: CGFloat(row) * tileSize,
                                width: tileSize,
                                height: tileSize
                            )),
                            with: .color(isLight ? Color(.systemGray5) : Color(.systemGray3))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Shared Helpers

    private func sliderRow(
        _ label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>
    ) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 110, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.1f", value.wrappedValue))
                .monospacedDigit()
                .font(.caption)
                .frame(width: 40, alignment: .trailing)
        }
    }

#elseif canImport(AppKit)
    import AppKit

    struct EffectsLabView: View {
        @State private var inspectorOutput = "Tap 'Inspect' to dump macOS filter info"

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("macOS Effects Lab")
                        .font(.title2.bold())

                    Text("Variable blur and alpha mask are iOS-only. Use this tab to inspect macOS CABackdropLayer filters.")
                        .foregroundStyle(.secondary)

                    Button("Inspect macOS Filters") {
                        inspectorOutput = inspectMacOSFilters()
                    }
                    .buttonStyle(.borderedProminent)

                    Text(inspectorOutput)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        }

        @MainActor
        private func inspectMacOSFilters() -> String {
            var lines: [String] = []
            func log(_ s: String) { lines.append(s) }

            log("=== macOS CABackdropLayer Filters ===")
            log("")

            for material: (String, NSVisualEffectView.Material) in [
                ("popover", .popover),
                ("titlebar", .titlebar),
                ("sheet", .sheet),
                ("hudWindow", .hudWindow),
                ("headerView", .headerView),
                ("underWindowBackground", .underWindowBackground),
            ] {
                let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
                view.material = material.1
                view.blendingMode = .behindWindow
                view.state = .active
                view.wantsLayer = true
                view.layoutSubtreeIfNeeded()
                view.displayIfNeeded()

                log("--- \(material.0) ---")

                // Find backdrop layer
                func findBackdrop(in layer: CALayer) -> CALayer? {
                    if NSStringFromClass(type(of: layer)) == "CABackdropLayer" { return layer }
                    return layer.sublayers?.lazy.compactMap { findBackdrop(in: $0) }.first
                }

                guard let rootLayer = view.layer,
                      let backdrop = findBackdrop(in: rootLayer)
                else {
                    log("  backdrop: NOT FOUND")
                    log("")
                    continue
                }

                log("  backdrop: \(NSStringFromClass(type(of: backdrop)))")

                if let filters = backdrop.filters as? [NSObject] {
                    for filter in filters {
                        var filterType = "unknown"
                        for tryKey in ["filterType", "type", "name"] {
                            if filter.responds(to: NSSelectorFromString(tryKey)),
                               let val = filter.value(forKeyPath: tryKey) as? String
                            {
                                filterType = val
                                break
                            }
                        }

                        var details: [String] = []
                        for key in ["inputRadius", "inputAmount", "inputColor", "inputNormalizeEdges"] {
                            if filter.responds(to: NSSelectorFromString(key)) {
                                let val = filter.value(forKey: key) as Any
                                details.append("\(key)=\(val)")
                            }
                        }
                        log("  filter: \(filterType) [\(details.joined(separator: ", "))]")
                    }
                }

                if backdrop.responds(to: NSSelectorFromString("scale")) {
                    log("  scale: \(backdrop.value(forKey: "scale") as Any)")
                }

                log("")
            }

            return lines.joined(separator: "\n")
        }
    }
#endif
