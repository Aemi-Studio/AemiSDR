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
        @State private var refreshRate: Int = 40
        @State private var captureScale: Double = 0.5
        @State private var forceCaptureEveryFrame = true
        @State private var headerCornerRadius: Double = 16

        // Physical fidelity opt-ins (function-constant gated in the shader).
        @State private var diagonalBand: Double = 6.0
        @State private var enableFresnel = false
        @State private var enableSpectral = false
        @State private var enableAspheric = false
        @State private var enableHighFidelityRefraction = false
        @State private var asphericK2: Double = 0.0
        @State private var asphericK4: Double = 0.0

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
                refreshRate: refreshRate,
                captureScale: CGFloat(captureScale),
                forceCaptureEveryFrame: forceCaptureEveryFrame,
                diagonalBand: Float(diagonalBand),
                asphericK2: Float(asphericK2),
                asphericK4: Float(asphericK4),
                enableFresnel: enableFresnel,
                enableSpectral: enableSpectral,
                enableAspheric: enableAspheric,
                enableHighFidelityRefraction: enableHighFidelityRefraction
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
            .demoSettingsToolbar(isPresented: $showSettings)
            .demoSettingsSheet(isPresented: $showSettings) {
                settingsSheet
            }
            .onChange(of: preset) { _, value in
                applyPreset(value)
            }
        }

        // MARK: - Surfaces

        private var topSurface: some View {
            headerContent
                .background { headerBlurLayer }
                .liquidBackground(
                    liquidConfig,
                    shape: RoundedRectangle(cornerRadius: headerCornerRadius, style: .continuous),
                    cornerRadius: .points(Float(headerCornerRadius))
                )
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
                Button {
                } label: {
                    Image(systemName: "bell.fill")
                }
                Button {
                } label: {
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
                        let topType: MaskType =
                            vbTransition == .linear
                            ? .linearTopToBottom : .easeInTopToBottom
                        VariableBlurView(maxBlurRadius: vbBlurRadius, type: topType)
                            .frame(height: height == .infinity ? nil : height)
                            .frame(maxHeight: height == .infinity ? .infinity : nil)
                    }
                    if hasTop && hasBottom || height != .infinity { Spacer() }
                    if hasBottom {
                        let bottomType: MaskType =
                            vbTransition == .linear
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
                Button {
                } label: {
                    Image(systemName: "house.fill")
                }
                Button {
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                Button {
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                Button {
                } label: {
                    Image(systemName: "heart.fill")
                }
                Button {
                } label: {
                    Image(systemName: "person.fill")
                }
            }
            .font(.title3)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background { headerBlurLayer }
            .liquidBackground(liquidConfig, shape: Capsule())
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
                    ParameterSlider("Header Radius", value: $headerCornerRadius, range: 0...48, format: "%.0f pt")
                }

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
                            ParameterSlider("Radius", value: $bdBlurRadius, range: 0...40)
                            ColorPicker("Tint Color", selection: $bdColorTint, supportsOpacity: false)
                            ParameterSlider("Tint Alpha", value: $bdColorTintAlpha, range: 0...1)
                            ParameterSlider("Saturation", value: $bdSaturation, range: 0...3)
                            ParameterSlider("Scale", value: $bdScale, range: 0.1...3.0, format: "%.2fx")

                        case .variableBlur:
                            Picker("Mode", selection: $vbMode) {
                                ForEach(VariableBlurMode.allCases, id: \.self) { m in
                                    Text(m.rawValue).tag(m)
                                }
                            }
                            .pickerStyle(.segmented)

                            ParameterSlider("Radius", value: $vbBlurRadius, range: 1...40)

                            if vbMode != .uniform {
                                Toggle("Full Height", isOn: $vbFullHeight)
                                if !vbFullHeight {
                                    ParameterSlider("Height", value: $vbHeight, range: 20...200, format: "%.0f pt")
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
                            ParameterSlider("Radius", value: $suiBlurRadius, range: 0...40)
                        }
                    }
                }

                Section("Optics") {
                    ParameterSlider("Strength", value: $strength, range: 0...1)
                    ParameterSlider("Curvature", value: $lensCurvature, range: 0...1)
                    ParameterSlider("Chromatic", value: $chromaticAmount, range: 0...30, format: "%.1f")

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
                    ParameterSlider("Length", value: $falloffLength, range: 0.01...1.0)
                    ParameterSlider("Intensity", value: $falloffIntensity, range: 0...1)
                }

                Section {
                    ParameterSlider(
                        "Diagonal Band",
                        value: $diagonalBand,
                        range: 0...32,
                        format: "%.1f pt"
                    )
                    Toggle("High-Fidelity Refraction", isOn: $enableHighFidelityRefraction)
                    Toggle("Fresnel Attenuation", isOn: $enableFresnel)
                    Toggle("Spectral Integration", isOn: $enableSpectral)
                    Toggle("Aspheric Profile", isOn: $enableAspheric)
                    if enableAspheric {
                        ParameterSlider("Asph K₂", value: $asphericK2, range: -1...1, format: "%+.2f")
                        ParameterSlider("Asph K₄", value: $asphericK4, range: -1...1, format: "%+.2f")
                    }
                } header: {
                    Text("Physical Fidelity")
                } footer: {
                    Text(
                        "Function-constant-gated pipeline variants. Each enabled toggle builds a specialized shader on first use. High-Fidelity Refraction uses per-fragment MSL refract() 3D form — strictly more accurate at large incidence angles but ~3× the chromatic-path ALU. Off by default for performance."
                    )
                    .font(.caption2)
                }

                Section {
                    Toggle("Continuous Capture", isOn: $continuousCapture)

                    ParameterIntSlider("Refresh Rate", value: $refreshRate, range: 1...120, unit: "fps")
                        .disabled(!continuousCapture)
                        .opacity(continuousCapture ? 1 : 0.5)

                    ParameterSlider("Capture Scale", value: $captureScale, range: 0.25...3.0, format: "%.2fx")

                    Toggle("Force Capture Every Frame", isOn: $forceCaptureEveryFrame)
                } header: {
                    Text("Capture")
                } footer: {
                    Text(
                        "Lower capture scale trades fidelity for performance. Disable “Force Capture Every Frame” to skip recaptures when the backdrop structure hasn’t changed."
                    )
                    .font(.caption2)
                }
            }
        }

        // MARK: - Helpers

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
            refreshRate = value.refreshRate
            captureScale = Double(value.captureScale)
            forceCaptureEveryFrame = value.forceCaptureEveryFrame
            diagonalBand = Double(value.diagonalBand)
            asphericK2 = Double(value.asphericK2)
            asphericK4 = Double(value.asphericK4)
            enableFresnel = value.enableFresnel
            enableSpectral = value.enableSpectral
            enableAspheric = value.enableAspheric
        }
    }
#endif
