import AemiSDR
import SwiftUI

struct ModifiersShowcaseView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    backgroundVsOverlaySection
                    frostedGlassSection
                    tintedBlurSection
                }
                .padding()
            }
            .background { SampleBackground() }
            .navigationTitle("Modifiers")
        }
    }

    // MARK: - Background vs Overlay

    private var backgroundVsOverlaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background vs Overlay")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                VStack {
                    Text("Image + Text")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .visualEffectBackground(
                            VisualEffectConfiguration(
                                blurRadius: 20,
                                saturationDeltaFactor: 1.8
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(".visualEffectBackground")
                        .font(.caption)
                }

                VStack {
                    Text("Image + Text")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .visualEffectOverlay(
                            VisualEffectConfiguration(
                                blurRadius: 20,
                                saturationDeltaFactor: 1.8
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(".visualEffectOverlay")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Frosted Glass

    private var frostedGlassSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frosted Glass")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                VStack {
                    Text("Default")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .frostedGlassBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("blur: 18, tint: 0.2")
                        .font(.caption)
                }

                VStack {
                    Text("Heavy")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .frostedGlassBackground(blurRadius: 30, tintOpacity: 0.5)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("blur: 30, tint: 0.5")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Tinted Blur

    private var tintedBlurSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tinted Blur")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                tintedCard(color: .blue, label: "Blue")
                tintedCard(color: .red, label: "Red")
                tintedCard(color: .green, label: "Green")
            }
        }
    }

    private func tintedCard(color: Color, label: String) -> some View {
        VStack {
            Text(label)
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .tintedBlurBackground(color: color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
