import AemiSDR
import SwiftUI

struct CustomBlurView: View {
    @State private var blurRadius: CGFloat = 10
    @State private var saturationDeltaFactor: CGFloat = 1.5
    @State private var scale: CGFloat = 1
    @State private var colorTintAlpha: CGFloat = 0
    @State private var colorTint: Color = .white
    @State private var grayscaleTintLevel: CGFloat = 0
    @State private var darkeningTintAlpha: CGFloat = 0

    private var configuration: VisualEffectConfiguration {
        VisualEffectConfiguration(
            blurRadius: blurRadius,
            scale: scale,
            colorTint: colorTintAlpha > 0 ? colorTint : nil,
            colorTintAlpha: colorTintAlpha,
            saturationDeltaFactor: saturationDeltaFactor,
            grayscaleTintLevel: grayscaleTintLevel,
            darkeningTintAlpha: darkeningTintAlpha
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SampleBackground()

                VStack(spacing: 0) {
                    // Live preview area
                    VisualEffectView(configuration: configuration)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()

                    Divider()

                    // Controls
                    ScrollView {
                        VStack(spacing: 16) {
                            sliderRow("Blur Radius", value: $blurRadius, range: 0...50)
                            sliderRow("Saturation", value: $saturationDeltaFactor, range: 0...3)
                            sliderRow("Scale", value: $scale, range: 0...2)

                            HStack {
                                Text("Color Tint")
                                    .frame(width: 120, alignment: .leading)
                                ColorPicker("", selection: $colorTint, supportsOpacity: false)
                                    .labelsHidden()
                                Slider(value: $colorTintAlpha, in: 0...1)
                                Text(String(format: "%.2f", colorTintAlpha))
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                            }

                            sliderRow("Grayscale Tint", value: $grayscaleTintLevel, range: 0...1)
                            sliderRow("Darkening", value: $darkeningTintAlpha, range: 0...1)

                            Button("Reset") {
                                blurRadius = 10
                                saturationDeltaFactor = 1.5
                                scale = 1
                                colorTintAlpha = 0
                                colorTint = .white
                                grayscaleTintLevel = 0
                                darkeningTintAlpha = 0
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                    .background(.regularMaterial)
                }
            }
            .navigationTitle("Custom Blur")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func sliderRow(
        _ label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>
    ) -> some View {
        HStack {
            Text(label)
                .frame(width: 120, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.2f", value.wrappedValue))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}
