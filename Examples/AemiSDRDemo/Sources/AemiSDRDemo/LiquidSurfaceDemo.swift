import AemiSDR
import SwiftUI

#if os(iOS)
    import UIKit

    struct LiquidSurfaceDemo: View {
        // MARK: - Enums

        private enum Preset: String, CaseIterable {
            case subtle, regular, clear

            var configuration: LiquidGlassConfiguration {
                switch self {
                case .subtle: .subtle
                case .regular: .regular
                case .clear: .clear
                }
            }

            var label: String { rawValue.capitalized }
        }

        private enum HeaderBlurType: String, CaseIterable {
            case backdrop = "Backdrop"
            case variableBlur = "Variable"
            case swiftUI = "SwiftUI"
        }

        private enum VariableBlurMode: String, CaseIterable {
            case uniform = "Uniform"
            case edgeBlur = "Edge"
            case centerBlur = "Center"
        }

        private enum EdgeSelection: String, CaseIterable {
            case top, bottom, both

            var edgeSet: VerticalEdge.Set {
                switch self {
                case .top: .top
                case .bottom: .bottom
                case .both: .all
                }
            }
        }

        // MARK: - Liquid Glass State

        @State private var preset: Preset = .regular
        @State private var strength: Double = 0.5
        @State private var lensCurvature: Double = 1.0
        @State private var chromaticAmount: Double = 15
        @State private var material: LiquidLensMaterial = .acrylic
        @State private var falloff: LiquidLensFalloff = .exponential
        @State private var falloffLength: Double = 1.0
        @State private var falloffIntensity: Double = 1.0
        @State private var continuousCapture = true
        @State private var refreshRate: Double = 40
        @State private var captureScale: Double = 0.5
        @State private var headerCornerRadius: Double = 16

        // MARK: - Header Blur State

        @State private var headerBlurEnabled = true
        @State private var headerBlurType: HeaderBlurType = .backdrop

        // Backdrop blur (sits below the lens to provide an opaque base
        // layer — without it the lens output is transparent in non-active
        // regions and the un-refracted scene shows through, doubling the
        // visible content). Default to a pure blur (no colour tint).
        @State private var bdBlurRadius: Double = 24
        @State private var bdColorTint: Color = .white
        @State private var bdColorTintAlpha: Double = 0
        @State private var bdSaturation: Double = 1.6
        @State private var bdScale: Double = 1.0

        // Variable blur
        @State private var vbMode: VariableBlurMode = .uniform
        @State private var vbBlurRadius: Double = 20
        @State private var vbHeight: Double = 100
        @State private var vbFullHeight = true
        @State private var vbEdges: EdgeSelection = .both
        @State private var vbTransition: TransitionAlgorithm = .eased

        // SwiftUI blur
        @State private var suiBlurRadius: Double = 10

        @State private var showSettings = false

        // MARK: - Computed Configuration

        private var liquidConfig: LiquidGlassConfiguration {
            LiquidGlassConfiguration(
                strength: Float(strength),
                lensCurvature: Float(lensCurvature),
                cornerRadius: nil,
                falloff: falloff,
                falloffLength: Float(falloffLength),
                falloffIntensity: Float(falloffIntensity),
                chromaticAmount: Float(chromaticAmount),
                material: material,
                continuousCapture: continuousCapture,
                refreshRate: Int(refreshRate.rounded()),
                captureScale: CGFloat(captureScale)
            )
        }

        private var backdropConfig: BackdropBlurConfiguration {
            BackdropBlurConfiguration(
                colorTint: bdColorTint,
                colorTintAlpha: bdColorTintAlpha,
                blurRadius: bdBlurRadius,
                scale: bdScale,
                saturationDeltaFactor: bdSaturation
            )
        }

        // MARK: - Body

        var body: some View {
            ZStack {
                SharedScrollContent()

                VStack {
                    topSurface
                    Spacer()
                    bottomSurface
                }
                .padding()
            }
            .navigationTitle("Liquid Surface")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(
                            systemName: showSettings
                                ? "slider.horizontal.2.square.on.square"
                                : "slider.horizontal.2.square"
                        )
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
            .onChange(of: preset) { _, value in
                applyPreset(value)
            }
        }

        // MARK: - Surfaces

        private var topSurface: some View {
            headerContent
                .liquidBackground(
                    liquidConfig,
                    shape: RoundedRectangle(cornerRadius: headerCornerRadius, style: .continuous),
                    cornerRadius: .points(Float(headerCornerRadius))
                )
                .background { headerBlurLayer }
                .clipShape(RoundedRectangle(cornerRadius: headerCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: headerCornerRadius, style: .continuous)
                        .strokeBorder(.black.opacity(0.2), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        }

        private var headerContent: some View {
            HStack {
                Image(systemName: "sparkles")
                Text("Floating Header")
                    .font(.headline)
                Spacer()
                Button {} label: {
                    Image(systemName: "bell.fill")
                }
                Button {} label: {
                    Image(systemName: "person.circle")
                }
            }
            .padding()
        }

        @ViewBuilder
        private var headerBlurLayer: some View {
            if headerBlurEnabled {
                switch headerBlurType {
                case .backdrop:
                    BackdropBlurView(configuration: backdropConfig)
                case .variableBlur:
                    variableBlurLayer
                case .swiftUI:
                    Rectangle().fill(.ultraThinMaterial)
                        .blur(radius: suiBlurRadius)
                }
            }
        }

        @ViewBuilder
        private var variableBlurLayer: some View {
            let height = vbFullHeight ? CGFloat.infinity : vbHeight
            switch vbMode {
            case .uniform:
                VariableBlurView(maxBlurRadius: vbBlurRadius, type: .uniform)
            case .edgeBlur:
                let hasTop = vbEdges.edgeSet.contains(.top)
                let hasBottom = vbEdges.edgeSet.contains(.bottom)
                VStack(spacing: 0) {
                    if hasTop {
                        let topType: MaskType = vbTransition == .linear
                            ? .linearTopToBottom : .easeInTopToBottom
                        VariableBlurView(maxBlurRadius: vbBlurRadius, type: topType)
                            .frame(height: height == .infinity ? nil : height)
                            .frame(maxHeight: height == .infinity ? .infinity : nil)
                    }
                    if hasTop && hasBottom || height != .infinity { Spacer() }
                    if hasBottom {
                        let bottomType: MaskType = vbTransition == .linear
                            ? .linearBottomToTop : .easeInBottomToTop
                        VariableBlurView(maxBlurRadius: vbBlurRadius, type: bottomType)
                            .frame(height: height == .infinity ? nil : height)
                            .frame(maxHeight: height == .infinity ? .infinity : nil)
                    }
                }
            case .centerBlur:
                VStack(spacing: 0) {
                    if height != .infinity { Spacer() }
                    VariableBlurView(maxBlurRadius: vbBlurRadius, type: .easeInCenterVertical)
                        .frame(height: height == .infinity ? nil : height)
                        .frame(maxHeight: height == .infinity ? .infinity : nil)
                    if height != .infinity { Spacer() }
                }
            }
        }

        private var bottomSurface: some View {
            HStack(spacing: 20) {
                Button {} label: { Image(systemName: "house.fill") }
                Button {} label: { Image(systemName: "magnifyingglass") }
                Button {} label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                Button {} label: { Image(systemName: "heart.fill") }
                Button {} label: { Image(systemName: "person.fill") }
            }
            .font(.title3)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .liquidBackground(liquidConfig, shape: Capsule())
            .background { headerBlurLayer }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.black.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        }

        // MARK: - Settings Sheet

        private var settingsSheet: some View {
            Form {
                Section("Preset") {
                    Picker("Preset", selection: $preset) {
                        ForEach(Preset.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    Button("Reset To Preset") { applyPreset(preset) }
                }

                Section("Layout") {
                    sliderRow("Header Radius", value: $headerCornerRadius, range: 0...48, format: "%.0f")
                }

                // MARK: Header Blur

                Section("Header Blur") {
                    Toggle("Enable Blur", isOn: $headerBlurEnabled)

                    if headerBlurEnabled {
                        Picker("Type", selection: $headerBlurType) {
                            ForEach(HeaderBlurType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch headerBlurType {
                        case .backdrop:
                            sliderRow("Radius", value: $bdBlurRadius, range: 0...40)
                            ColorPicker("Tint Color", selection: $bdColorTint, supportsOpacity: false)
                            sliderRow("Tint Alpha", value: $bdColorTintAlpha, range: 0...1)
                            sliderRow("Saturation", value: $bdSaturation, range: 0...3)
                            sliderRow("Scale", value: $bdScale, range: 0.1...3.0, format: "%.2fx")

                        case .variableBlur:
                            Picker("Mode", selection: $vbMode) {
                                ForEach(VariableBlurMode.allCases, id: \.self) { m in
                                    Text(m.rawValue).tag(m)
                                }
                            }
                            .pickerStyle(.segmented)

                            sliderRow("Radius", value: $vbBlurRadius, range: 1...40)

                            if vbMode != .uniform {
                                Toggle("Full Height", isOn: $vbFullHeight)
                                if !vbFullHeight {
                                    sliderRow("Height", value: $vbHeight, range: 20...200, format: "%.0f pt")
                                }
                            }

                            if vbMode == .edgeBlur {
                                Picker("Edges", selection: $vbEdges) {
                                    Text("Top").tag(EdgeSelection.top)
                                    Text("Bottom").tag(EdgeSelection.bottom)
                                    Text("Both").tag(EdgeSelection.both)
                                }
                                Picker("Transition", selection: $vbTransition) {
                                    Text("Linear").tag(TransitionAlgorithm.linear)
                                    Text("Eased").tag(TransitionAlgorithm.eased)
                                }
                            }

                        case .swiftUI:
                            sliderRow("Radius", value: $suiBlurRadius, range: 0...40)
                        }
                    }
                }

                // MARK: Optics

                Section("Optics") {
                    sliderRow("Strength", value: $strength, range: 0...1)
                    sliderRow("Curvature", value: $lensCurvature, range: 0...1)
                    sliderRow("Chromatic", value: $chromaticAmount, range: 0...30)

                    Picker("Material", selection: $material) {
                        ForEach(LiquidLensMaterial.allCases, id: \.self) { value in
                            Text(materialTitle(value)).tag(value)
                        }
                    }
                }

                Section("Falloff") {
                    Picker("Curve", selection: $falloff) {
                        ForEach(LiquidLensFalloff.allCases, id: \.self) { value in
                            Text(falloffTitle(value)).tag(value)
                        }
                    }
                    sliderRow("Length", value: $falloffLength, range: 0.01...1.0)
                    sliderRow("Intensity", value: $falloffIntensity, range: 0...1)
                }

                Section("Capture") {
                    Toggle("Continuous Capture", isOn: $continuousCapture)

                    sliderRow("Refresh", value: $refreshRate, range: 1...120, format: "%.0f fps")
                        .disabled(!continuousCapture)
                        .opacity(continuousCapture ? 1 : 0.5)
                    sliderRow("Scale", value: $captureScale, range: 0.25...1.0, format: "%.2fx")
                }
            }
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
            .presentationBackgroundInteraction(.enabled)
        }

        // MARK: - Helpers

        private func sliderRow(
            _ label: String,
            value: Binding<Double>,
            range: ClosedRange<Double>,
            format: String = "%.2f"
        ) -> some View {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption)
                    .frame(width: 80, alignment: .leading)
                Slider(value: value, in: range)
                Text(String(format: format, value.wrappedValue))
                    .monospacedDigit()
                    .font(.caption2)
                    .frame(width: 50, alignment: .trailing)
            }
        }

        private func materialTitle(_ material: LiquidLensMaterial) -> String {
            switch material {
            case .crownGlass: "Crown Glass"
            case .flintGlass: "Flint Glass"
            case .water: "Water"
            case .acrylic: "Acrylic"
            case .diamond: "Diamond"
            }
        }

        private func falloffTitle(_ falloff: LiquidLensFalloff) -> String {
            switch falloff {
            case .linear: "Linear"
            case .easeIn: "Ease In"
            case .easeOut: "Ease Out"
            case .easeInOut: "Ease In-Out"
            case .cubic: "Cubic"
            case .exponential: "Exponential"
            }
        }

        private func applyPreset(_ preset: Preset) {
            let value = preset.configuration
            strength = Double(value.strength)
            lensCurvature = Double(value.lensCurvature)
            chromaticAmount = Double(value.chromaticAmount)
            material = value.material
            falloff = value.falloff
            falloffLength = Double(value.falloffLength)
            falloffIntensity = Double(value.falloffIntensity)
            continuousCapture = value.continuousCapture
            refreshRate = Double(value.refreshRate)
            captureScale = Double(value.captureScale)
        }
    }
#endif
