import AemiSDR
import SwiftUI

#if os(iOS)
    import UIKit

    // MARK: - Navigation

    struct LiquidLensDemoView: View {
        var body: some View {
            NavigationStack {
                DraggableLensScrollDemo()
            }
        }
    }

    // MARK: - Draggable Lens over ScrollView

    private struct DraggableLensScrollDemo: View {
        // Drag state
        @State private var lensCenter: CGPoint = CGPoint(x: 200, y: 300)
        @State private var isDragging = false

        // Lens settings
        @State private var lensWidth: Float = 240
        @State private var lensHeight: Float = 240
        @State private var strength: Float = 0.5
        @State private var lensCurvature: Float = 0.6
        @State private var chromaticAmount: Float = 2.0
        @State private var material: LiquidLensMaterial = .flintGlass
        @State private var falloff: LiquidLensFalloff = .easeInOut
        @State private var falloffLength: Float = 1.0
        @State private var falloffIntensity: Float = 0.5
        @State private var lensCornerRadius: Float = 0
        @State private var cornerRadiusProportional = false

        // Quality / performance
        @State private var refreshRate: Float = 30
        @State private var captureScale: Float = 1.0

        // Panel
        @State private var showSettings = false

        // Demo content state
        @State private var toggleA = true
        @State private var toggleB = false
        @State private var sliderValue: Double = 0.6
        @State private var textInput = "Hello, Liquid Lens!"
        @State private var stepperValue = 3
        @State private var pickerSelection = 1

        private var outlineCornerRadius: Float {
            let hs = SIMD2(lensWidth / 2, lensHeight / 2)
            return cornerRadiusProportional
                ? (lensCornerRadius / 100) * max(hs.x, hs.y)
                : lensCornerRadius
        }

        var body: some View {
            ZStack(alignment: .bottom) {
                // Content + lens
                scrollContent
                    .liquidLens(
                        center: SIMD2(Float(lensCenter.x), Float(lensCenter.y)),
                        halfSize: SIMD2(lensWidth / 2, lensHeight / 2),
                        strength: strength,
                        lensCurvature: lensCurvature,
                        cornerRadius: cornerRadiusProportional
                            ? .proportional(lensCornerRadius / 100)
                            : .points(lensCornerRadius),
                        falloff: falloff,
                        falloffLength: falloffLength,
                        falloffIntensity: falloffIntensity,
                        chromaticAmount: chromaticAmount,
                        material: material,
                        continuousCapture: true,
                        refreshRate: Int(refreshRate),
                        captureScale: CGFloat(captureScale)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: CGFloat(outlineCornerRadius))
                            .stroke(
                                isDragging ? Color.white : Color.white.opacity(0.4),
                                lineWidth: isDragging ? 2 : 1
                            )
                            .frame(width: CGFloat(lensWidth), height: CGFloat(lensHeight))
                            .position(lensCenter)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDragging = true
                                        lensCenter = value.location
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )
                    }

                // Settings panel
                if showSettings {
                    settingsPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showSettings)
            .navigationTitle("Draggable Lens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: showSettings ? "slider.horizontal.2.square.on.square" : "slider.horizontal.2.square")
                    }
                }
            }
        }

        // MARK: - Scroll Content

        private var scrollContent: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Drag the lens around")
                            .font(.title2.bold())
                        Text("The lens follows your finger and distorts the live scroll content underneath. Tap the slider icon to customize.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        settingsRow { Toggle("Wi-Fi", isOn: $toggleA) }
                        Divider().padding(.leading, 16)
                        settingsRow { Toggle("Bluetooth", isOn: $toggleB) }
                        Divider().padding(.leading, 16)
                        settingsRow {
                            HStack {
                                Text("Brightness")
                                Slider(value: $sliderValue)
                            }
                        }
                        Divider().padding(.leading, 16)
                        settingsRow {
                            Stepper("Count: \(stepperValue)", value: $stepperValue, in: 0...10)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    TextField("Type something...", text: $textInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .padding(.horizontal)

                    Picker("Selection", selection: $pickerSelection) {
                        Text("First").tag(0)
                        Text("Second").tag(1)
                        Text("Third").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button("Primary") {}
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        Button("Secondary") {}
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        Button(role: .destructive) {} label: { Text("Delete") }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Physics-Based Rendering")
                            .font(.title2.bold())
                        Text("Sellmeier dispersion equations model wavelength-dependent refraction indices for 5 real optical materials. Each produces unique chromatic aberration patterns visible through the lens.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Label("Crown Glass", systemImage: "drop.circle.fill")
                                .foregroundStyle(.blue)
                            Label("Diamond", systemImage: "sparkles")
                                .foregroundStyle(.purple)
                            Label("Water", systemImage: "drop.fill")
                                .foregroundStyle(.cyan)
                        }
                        .font(.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    ForEach(0..<6) { i in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill([Color.red, .orange, .yellow, .green, .blue, .purple][i].gradient)
                                .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(["Ruby", "Amber", "Topaz", "Emerald", "Sapphire", "Amethyst"][i])
                                    .font(.headline)
                                Text("Optical material sample \(i + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Spacer(minLength: showSettings ? 340 : 100)
                }
                .padding(.vertical)
            }
        }

        // MARK: - Settings Panel

        private var settingsPanel: some View {
            ScrollView {
                VStack(spacing: 10) {
                    // Header
                    HStack {
                        Text("Lens Settings")
                            .font(.headline)
                        Spacer()
                        Button("Reset") { resetDefaults() }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }

                    // Lens geometry
                    lensSlider("Width", value: $lensWidth, range: 60...600)
                    lensSlider("Height", value: $lensHeight, range: 60...600)
                    lensSlider("Strength", value: $strength, range: 0...1)
                    lensSlider("Curvature", value: $lensCurvature, range: 0...1)
                    HStack(spacing: 6) {
                        Text("Corner R.")
                            .font(.caption)
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $cornerRadiusProportional) {
                            Text("pt").tag(false)
                            Text("%").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 70)
                        .onChange(of: cornerRadiusProportional) { _, isProportional in
                            // Convert current value when switching modes
                            let hs = SIMD2(lensWidth / 2, lensHeight / 2)
                            let maxHalf = max(hs.x, hs.y)
                            if isProportional {
                                lensCornerRadius = min((lensCornerRadius / maxHalf) * 100, 100)
                            } else {
                                lensCornerRadius = (lensCornerRadius / 100) * maxHalf
                            }
                        }
                    }
                    lensSlider(
                        cornerRadiusProportional ? "Rounding" : "Corner Radius",
                        value: $lensCornerRadius,
                        range: cornerRadiusProportional ? 0...100 : 0...200,
                        format: cornerRadiusProportional ? "%.0f%%" : "%.1f"
                    )

                    Divider()

                    // Material
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Material").font(.caption.bold())
                        Picker("Material", selection: $material) {
                            Text("Crown").tag(LiquidLensMaterial.crownGlass)
                            Text("Flint").tag(LiquidLensMaterial.flintGlass)
                            Text("Water").tag(LiquidLensMaterial.water)
                            Text("Acrylic").tag(LiquidLensMaterial.acrylic)
                            Text("Diamond").tag(LiquidLensMaterial.diamond)
                        }
                        .pickerStyle(.segmented)
                    }

                    lensSlider("Chromatic", value: $chromaticAmount, range: 0...5)

                    Divider()

                    // Falloff
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Falloff Curve").font(.caption.bold())
                        Picker("Falloff", selection: $falloff) {
                            Text("Linear").tag(LiquidLensFalloff.linear)
                            Text("In").tag(LiquidLensFalloff.easeIn)
                            Text("Out").tag(LiquidLensFalloff.easeOut)
                            Text("InOut").tag(LiquidLensFalloff.easeInOut)
                            Text("Cubic").tag(LiquidLensFalloff.cubic)
                            Text("Expo").tag(LiquidLensFalloff.exponential)
                        }
                        .pickerStyle(.segmented)
                    }

                    lensSlider("Falloff Length", value: $falloffLength, range: 0.01...1)
                    lensSlider("Falloff Intensity", value: $falloffIntensity, range: 0...1)

                    Divider()

                    // Quality
                    Text("Quality / Performance").font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    lensSlider("Capture Scale", value: $captureScale, range: 0.25...1.0, format: "%.2fx")
                    lensSlider("Refresh Rate", value: $refreshRate, range: 1...120, format: "%.0f fps")
                }
                .padding()
            }
            .frame(maxHeight: 300)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }

        // MARK: - Helpers

        private func lensSlider(
            _ label: String,
            value: Binding<Float>,
            range: ClosedRange<Float>,
            format: String = "%.2f"
        ) -> some View {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption)
                    .frame(width: 100, alignment: .leading)
                Slider(value: value, in: range)
                Text(String(format: format, value.wrappedValue))
                    .monospacedDigit()
                    .font(.caption2)
                    .frame(width: 50, alignment: .trailing)
            }
        }

        private func settingsRow<V: View>(@ViewBuilder content: () -> V) -> some View {
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }

        private func resetDefaults() {
            lensWidth = 240
            lensHeight = 240
            strength = 0.5
            lensCurvature = 0.6
            chromaticAmount = 2.0
            material = .flintGlass
            falloff = .easeInOut
            falloffLength = 1.0
            falloffIntensity = 0.5
            lensCornerRadius = 0
            cornerRadiusProportional = false
            refreshRate = 30
            captureScale = 1.0
        }
    }

#else

    struct LiquidLensDemoView: View {
        var body: some View {
            NavigationStack {
                VStack(spacing: 16) {
                    Image(systemName: "drop.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Liquid Lens is iOS-only")
                        .font(.title3.bold())
                    Text("The CAMetalLayer-backed renderer requires iOS.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Liquid Lens")
            }
        }
    }

#endif
