import SwiftUI

struct SharedScrollContent: View {
    @State private var toggleA = true
    @State private var toggleB = false
    @State private var sliderValue: Double = 0.6
    @State private var stepperValue = 3
    @State private var pickerSelection = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Gradient hero header
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 160)

                    VStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 44))
                        Text("AemiSDR")
                            .font(.title2.bold())
                    }
                    .foregroundStyle(.white)
                }
                .padding(.horizontal)

                // Settings-style grouped rows
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

                // Segmented picker + buttons
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

                // Info card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Real-Time Effects")
                        .font(.title2.bold())
                    Text(
                        "AemiSDR provides GPU-accelerated visual effects using CoreImage and Metal. Each effect runs in real time with configurable parameters, applied directly to SwiftUI views."
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Label("Blur", systemImage: "aqi.medium")
                            .foregroundStyle(.blue)
                        Label("Mask", systemImage: "square.on.circle")
                            .foregroundStyle(.purple)
                        Label("Glass", systemImage: "rectangle.on.rectangle")
                            .foregroundStyle(.cyan)
                    }
                    .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Colored item rows
                ForEach(0..<6) { i in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill([Color.red, .orange, .yellow, .green, .blue, .purple][i].gradient)
                            .frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(["Ruby", "Amber", "Topaz", "Emerald", "Sapphire", "Amethyst"][i])
                                .font(.headline)
                            Text("Sample item \(i + 1)")
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

                // Lorem ipsum footer
                Text(
                    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

                Spacer(minLength: 120)
            }
            .padding(.vertical)
        }
    }

    private func settingsRow<V: View>(@ViewBuilder content: () -> V) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}
