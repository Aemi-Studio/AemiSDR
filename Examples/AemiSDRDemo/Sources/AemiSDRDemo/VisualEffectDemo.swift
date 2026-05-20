import AemiSDR
import SwiftUI

#if os(iOS)
    struct VisualEffectDemo: View {
        enum EffectPreset: String, CaseIterable, Identifiable {
            case ultraThin, thin, regular, thick, chrome, light, dark

            var id: Self { self }
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

        @State private var preset: EffectPreset = .regular
        @State private var customMode = false

        // Core
        @State private var blurRadius: CGFloat = 30
        @State private var scale: CGFloat = 1.0
        @State private var zoom: CGFloat = 0

        // Color tint
        @State private var useColorTint: Bool = false
        @State private var colorTint: Color = .white
        @State private var colorTintAlpha: CGFloat = 0.2

        // Saturation
        @State private var saturationDeltaFactor: CGFloat = 1.8

        // Grayscale tint
        @State private var grayscaleTintLevel: CGFloat = 0
        @State private var grayscaleTintAlpha: CGFloat = 0
        @State private var lightenGrayscaleWithSourceOver: Bool = false

        // Color burn tint
        @State private var colorBurnTintLevel: CGFloat = 0
        @State private var colorBurnTintAlpha: CGFloat = 0
        @State private var darkenWithSourceOver: Bool = false

        // Darkening tint
        @State private var darkeningTintAlpha: CGFloat = 0
        @State private var darkeningTintHue: CGFloat = 0
        @State private var darkeningTintSaturation: CGFloat = 0

        @State private var showSettings = false

        private var configuration: BackdropBlurConfiguration {
            if customMode {
                BackdropBlurConfiguration(
                    colorTint: useColorTint ? colorTint : nil,
                    colorTintAlpha: useColorTint ? colorTintAlpha : 0,
                    blurRadius: blurRadius,
                    scale: scale,
                    saturationDeltaFactor: saturationDeltaFactor,
                    grayscaleTintLevel: grayscaleTintLevel,
                    grayscaleTintAlpha: grayscaleTintAlpha,
                    colorBurnTintLevel: colorBurnTintLevel,
                    colorBurnTintAlpha: colorBurnTintAlpha,
                    darkeningTintAlpha: darkeningTintAlpha,
                    darkeningTintHue: darkeningTintHue,
                    darkeningTintSaturation: darkeningTintSaturation,
                    zoom: zoom,
                    lightenGrayscaleWithSourceOver: lightenGrayscaleWithSourceOver,
                    darkenWithSourceOver: darkenWithSourceOver
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
                        headerBar
                        Spacer()
                        actionBar
                    }
                    .padding()
                }
                .navigationTitle("Backdrop Blur")
                .demoSettingsToolbar(isPresented: $showSettings)
                .demoSettingsSheet(isPresented: $showSettings) {
                    settingsSheet
                }
                .onChange(of: preset) { _, value in
                    if !customMode {
                        applyPreset(value)
                    }
                }
                .onChange(of: customMode) { _, newValue in
                    if newValue {
                        // When entering custom mode, seed sliders from the current preset
                        // so the user can tweak from a known baseline.
                        applyPreset(preset)
                    }
                }
            }
        }

        private var headerBar: some View {
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
            .backdropBlurBackground(configuration, ignoreSafeArea: false)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }

        private var actionBar: some View {
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
            .backdropBlurBackground(configuration, ignoreSafeArea: false)
            .clipShape(Capsule())
        }

        private var settingsSheet: some View {
            Form {
                Section("Mode") {
                    Picker("Preset", selection: $preset) {
                        ForEach(EffectPreset.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .disabled(customMode)

                    Toggle("Custom Mode", isOn: $customMode)
                }

                if customMode {
                    Section("Core") {
                        ParameterSlider("Blur Radius", value: $blurRadius, range: 0...60, format: "%.1f pt")
                        ParameterSlider("Scale", value: $scale, range: 0.25...3.0, format: "%.2fx")
                        ParameterSlider("Zoom", value: $zoom, range: -1...1, format: "%+.2f")
                        ParameterSlider("Saturation", value: $saturationDeltaFactor, range: 0...3, format: "%.2f")
                    }

                    Section("Color Tint") {
                        Toggle("Enable", isOn: $useColorTint)
                        if useColorTint {
                            ColorPicker("Tint", selection: $colorTint, supportsOpacity: false)
                            ParameterSlider("Alpha", value: $colorTintAlpha, range: 0...1)
                        }
                    }

                    Section("Grayscale Tint") {
                        ParameterSlider("Level", value: $grayscaleTintLevel, range: 0...1)
                        ParameterSlider("Alpha", value: $grayscaleTintAlpha, range: 0...1)
                        Toggle("Source-over Lighten", isOn: $lightenGrayscaleWithSourceOver)
                    }

                    Section("Color Burn Tint") {
                        ParameterSlider("Level", value: $colorBurnTintLevel, range: 0...1)
                        ParameterSlider("Alpha", value: $colorBurnTintAlpha, range: 0...1)
                        Toggle("Source-over Darken", isOn: $darkenWithSourceOver)
                    }

                    Section("Darkening Tint") {
                        ParameterSlider("Alpha", value: $darkeningTintAlpha, range: 0...1)
                        ParameterSlider("Hue", value: $darkeningTintHue, range: 0...1)
                        ParameterSlider("Saturation", value: $darkeningTintSaturation, range: 0...1)
                    }

                    Section {
                        Button("Reset To Preset", role: .destructive) {
                            applyPreset(preset)
                        }
                    } footer: {
                        Text(
                            "All tint layers and the scale/zoom inputs map to the private `_UICustomBlurEffect` properties (iOS) / `CABackdropLayer` filters (macOS). Grayscale, color-burn, and darkening tints stack — each is its own layer on top of the blur."
                        )
                        .font(.caption2)
                    }
                }
            }
        }

        private func applyPreset(_ preset: EffectPreset) {
            let config = preset.configuration
            blurRadius = config.blurRadius
            scale = config.scale
            zoom = config.zoom
            useColorTint = config.colorTint != nil
            if let tint = config.colorTint {
                colorTint = tint
            }
            colorTintAlpha = config.colorTintAlpha
            saturationDeltaFactor = config.saturationDeltaFactor
            grayscaleTintLevel = config.grayscaleTintLevel
            grayscaleTintAlpha = config.grayscaleTintAlpha
            lightenGrayscaleWithSourceOver = config.lightenGrayscaleWithSourceOver
            colorBurnTintLevel = config.colorBurnTintLevel
            colorBurnTintAlpha = config.colorBurnTintAlpha
            darkenWithSourceOver = config.darkenWithSourceOver
            darkeningTintAlpha = config.darkeningTintAlpha
            darkeningTintHue = config.darkeningTintHue
            darkeningTintSaturation = config.darkeningTintSaturation
        }
    }
#else
    struct VisualEffectDemo: View {
        var body: some View {
            Text("Backdrop Blur demo is iOS-only.")
                .foregroundStyle(.secondary)
                .navigationTitle("Backdrop Blur")
        }
    }
#endif
