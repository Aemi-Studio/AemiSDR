import AemiSDR
import SwiftUI

struct VisualEffectDemo: View {
    enum EffectPreset: String, CaseIterable {
        case ultraThin, thin, regular, thick, chrome, light, dark

        var label: String { rawValue.capitalized }

        var configuration: VisualEffectConfiguration {
            switch self {
            case .ultraThin:
                VisualEffectConfiguration(blurRadius: 10, saturationDeltaFactor: 1.8)
            case .thin:
                VisualEffectConfiguration(blurRadius: 20, saturationDeltaFactor: 1.8)
            case .regular:
                VisualEffectConfiguration(blurRadius: 30, saturationDeltaFactor: 1.8)
            case .thick:
                VisualEffectConfiguration(blurRadius: 50, saturationDeltaFactor: 1.8)
            case .chrome:
                VisualEffectConfiguration(
                    blurRadius: 10,
                    saturationDeltaFactor: 2.5,
                    grayscaleTintLevel: 0.3,
                    grayscaleTintAlpha: 0.2
                )
            case .light:
                VisualEffectConfiguration(
                    blurRadius: 30,
                    saturationDeltaFactor: 1.8,
                    grayscaleTintLevel: 0.9,
                    grayscaleTintAlpha: 0.4
                )
            case .dark:
                VisualEffectConfiguration(
                    blurRadius: 30,
                    saturationDeltaFactor: 1.8,
                    darkeningTintAlpha: 0.5
                )
            }
        }
    }

    enum TintColor: String, CaseIterable {
        case none, white, blue, purple, orange

        var color: Color? {
            switch self {
            case .none: nil
            case .white: .white
            case .blue: .blue
            case .purple: .purple
            case .orange: .orange
            }
        }
    }

    @State private var preset: EffectPreset = .regular
    @State private var customMode = false
    @State private var blurRadius: CGFloat = 30
    @State private var tintColor: TintColor = .none
    @State private var colorTintAlpha: CGFloat = 0.2
    @State private var saturationDeltaFactor: CGFloat = 1.8
    @State private var showSettings = false

    private var configuration: VisualEffectConfiguration {
        if customMode {
            VisualEffectConfiguration(
                blurRadius: blurRadius,
                colorTint: tintColor.color,
                colorTintAlpha: tintColor == .none ? 0 : colorTintAlpha,
                saturationDeltaFactor: saturationDeltaFactor
            )
        } else {
            preset.configuration
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                SharedScrollContent()

                VStack {
                    // Floating header bar
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
                    .visualEffectBackground(configuration, ignoreSafeArea: false)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Spacer()

                    // Floating action bar
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
                    .visualEffectBackground(configuration, ignoreSafeArea: false)
                    .clipShape(Capsule())
                }
                .padding()

                if showSettings {
                    settingsPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showSettings)
            .navigationTitle("Visual Effect")
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
        }
    }

    private var settingsPanel: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("Effect Settings")
                        .font(.headline)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Preset").font(.caption.bold())
                    Picker("Preset", selection: $preset) {
                        ForEach(EffectPreset.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .disabled(customMode)
                }

                Divider()

                Toggle("Custom Mode", isOn: $customMode)
                    .font(.subheadline)

                if customMode {
                    parameterSlider("Blur Radius", value: $blurRadius, range: 0...50, format: "%.1f")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Color Tint").font(.caption.bold())
                        Picker("Tint", selection: $tintColor) {
                            ForEach(TintColor.allCases, id: \.self) { t in
                                Text(t.rawValue.capitalized).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if tintColor != .none {
                        parameterSlider(
                            "Tint Alpha", value: $colorTintAlpha, range: 0...1, format: "%.2f"
                        )
                    }

                    parameterSlider(
                        "Saturation", value: $saturationDeltaFactor, range: 0...3, format: "%.2f"
                    )
                }
            }
            .padding()
        }
        .frame(maxHeight: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private func parameterSlider(
        _ label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
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
}
