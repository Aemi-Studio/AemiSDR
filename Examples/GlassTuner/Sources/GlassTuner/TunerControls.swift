import SwiftUI

struct TunerControls: View {
    @Binding var settings: TunerSettings

    var body: some View {
        Form {
            Section("Scene") {
                Picker("Background", selection: $settings.pattern) {
                    ForEach(TunerPattern.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                }
                Toggle("Dark appearance", isOn: $settings.darkAppearance)
            }
            Section("Geometry — points") {
                Picker("Shape", selection: $settings.shape) {
                    ForEach(TunerShape.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                TunerSlider("Width / diameter", value: $settings.width, range: 40...380)
                if settings.shape != .circle { TunerSlider("Height", value: $settings.height, range: 40...400) }
                if settings.shape == .rounded {
                    Toggle("Continuous corners", isOn: $settings.continuous)
                    Toggle("Per-corner radii", isOn: $settings.perCorner)
                    if settings.perCorner {
                        TunerSlider("Top left", value: $settings.topLeft, range: 0...180)
                        TunerSlider("Top right", value: $settings.topRight, range: 0...180)
                        TunerSlider("Bottom left", value: $settings.bottomLeft, range: 0...180)
                        TunerSlider("Bottom right", value: $settings.bottomRight, range: 0...180)
                    } else {
                        TunerSlider("Corner radius", value: $settings.radius, range: 0...180)
                    }
                }
            }
            Section("Blur — preferred look") {
                Picker("Kernel", selection: $settings.blur) {
                    ForEach(TunerBlur.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                TunerSlider("Blur amount", value: $settings.blurScale, range: 0...4)
                if settings.blur == .gaussian {
                    TunerSlider("Gaussian σ — pt", value: $settings.gaussianRadius, range: 0...8)
                }
                TunerSlider("Clearer edges", value: $settings.edgeClarity, range: 0...1)
                TunerSlider("Ramp depth — pt", value: $settings.rampDepth, range: 0...40)
                TunerSlider("Ramp curve", value: $settings.rampCurve, range: 0.1...8)
                Text("Three-component kernels use their sharpest component for clear edges.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Refraction — points") {
                Toggle("Refraction", isOn: $settings.refraction)
                Toggle("Circular-arc profile", isOn: $settings.arc)
                TunerSlider("Edge pull", value: $settings.pull, range: 0...100)
                TunerSlider("Pull height", value: $settings.pullHeight, range: 0.1...60)
                let effective = settings.configuration.rim.constrained(
                    to: settings.size, chromatic: settings.aberration)
                Text(
                    "Effective pull: \(effective.edgeDepth, format: .number.precision(.fractionLength(2))) pt; height: \(effective.edgeFalloff, format: .number.precision(.fractionLength(2))) pt"
                )
                .font(.caption).foregroundStyle(.secondary)
                if !settings.arc {
                    TunerSlider("Gaussian pull", value: $settings.gaussianPull, range: 0...30)
                    TunerSlider("Gaussian width", value: $settings.gaussianWidth, range: 0.1...40)
                }
            }
            Section("Veil, light and colour") {
                Toggle("Veil", isOn: $settings.veil)
                TunerSlider("Veil strength", value: $settings.veilStrength, range: 0...0.5)
                TunerSlider("Veil red", value: $settings.veilRed, range: 0...1)
                TunerSlider("Veil green", value: $settings.veilGreen, range: 0...1)
                TunerSlider("Veil blue", value: $settings.veilBlue, range: 0...1)
                TunerSlider("Inner rim light", value: $settings.innerLight, range: 0...2)
                TunerSlider("Outer dark ring", value: $settings.outerRing, range: 0...2)
                TunerSlider("Chromatic aberration", value: $settings.aberration, range: 0...0.2)
                Text("Aberration is optional and off by default; it is not a native-clear fidelity control.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
    }
}

private struct TunerSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>

    init(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>) {
        self.title = title
        _value = value
        self.range = range
    }

    var body: some View {
        VStack(spacing: 2) {
            LabeledContent(title) {
                Text(value, format: .number.precision(.fractionLength(2))).monospacedDigit()
            }
            Slider(value: $value, in: range) { Text(title) }.labelsHidden()
        }
    }
}
