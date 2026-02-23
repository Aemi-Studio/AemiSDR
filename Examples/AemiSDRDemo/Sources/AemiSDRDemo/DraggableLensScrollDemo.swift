import AemiSDR
import SwiftUI

#if os(iOS)
    import UIKit

    struct LiquidSurfaceDemo: View {
        private enum Preset: String, CaseIterable {
            case subtle
            case regular
            case clear

            var configuration: LiquidGlassConfiguration {
                switch self {
                case .subtle:
                    return .subtle
                case .regular:
                    return .regular
                case .clear:
                    return .clear
                }
            }

            var label: String { rawValue.capitalized }
        }

        @State private var preset: Preset = .regular
        @State private var strength: Double = 0.35
        @State private var lensCurvature: Double = 0.55
        @State private var chromaticAmount: Double = 0.6
        @State private var material: LiquidLensMaterial = .crownGlass
        @State private var falloff: LiquidLensFalloff = .easeInOut
        @State private var falloffLength: Double = 1.0
        @State private var falloffIntensity: Double = 0.45
        @State private var useRadialDirection = true
        @State private var continuousCapture = true
        @State private var refreshRate: Double = 30
        @State private var captureScale: Double = 1.0
        @State private var headerCornerRadius: Double = 16
        @State private var showSettings = false

        private var configuration: LiquidGlassConfiguration {
            LiquidGlassConfiguration(
                strength: Float(strength),
                lensCurvature: Float(lensCurvature),
                cornerRadius: nil,
                falloff: falloff,
                falloffLength: Float(falloffLength),
                falloffIntensity: Float(falloffIntensity),
                chromaticAmount: Float(chromaticAmount),
                material: material,
                useRadialDirection: useRadialDirection,
                continuousCapture: continuousCapture,
                refreshRate: Int(refreshRate.rounded()),
                captureScale: CGFloat(captureScale)
            )
        }

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

        private var topSurface: some View {
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
            .liquidBackground(
                configuration,
                shape: RoundedRectangle(cornerRadius: headerCornerRadius, style: .continuous),
                cornerRadius: .points(Float(headerCornerRadius))
            )
            .clipShape(RoundedRectangle(cornerRadius: headerCornerRadius, style: .continuous))
        }

        private var bottomSurface: some View {
            HStack(spacing: 20) {
                Button {} label: {
                    Image(systemName: "house.fill")
                }
                Button {} label: {
                    Image(systemName: "magnifyingglass")
                }
                Button {} label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                Button {} label: {
                    Image(systemName: "heart.fill")
                }
                Button {} label: {
                    Image(systemName: "person.fill")
                }
            }
            .font(.title3)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .liquid(configuration, shape: Capsule())
            .clipShape(Capsule())
        }

        private var settingsSheet: some View {
            NavigationStack {
                List {
                    NavigationLink("Liquid Surface Settings") {
                        liquidSettings
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }

        private var liquidSettings: some View {
            Form {
                Section("Preset") {
                    Picker("Preset", selection: $preset) {
                        ForEach(Preset.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }

                    Button("Reset To Preset") {
                        applyPreset(preset)
                    }
                }

                Section("Layout") {
                    sliderRow("Header Radius", value: $headerCornerRadius, range: 0...48, format: "%.0f")
                }

                Section("Optics") {
                    sliderRow("Strength", value: $strength, range: 0...1)
                    sliderRow("Curvature", value: $lensCurvature, range: 0...1)
                    sliderRow("Chromatic", value: $chromaticAmount, range: 0...2)

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
                    Toggle("Extra Radial Emphasis", isOn: $useRadialDirection)
                    Toggle("Continuous Capture", isOn: $continuousCapture)

                    sliderRow("Refresh", value: $refreshRate, range: 1...120, format: "%.0f fps")
                        .disabled(!continuousCapture)
                        .opacity(continuousCapture ? 1 : 0.5)
                    sliderRow("Scale", value: $captureScale, range: 0.25...1.0, format: "%.2fx")
                }
            }
            .navigationTitle("Liquid Surface")
            .navigationBarTitleDisplayMode(.inline)
        }

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
            case .crownGlass: return "Crown Glass"
            case .flintGlass: return "Flint Glass"
            case .water: return "Water"
            case .acrylic: return "Acrylic"
            case .diamond: return "Diamond"
            }
        }

        private func falloffTitle(_ falloff: LiquidLensFalloff) -> String {
            switch falloff {
            case .linear: return "Linear"
            case .easeIn: return "Ease In"
            case .easeOut: return "Ease Out"
            case .easeInOut: return "Ease In-Out"
            case .cubic: return "Cubic"
            case .exponential: return "Exponential"
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
            useRadialDirection = value.useRadialDirection
            continuousCapture = value.continuousCapture
            refreshRate = Double(value.refreshRate)
            captureScale = Double(value.captureScale)
        }
    }
#endif
