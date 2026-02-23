import AemiSDR
import SwiftUI

struct VisualEffectDemo: View {
    enum EffectPreset: String, CaseIterable {
        case ultraThin, thin, regular, thick, chrome, light, dark

        var label: String { rawValue.capitalized }

        var configuration: BackdropBlurConfiguration {
            switch self {
            case .ultraThin:
                BackdropBlurConfiguration(blurRadius: 10, saturationDeltaFactor: 1.8)
            case .thin:
                BackdropBlurConfiguration(blurRadius: 20, saturationDeltaFactor: 1.8)
            case .regular:
                BackdropBlurConfiguration(blurRadius: 30, saturationDeltaFactor: 1.8)
            case .thick:
                BackdropBlurConfiguration(blurRadius: 50, saturationDeltaFactor: 1.8)
            case .chrome:
                BackdropBlurConfiguration(
                    blurRadius: 10,
                    saturationDeltaFactor: 2.5,
                    grayscaleTintLevel: 0.3,
                    grayscaleTintAlpha: 0.2
                )
            case .light:
                BackdropBlurConfiguration(
                    blurRadius: 30,
                    saturationDeltaFactor: 1.8,
                    grayscaleTintLevel: 0.9,
                    grayscaleTintAlpha: 0.4
                )
            case .dark:
                BackdropBlurConfiguration(
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

    private var configuration: BackdropBlurConfiguration {
        if customMode {
            BackdropBlurConfiguration(
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
            ZStack {
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
                    .backdropBlurBackground(configuration, ignoreSafeArea: false)
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
                    .backdropBlurBackground(configuration, ignoreSafeArea: false)
                    .clipShape(Capsule())
                }
                .padding()
            }
            .navigationTitle("Backdrop Blur")
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
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            List {
                NavigationLink("Backdrop Blur Settings") {
                    backdropSettings
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var backdropSettings: some View {
        Form {
            Section("Preset") {
                Picker("Preset", selection: $preset) {
                    ForEach(EffectPreset.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .disabled(customMode)

                Toggle("Custom Mode", isOn: $customMode)
            }

            if customMode {
                Section("Custom") {
                    parameterSlider("Blur Radius", value: $blurRadius, range: 0...50, format: "%.1f")

                    Picker("Color Tint", selection: $tintColor) {
                        ForEach(TintColor.allCases, id: \.self) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
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
        }
        .navigationTitle("Backdrop Blur")
        .navigationBarTitleDisplayMode(.inline)
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
