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
        @State private var radius: Float = 120
        @State private var strength: Float = 0.5
        @State private var lensCurvature: Float = 0.6
        @State private var chromaticAmount: Float = 2.0
        @State private var material: LiquidLensMaterial = .flintGlass
        @State private var falloff: LiquidLensFalloff = .easeInOut
        @State private var falloffLength: Float = 1.0
        @State private var falloffIntensity: Float = 0.5
        @State private var lensCornerRadius: Float = 0

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

        var body: some View {
            ZStack(alignment: .bottom) {
                // Content + lens
                scrollContent
                    .liquidLens(
                        center: SIMD2(Float(lensCenter.x), Float(lensCenter.y)),
                        radius: radius,
                        strength: strength,
                        lensCurvature: lensCurvature,
                        cornerRadius: lensCornerRadius,
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
                        Circle()
                            .stroke(
                                isDragging ? Color.white : Color.white.opacity(0.4),
                                lineWidth: isDragging ? 2 : 1
                            )
                            .frame(width: CGFloat(radius) * 2, height: CGFloat(radius) * 2)
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
                    lensSlider("Radius", value: $radius, range: 30...300)
                    lensSlider("Strength", value: $strength, range: 0...1)
                    lensSlider("Curvature", value: $lensCurvature, range: 0...1)
                    lensSlider("Corner Radius", value: $lensCornerRadius, range: 0...200)

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
            radius = 120
            strength = 0.5
            lensCurvature = 0.6
            chromaticAmount = 2.0
            material = .flintGlass
            falloff = .easeInOut
            falloffLength = 1.0
            falloffIntensity = 0.5
            lensCornerRadius = 0
            refreshRate = 30
            captureScale = 1.0
        }
    }

    // MARK: - Sample Image Generation

    /// Generates a colorful sample image for demos.
    @MainActor
    private func makeSampleImage(size: CGSize = CGSize(width: 600, height: 600)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Mesh-like gradient background
            let colors: [UIColor] = [
                UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1),
                UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1),
                UIColor(red: 0.9, green: 0.9, blue: 0.2, alpha: 1),
                UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1),
                UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1),
                UIColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1),
            ]

            let tileW = size.width / 3
            let tileH = size.height / 2

            for (i, color) in colors.enumerated() {
                let col = CGFloat(i % 3)
                let row = CGFloat(i / 3)
                let rect = CGRect(x: col * tileW, y: row * tileH, width: tileW, height: tileH)
                cg.setFillColor(color.cgColor)
                cg.fill(rect)
            }

            // Draw some shapes for visual reference
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            cg.setLineWidth(3)

            // Grid lines
            for i in 1..<6 {
                let x = CGFloat(i) * size.width / 6
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x, y: size.height))
            }
            for i in 1..<6 {
                let y = CGFloat(i) * size.height / 6
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: size.width, y: y))
            }
            cg.strokePath()

            // Circles
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(2)
            for r in stride(from: 40.0, to: size.width / 2, by: 60) {
                cg.strokeEllipse(in: CGRect(
                    x: size.width / 2 - r,
                    y: size.height / 2 - r,
                    width: r * 2,
                    height: r * 2
                ))
            }

            // Text labels
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.white,
            ]
            let text = "AemiSDR" as NSString
            let textSize = text.size(withAttributes: attrs)
            text.draw(
                at: CGPoint(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2
                ),
                withAttributes: attrs
            )
        }
    }

    // MARK: - 0. Live UI Components Demo

    private struct LiveUIComponentsDemo: View {
        @State private var toggleA = true
        @State private var toggleB = false
        @State private var sliderValue: Double = 0.6
        @State private var textInput = "Hello, Liquid Lens!"
        @State private var pickerSelection = 1
        @State private var stepperValue = 3

        var body: some View {
            ScrollView {
                VStack(spacing: 28) {
                    Text("The .liquidLens() modifier captures the view content and distorts it in-place. No pre-rendered image needed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    // Lens on a settings-style form
                    VStack(spacing: 0) {
                        formRow { Toggle("Wi-Fi", isOn: $toggleA) }
                        Divider().padding(.leading, 16)
                        formRow { Toggle("Bluetooth", isOn: $toggleB) }
                        Divider().padding(.leading, 16)
                        formRow {
                            HStack {
                                Text("Brightness")
                                Slider(value: $sliderValue)
                            }
                        }
                        Divider().padding(.leading, 16)
                        formRow {
                            Stepper("Count: \(stepperValue)", value: $stepperValue, in: 0...10)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .liquidLens(
                        center: SIMD2(180, 100),
                        radius: 120,
                        strength: 1.5,
                        lensCurvature: 0.6,
                        chromaticAmount: 2.0,
                        material: .flintGlass,
                        clipShape: RoundedRectangle(cornerRadius: 12)
                    )
                    .padding(.horizontal)

                    // Lens on a text field
                    VStack(spacing: 8) {
                        TextField("Type something...", text: $textInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                            .liquidLens(
                                center: SIMD2(160, 22),
                                radius: 100,
                                strength: 1.3,
                                chromaticAmount: 1.5,
                                material: .crownGlass
                            )

                        Text(".liquidLens() on TextField")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Lens on buttons
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button("Primary") {}
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)

                            Button("Secondary") {}
                                .buttonStyle(.bordered)
                                .controlSize(.large)

                            Button(role: .destructive) { } label: {
                                Text("Delete")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        .liquidLens(
                            center: SIMD2(120, 22),
                            radius: 90,
                            strength: 1.8,
                            lensCurvature: 0.7,
                            chromaticAmount: 2.5,
                            material: .diamond
                        )

                        Text(".liquidLens() on button group")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Lens on a segmented picker
                    VStack(spacing: 8) {
                        Picker("Selection", selection: $pickerSelection) {
                            Text("First").tag(0)
                            Text("Second").tag(1)
                            Text("Third").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .liquidLens(
                            center: SIMD2(180, 16),
                            radius: 80,
                            strength: 1.2,
                            chromaticAmount: 1.5,
                            material: .water
                        )

                        Text(".liquidLens() on segmented picker")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Lens on rich text content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Physics-Based Rendering")
                            .font(.title2.bold())
                        Text("Sellmeier dispersion equations model wavelength-dependent refraction indices for 5 real optical materials.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "drop.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                            Image(systemName: "wand.and.stars")
                                .font(.title)
                                .foregroundStyle(.purple)
                            Image(systemName: "sparkles")
                                .font(.title)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .liquidLens(
                        center: SIMD2(160, 60),
                        radius: 100,
                        strength: 1.4,
                        lensCurvature: 0.5,
                        chromaticAmount: 2.0,
                        material: .acrylic,
                        clipShape: RoundedRectangle(cornerRadius: 12)
                    )
                    .padding(.horizontal)

                    // Continuous capture demo: animated gradient
                    ContinuousCaptureDemoCard()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Live UI Components")
            .navigationBarTitleDisplayMode(.inline)
        }

        private func formRow<V: View>(@ViewBuilder content: () -> V) -> some View {
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    // MARK: - Continuous Capture Demo

    /// Demonstrates that the lens effect updates in real-time when background content changes.
    private struct ContinuousCaptureDemoCard: View {
        @State private var hue: Double = 0

        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    // Animated gradient that changes continuously
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.8, brightness: 0.9),
                            Color(hue: (hue + 0.33).truncatingRemainder(dividingBy: 1.0), saturation: 0.8, brightness: 0.9),
                            Color(hue: (hue + 0.66).truncatingRemainder(dividingBy: 1.0), saturation: 0.8, brightness: 0.9),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 4) {
                        Image(systemName: "livephoto")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                        Text("Continuous Capture")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Background animates; lens updates in real-time")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .liquidLens(
                    center: SIMD2(180, 80),
                    radius: 80,
                    strength: 1.6,
                    lensCurvature: 0.6,
                    chromaticAmount: 2.0,
                    material: .diamond,
                    clipShape: RoundedRectangle(cornerRadius: 16),
                    continuousCapture: true,
                    refreshRate: 30
                )
                .onAppear {
                    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                        hue = 1.0
                    }
                }

                Text(".liquidLens(continuousCapture: true) on animated gradient")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Lens-over-image helper

    /// Shows the source image as a background with the liquid lens overlay on top,
    /// so the distortion is visible against the original content.
    private struct LensOverImage: View {
        let image: UIImage
        let configuration: LiquidLensConfiguration

        var body: some View {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()

                LiquidLensView(
                    image: image,
                    configuration: configuration
                )
            }
        }
    }

    // MARK: - 1. Interactive Playground

    private struct LiquidLensPlayground: View {
        @State private var sampleImage: UIImage?
        @State private var radius: Float = 150
        @State private var strength: Float = 1.0
        @State private var lensCurvature: Float = 0.5
        @State private var cornerRadius: Float = 0
        @State private var falloff: LiquidLensFalloff = .easeInOut
        @State private var falloffLength: Float = 1.0
        @State private var falloffIntensity: Float = 0.5
        @State private var chromaticAmount: Float = 1.0
        @State private var material: LiquidLensMaterial = .crownGlass
        @State private var useRadialDirection: Bool = true

        var body: some View {
            VStack(spacing: 0) {
                // Preview
                GeometryReader { geo in
                    let center = SIMD2<Float>(
                        Float(geo.size.width / 2),
                        Float(geo.size.height / 2)
                    )

                    if let image = sampleImage {
                        LensOverImage(
                            image: image,
                            configuration: LiquidLensConfiguration(
                                center: center,
                                radius: radius,
                                strength: strength,
                                lensCurvature: lensCurvature,
                                cornerRadius: cornerRadius,
                                falloff: falloff,
                                falloffLength: falloffLength,
                                falloffIntensity: falloffIntensity,
                                chromaticAmount: chromaticAmount,
                                material: material,
                                useRadialDirection: useRadialDirection
                            )
                        )
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 320)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 4)

                Divider().padding(.top, 8)

                // Controls
                ScrollView {
                    VStack(spacing: 12) {
                        Group {
                            floatSlider("Radius", value: $radius, range: 10...300)
                            floatSlider("Strength", value: $strength, range: -3...3)
                            floatSlider("Curvature", value: $lensCurvature, range: 0...1)
                            floatSlider("Corner Radius", value: $cornerRadius, range: 0...200)
                        }

                        Divider()

                        Group {
                            materialPicker
                            falloffPicker
                            floatSlider("Falloff Length", value: $falloffLength, range: 0.01...1)
                            floatSlider("Falloff Intensity", value: $falloffIntensity, range: 0...1)
                        }

                        Divider()

                        Group {
                            floatSlider("Chromatic", value: $chromaticAmount, range: 0...3)
                            Toggle("Radial Direction", isOn: $useRadialDirection)
                        }

                        resetButton
                    }
                    .padding()
                }
                .background(.regularMaterial)
            }
            .navigationTitle("Playground")
            .navigationBarTitleDisplayMode(.inline)
            .task { sampleImage = makeSampleImage() }
        }

        private var materialPicker: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("Material").font(.caption.bold())
                Picker("Material", selection: $material) {
                    Text("Crown Glass").tag(LiquidLensMaterial.crownGlass)
                    Text("Flint Glass").tag(LiquidLensMaterial.flintGlass)
                    Text("Water").tag(LiquidLensMaterial.water)
                    Text("Acrylic").tag(LiquidLensMaterial.acrylic)
                    Text("Diamond").tag(LiquidLensMaterial.diamond)
                }
                .pickerStyle(.segmented)
            }
        }

        private var falloffPicker: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("Falloff Curve").font(.caption.bold())
                Picker("Falloff", selection: $falloff) {
                    Text("Linear").tag(LiquidLensFalloff.linear)
                    Text("Ease In").tag(LiquidLensFalloff.easeIn)
                    Text("Ease Out").tag(LiquidLensFalloff.easeOut)
                    Text("InOut").tag(LiquidLensFalloff.easeInOut)
                    Text("Cubic").tag(LiquidLensFalloff.cubic)
                    Text("Expo").tag(LiquidLensFalloff.exponential)
                }
                .pickerStyle(.segmented)
            }
        }

        private var resetButton: some View {
            Button("Reset All") {
                radius = 150; strength = 1.0; lensCurvature = 0.5; cornerRadius = 0
                falloff = .easeInOut; falloffLength = 1.0; falloffIntensity = 0.5
                chromaticAmount = 1.0; material = .crownGlass; useRadialDirection = true
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - 2. Material Gallery

    private struct MaterialGalleryView: View {
        @State private var sampleImage: UIImage?

        private let materials: [(String, LiquidLensMaterial)] = [
            ("Crown Glass", .crownGlass),
            ("Flint Glass", .flintGlass),
            ("Water", .water),
            ("Acrylic", .acrylic),
            ("Diamond", .diamond),
        ]

        var body: some View {
            ScrollView {
                if let image = sampleImage {
                    VStack(spacing: 24) {
                        Text("Each material has unique Sellmeier dispersion coefficients, producing different chromatic aberration patterns.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ForEach(materials, id: \.0) { name, mat in
                            VStack(spacing: 6) {
                                LensOverImage(
                                    image: image,
                                    configuration: LiquidLensConfiguration(
                                        center: SIMD2(150, 120),
                                        radius: 120,
                                        strength: 1.5,
                                        lensCurvature: 0.6,
                                        chromaticAmount: 2.0,
                                        material: mat
                                    )
                                )
                                .frame(height: 240)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text(name)
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("Materials")
            .navigationBarTitleDisplayMode(.inline)
            .task { sampleImage = makeSampleImage(size: CGSize(width: 400, height: 300)) }
        }
    }

    // MARK: - 3. Falloff Curves Gallery

    private struct FalloffGalleryView: View {
        @State private var sampleImage: UIImage?

        private let falloffs: [(String, LiquidLensFalloff)] = [
            ("Linear", .linear),
            ("Ease In", .easeIn),
            ("Ease Out", .easeOut),
            ("Ease In-Out", .easeInOut),
            ("Cubic", .cubic),
            ("Exponential", .exponential),
        ]

        var body: some View {
            ScrollView {
                if let image = sampleImage {
                    VStack(spacing: 24) {
                        Text("Falloff curves control how the lens effect intensity transitions from center to edge.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 16
                        ) {
                            ForEach(falloffs, id: \.0) { name, curve in
                                VStack(spacing: 6) {
                                    LensOverImage(
                                        image: image,
                                        configuration: LiquidLensConfiguration(
                                            center: SIMD2(100, 100),
                                            radius: 90,
                                            strength: 1.2,
                                            lensCurvature: 0.5,
                                            falloff: curve,
                                            falloffLength: 1.0,
                                            falloffIntensity: 0.8,
                                            chromaticAmount: 1.5,
                                            material: .flintGlass
                                        )
                                    )
                                    .frame(height: 200)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                    Text(name)
                                        .font(.caption.bold())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("Falloff Curves")
            .navigationBarTitleDisplayMode(.inline)
            .task { sampleImage = makeSampleImage(size: CGSize(width: 300, height: 300)) }
        }
    }

    // MARK: - 4. Drag-to-Distort

    private struct DragToDistortView: View {
        @State private var sampleImage: UIImage?
        @State private var lensCenter: CGPoint = .zero
        @State private var viewSize: CGSize = .zero
        @State private var radius: Float = 120
        @State private var strength: Float = 1.5
        @State private var material: LiquidLensMaterial = .crownGlass

        var body: some View {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let size = geo.size

                    ZStack {
                        if let image = sampleImage {
                            // Background: original image
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: size.width, height: size.height)
                                .clipped()

                            // Overlay: distorted lens
                            LiquidLensView(
                                image: image,
                                configuration: LiquidLensConfiguration(
                                    center: SIMD2(
                                        Float(lensCenter.x),
                                        Float(lensCenter.y)
                                    ),
                                    radius: radius,
                                    strength: strength,
                                    lensCurvature: 0.6,
                                    chromaticAmount: 1.5,
                                    material: material
                                )
                            )
                        }

                        // Lens indicator ring
                        Circle()
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                            .frame(width: CGFloat(radius) * 2, height: CGFloat(radius) * 2)
                            .position(lensCenter)
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                lensCenter = value.location
                            }
                    )
                    .onAppear {
                        viewSize = size
                        lensCenter = CGPoint(x: size.width / 2, y: size.height / 2)
                    }
                    .onChange(of: size) { _, newSize in
                        viewSize = newSize
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Compact controls
                VStack(spacing: 10) {
                    floatSlider("Radius", value: $radius, range: 30...200)
                    floatSlider("Strength", value: $strength, range: -3...3)

                    Picker("Material", selection: $material) {
                        Text("Crown").tag(LiquidLensMaterial.crownGlass)
                        Text("Flint").tag(LiquidLensMaterial.flintGlass)
                        Text("Water").tag(LiquidLensMaterial.water)
                        Text("Acrylic").tag(LiquidLensMaterial.acrylic)
                        Text("Diamond").tag(LiquidLensMaterial.diamond)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle("Drag to Distort")
            .navigationBarTitleDisplayMode(.inline)
            .task { sampleImage = makeSampleImage() }
        }
    }

    // MARK: - 5. Clip Shape Composability

    private struct ClipShapeDemo: View {
        @State private var sampleImage: UIImage?

        var body: some View {
            ScrollView {
                if let image = sampleImage {
                    VStack(spacing: 32) {
                        Text("CAMetalLayer with isOpaque=false preserves transparency, so SwiftUI clip shapes work naturally.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        // Rounded rectangle clip
                        demoCard(image: image, title: "RoundedRectangle(cornerRadius: 24)") {
                            $0.clipShape(RoundedRectangle(cornerRadius: 24))
                        }

                        // Circle clip
                        demoCard(image: image, title: "Circle()") {
                            $0.clipShape(Circle())
                        }

                        // Capsule clip
                        demoCard(image: image, title: "Capsule()") {
                            $0.frame(height: 160)
                                .clipShape(Capsule())
                        }

                        // UnevenRoundedRectangle clip
                        demoCard(image: image, title: "UnevenRoundedRectangle") {
                            $0.clipShape(UnevenRoundedRectangle(
                                topLeadingRadius: 40,
                                bottomLeadingRadius: 8,
                                bottomTrailingRadius: 40,
                                topTrailingRadius: 8
                            ))
                        }

                        // No clip (raw transparent metal layer)
                        demoCard(image: image, title: "No clip (raw layer)") { $0 }
                    }
                    .padding()
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("Clip Shapes")
            .navigationBarTitleDisplayMode(.inline)
            .task { sampleImage = makeSampleImage(size: CGSize(width: 400, height: 300)) }
        }

        private func demoCard<V: View>(
            image: UIImage,
            title: String,
            @ViewBuilder transform: (LensOverImage) -> V
        ) -> some View {
            VStack(spacing: 8) {
                transform(
                    LensOverImage(
                        image: image,
                        configuration: LiquidLensConfiguration(
                            center: SIMD2(200, 150),
                            radius: 130,
                            strength: 1.3,
                            lensCurvature: 0.5,
                            chromaticAmount: 1.5,
                            material: .flintGlass
                        )
                    )
                )
                .frame(height: 240)
                .clipped()

                Text(title)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 6. View Modifier Usage

    private struct ViewModifierDemo: View {
        @State private var sampleImage: UIImage?

        var body: some View {
            ScrollView {
                if let image = sampleImage {
                    VStack(spacing: 32) {
                        Text("The .liquidLens() modifier applies the effect as a non-interactive overlay on any view.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        // Basic modifier usage
                        VStack(spacing: 8) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 260)
                                .clipped()
                                .liquidLens(
                                    image: image,
                                    center: SIMD2(180, 130),
                                    radius: 120,
                                    strength: 1.2,
                                    material: .crownGlass
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text(".liquidLens(image:center:radius:strength:material:)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        // Full-parameter modifier
                        VStack(spacing: 8) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 260)
                                .clipped()
                                .liquidLens(
                                    image: image,
                                    center: SIMD2(180, 130),
                                    radius: 150,
                                    strength: 2.0,
                                    lensCurvature: 0.7,
                                    cornerRadius: 40,
                                    falloff: .cubic,
                                    falloffLength: 0.8,
                                    falloffIntensity: 0.6,
                                    chromaticAmount: 2.5,
                                    material: .diamond,
                                    useRadialDirection: false
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text("Diamond + Cubic falloff + Shape-aware direction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        // Negative strength (inverted lens)
                        VStack(spacing: 8) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 260)
                                .clipped()
                                .liquidLens(
                                    image: image,
                                    center: SIMD2(180, 130),
                                    radius: 140,
                                    strength: -1.5,
                                    chromaticAmount: 1.5,
                                    material: .flintGlass
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text("Negative strength (concave lens)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("View Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .task { sampleImage = makeSampleImage(size: CGSize(width: 400, height: 300)) }
        }
    }

    // MARK: - Shared Helpers

    private func floatSlider(
        _ label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>
    ) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 110, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.2f", value.wrappedValue))
                .monospacedDigit()
                .font(.caption)
                .frame(width: 48, alignment: .trailing)
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
