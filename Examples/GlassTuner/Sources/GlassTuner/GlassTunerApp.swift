import SwiftUI

@main
struct GlassTunerApp: App {
    @State private var model = TunerModel()

    var body: some Scene {
        #if os(macOS)
            Window("Glass Tuner", id: "main") {
                TunerRoot(model: model)
            }
            .defaultSize(width: 1220, height: 800)
        #else
            WindowGroup {
                NavigationStack {
                    TunerRoot(model: model).navigationTitle("Glass Tuner").navigationBarTitleDisplayMode(.inline)
                }
            }
        #endif
    }
}

private struct TunerRoot: View {
    @Bindable var model: TunerModel
    @Environment(\.displayScale) private var displayScale

    private var sourceKey: TunerModel.SourceKey {
        .init(pattern: model.settings.pattern, scale: displayScale)
    }

    var body: some View {
        HStack(spacing: 0) {
            TunerComparison(model: model)
            Divider()
            TunerControls(settings: $model.settings).frame(width: 320)
        }
        .preferredColorScheme(model.settings.darkAppearance ? .dark : .light)
        // The laboratory labels corners by physical position, independently of the interface language.
        .environment(\.layoutDirection, .leftToRight)
        .toolbar {
            Button("Reset", systemImage: "arrow.counterclockwise") { model.settings = TunerSettings() }
            Button("Copy Swift", systemImage: "curlybraces") { model.copySwift() }
            Button("Copy Settings", systemImage: "doc.on.doc") { model.copySettings() }
            Button("Paste Settings", systemImage: "doc.on.clipboard") { model.pasteSettings() }
        }
        .task(id: sourceKey) { await model.load(scale: displayScale) }
        .onChange(of: model.settings) { model.requestRender() }
        .onDisappear { model.cancel() }
    }
}

private struct TunerComparison: View {
    let model: TunerModel
    private let spacing: CGFloat = 24

    var body: some View {
        GeometryReader { geometry in
            let horizontal = geometry.size.width >= TunerSettings.canvasSize.width * 2 + spacing * 3
            let layout =
                horizontal ? AnyLayout(HStackLayout(spacing: spacing)) : AnyLayout(VStackLayout(spacing: spacing))
            ScrollView {
                VStack(spacing: spacing) {
                    layout {
                        NativeGlassCanvas(settings: model.settings, image: model.sourceImage, scale: model.scale)
                        CustomGlassCanvas(image: model.sourceImage, rendered: model.rendered, scale: model.scale)
                    }
                    if let result = model.rendered {
                        HStack {
                            Text(
                                "GPU: \(result.gpuMilliseconds.map { String(format: "%.3f ms", $0) } ?? "unavailable")")
                            Text("Total: \(result.totalMilliseconds, format: .number.precision(.fractionLength(3))) ms")
                            Text("Scale: \(result.scale, format: .number.precision(.fractionLength(1)))×")
                        }
                        .font(.caption.monospacedDigit())
                    }
                    if let error = model.errorText {
                        Text(verbatim: error).foregroundStyle(.red).textSelection(.enabled)
                    } else {
                        Text(model.isRendering ? "Updating…" : "Ready").foregroundStyle(.secondary)
                    }
                    #if os(macOS)
                        Text(
                            "Native preset calibrated on iOS; macOS may differ. Timings describe custom still-image rendering, not native glass."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    #else
                        Text(
                            "Native iOS clear glass is the fidelity reference. Timings describe custom still-image rendering, not native glass."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    #endif
                }
                .padding(spacing)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
