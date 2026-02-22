import AemiSDR
import SwiftUI

struct PresetsGalleryView: View {
    private let presets: [(String, VisualEffectConfiguration)] = {
        var list: [(String, VisualEffectConfiguration)] = []
        #if os(iOS)
            list = [
                ("light", .light),
                ("dark", .dark),
                ("extraLight", .extraLight),
                ("ultraThinMaterial", .ultraThinMaterial),
                ("thinMaterial", .thinMaterial),
                ("material", .material),
                ("thickMaterial", .thickMaterial),
                ("chromeMaterial", .chromeMaterial),
            ]
        #elseif os(macOS)
            list = [
                ("light", .light),
                ("dark", .dark),
                ("ultraThinMaterial", .ultraThinMaterial),
                ("thinMaterial", .thinMaterial),
                ("material", .material),
                ("thickMaterial", .thickMaterial),
                ("chromeMaterial", .chromeMaterial),
            ]
        #endif
        return list
    }()

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(presets, id: \.0) { name, config in
                        PresetCard(name: name, configuration: config)
                    }
                }
                .padding()
            }
            .background { SampleBackground() }
            .navigationTitle("Presets Gallery")
        }
    }
}

private struct PresetCard: View {
    let name: String
    let configuration: VisualEffectConfiguration

    var body: some View {
        ZStack {
            VisualEffectView(configuration: configuration)

            VStack(spacing: 4) {
                Text(name)
                    .font(.headline)
                Text("blur: \(configuration.blurRadius, specifier: "%.1f")")
                    .font(.caption)
                Text("sat: \(configuration.saturationDeltaFactor, specifier: "%.2f")")
                    .font(.caption)
            }
            .foregroundStyle(.primary)
            .padding(8)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
