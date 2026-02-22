import AemiSDR
import SwiftUI

struct AlphaMaskDemo: View {
    enum EdgeSelection: String, CaseIterable {
        case top, bottom, both

        var edgeSet: VerticalEdge.Set {
            switch self {
            case .top: .top
            case .bottom: .bottom
            case .both: .all
            }
        }
    }

    @State private var height: CGFloat = 100
    @State private var useFullHeight = false
    @State private var edges: EdgeSelection = .both
    @State private var transition: TransitionAlgorithm = .eased
    @State private var inverted = true
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [.purple, .blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                SharedScrollContent()
                    .verticalEdgeMask(
                        height: useFullHeight ? .infinity : height,
                        edges: edges.edgeSet,
                        transition: transition,
                        inverted: inverted
                    )

                if showSettings {
                    settingsPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showSettings)
            .navigationTitle("Alpha Mask")
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
        }
    }

    private var settingsPanel: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("Mask Settings")
                        .font(.headline)
                    Spacer()
                }

                if !useFullHeight {
                    parameterSlider("Height", value: $height, range: 20...200, format: "%.0f pt")
                }

                Toggle("Full Height", isOn: $useFullHeight)
                    .font(.subheadline)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Edges").font(.caption.bold())
                    Picker("Edges", selection: $edges) {
                        Text("Top").tag(EdgeSelection.top)
                        Text("Bottom").tag(EdgeSelection.bottom)
                        Text("Both").tag(EdgeSelection.both)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Transition").font(.caption.bold())
                    Picker("Transition", selection: $transition) {
                        Text("Linear").tag(TransitionAlgorithm.linear)
                        Text("Eased").tag(TransitionAlgorithm.eased)
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("Inverted", isOn: $inverted)
                    .font(.subheadline)
            }
            .padding()
        }
        .frame(maxHeight: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
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
