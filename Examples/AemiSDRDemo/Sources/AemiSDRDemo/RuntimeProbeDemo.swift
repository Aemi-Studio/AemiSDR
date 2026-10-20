#if os(iOS)
    import AemiSDR
    import SwiftUI
    import UIKit

    /// User-facing probes run the public API of the local checkout, not a second copy of the private reader.
    struct RuntimeProbeDemo: View {
        @Environment(\.scenePhase) private var scenePhase
        @State private var radii: DisplayCornerRadii = .zero
        @State private var samples: [Sample] = []
        @State private var refreshedAt: Date?

        private struct Sample: Identifiable {
            let id: String
            let light: BackdropBlurConfiguration
            let dark: BackdropBlurConfiguration
        }

        var body: some View {
            NavigationStack {
                List {
                    Section("Build") {
                        LabeledContent("Package", value: "Local checkout")
                        LabeledContent(
                            "System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                        Text("These probes call the same AemiSDR APIs as the effect demos.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Display corners · points") {
                        LabeledContent("Top left", value: number(radii.topLeft))
                        LabeledContent("Top right", value: number(radii.topRight))
                        LabeledContent("Bottom left", value: number(radii.bottomLeft))
                        LabeledContent("Bottom right", value: number(radii.bottomRight))
                        LabeledContent("Largest (legacy scalar)", value: number(radii.maximum))
                        LabeledContent("Uniform", value: radii.isUniform ? "Yes" : "No")
                        Text(
                            "Duo primary display was probed at 8 / 59 / 8 / 59. Existing effect masks still use a single radius; four-corner masks are not implemented yet."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Section("System blur recipes") {
                        Text(
                            "Radius in points / saturation multiplier. Light and dark appearances are resolved independently. These are scalar approximations, not complete material recipes."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        ForEach(samples) { sample in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sample.id).font(.headline)
                                Text("Light: \(recipe(sample.light))")
                                Text("Dark: \(recipe(sample.dark))")
                            }
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        }
                    }

                    if let refreshedAt {
                        Section {
                            LabeledContent("Last refreshed") {
                                Text(refreshedAt, style: .time)
                            }
                        }
                    }
                }
                .navigationTitle("Runtime Probes")
                .toolbar {
                    Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                }
                .onAppear(perform: refresh)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { refresh() }
                }
            }
        }

        private func refresh() {
            radii = UIScreen.displayCornerRadii
            let styles: [(String, UIBlurEffect.Style)] = [
                ("Extra light", .extraLight), ("Light", .light), ("Dark", .dark),
                ("Regular", .regular), ("Prominent", .prominent),
                ("Ultra thin", .systemUltraThinMaterial), ("Thin", .systemThinMaterial),
                ("Material", .systemMaterial), ("Thick", .systemThickMaterial),
                ("Chrome", .systemChromeMaterial),
            ]
            samples = styles.map { name, style in
                Sample(
                    id: name,
                    light: .systemStyle(style, userInterfaceStyle: .light),
                    dark: .systemStyle(style, userInterfaceStyle: .dark)
                )
            }
            refreshedAt = .now
        }

        private func recipe(_ value: BackdropBlurConfiguration) -> String {
            "\(number(value.blurRadius)) / \(number(value.saturationDeltaFactor))"
        }

        private func number(_ value: CGFloat) -> String {
            Double(value).formatted(.number.precision(.fractionLength(0...2)))
        }
    }
#endif
