import AemiSDR
import SwiftUI

#if os(iOS)
    struct VariableBlurDemo: View {
        enum BlurMode: String, CaseIterable, Identifiable {
            case edgeBlur = "Edge Blur"
            case uniformBlur = "Uniform Blur"
            case centerBlur = "Center Blur"
            case roundedRectBlur = "Rounded Rectangle"

            var id: Self { self }
        }

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

        enum CornerStyleSelection: String, CaseIterable {
            case circular, continuous

            var cornerStyle: RoundedCornerStyle {
                switch self {
                case .circular: .circular
                case .continuous: .continuous
                }
            }
        }

        // Mode
        @State private var blurMode: BlurMode = .edgeBlur

        // Geometry
        @State private var maxBlurRadius: CGFloat = 3
        @State private var height: CGFloat = 100
        @State private var useFullHeight = false

        // Edge-blur shape
        @State private var edges: EdgeSelection = .both
        @State private var transition: TransitionAlgorithm = .eased

        // Rounded-rect-blur shape
        @State private var rrCornerStyle: CornerStyleSelection = .continuous
        @State private var rrCornerRadius: CGFloat = 32
        @State private var rrFadeWidth: CGFloat = 16
        @State private var rrInverted: Bool = false

        // Capture
        @State private var captureScale: CGFloat = 1.0
        @State private var ignoreSafeArea: Bool = true

        @State private var showSettings = false

        var body: some View {
            NavigationStack {
                blurredContent
                    .navigationTitle("Variable Blur")
                    .demoSettingsToolbar(isPresented: $showSettings)
                    .demoSettingsSheet(isPresented: $showSettings) {
                        settingsSheet
                    }
            }
        }

        @ViewBuilder
        private var blurredContent: some View {
            switch blurMode {
            case .edgeBlur:
                SharedScrollContent()
                    .verticalEdgeBlur(
                        height: useFullHeight ? .infinity : height,
                        maxBlurRadius: maxBlurRadius,
                        edges: edges.edgeSet,
                        transition: transition,
                        ignoreSafeArea: ignoreSafeArea,
                        scale: captureScale
                    )
            case .uniformBlur:
                SharedScrollContent()
                    .uniformBlur(
                        maxBlurRadius: maxBlurRadius,
                        ignoreSafeArea: ignoreSafeArea,
                        scale: captureScale
                    )
            case .centerBlur:
                SharedScrollContent()
                    .verticalCenterBlur(
                        height: useFullHeight ? .infinity : height,
                        maxBlurRadius: maxBlurRadius,
                        ignoreSafeArea: ignoreSafeArea,
                        scale: captureScale
                    )
            case .roundedRectBlur:
                SharedScrollContent()
                    .roundedRectBlur(
                        rrCornerStyle.cornerStyle,
                        cornerRadius: rrCornerRadius,
                        fadeWidth: rrFadeWidth,
                        maxBlurRadius: maxBlurRadius,
                        transition: transition,
                        inverted: rrInverted,
                        ignoreSafeArea: ignoreSafeArea,
                        scale: captureScale
                    )
            }
        }

        private var settingsSheet: some View {
            Form {
                Section("Mode") {
                    Picker("Blur Mode", selection: $blurMode) {
                        ForEach(BlurMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                Section("Blur") {
                    ParameterSlider("Max Radius", value: $maxBlurRadius, range: 1...40, format: "%.1f pt")

                    // Band length only applies to vertical edge / center modes.
                    // Uniform blur covers the whole view; rounded-rect blur is
                    // sized by the shape's corner radius + fade-width band, not
                    // a height knob.
                    if blurMode == .edgeBlur || blurMode == .centerBlur {
                        Toggle("Full Height", isOn: $useFullHeight)
                        if !useFullHeight {
                            ParameterSlider("Height", value: $height, range: 20...400, format: "%.0f pt")
                        }
                    }
                }

                if blurMode == .edgeBlur {
                    Section("Edges") {
                        Picker("Edges", selection: $edges) {
                            Text("Top").tag(EdgeSelection.top)
                            Text("Bottom").tag(EdgeSelection.bottom)
                            Text("Both").tag(EdgeSelection.both)
                        }

                        Picker("Transition", selection: $transition) {
                            Text("Linear").tag(TransitionAlgorithm.linear)
                            Text("Eased").tag(TransitionAlgorithm.eased)
                        }
                    }
                }

                if blurMode == .roundedRectBlur {
                    Section("Shape") {
                        Picker("Corner Style", selection: $rrCornerStyle) {
                            ForEach(CornerStyleSelection.allCases, id: \.self) { value in
                                Text(value.rawValue.capitalized).tag(value)
                            }
                        }
                        ParameterSlider("Corner Radius", value: $rrCornerRadius, range: 0...120, format: "%.0f pt")
                        ParameterSlider("Fade Width", value: $rrFadeWidth, range: 0...64, format: "%.0f pt")
                        Picker("Transition", selection: $transition) {
                            Text("Linear").tag(TransitionAlgorithm.linear)
                            Text("Eased").tag(TransitionAlgorithm.eased)
                        }
                        Toggle("Inverted", isOn: $rrInverted)
                    }
                }

                Section {
                    ParameterSlider(
                        "Capture Scale",
                        value: $captureScale,
                        range: 0.25...3.0,
                        format: "%.2fx"
                    )
                    Toggle("Ignore Safe Area", isOn: $ignoreSafeArea)
                } header: {
                    Text("Capture")
                } footer: {
                    Text(
                        "Capture scale controls the mask resolution. 1.0× matches the screen scale; lower trades fidelity for performance."
                    )
                    .font(.caption2)
                }
            }
        }
    }
#else
    struct VariableBlurDemo: View {
        var body: some View {
            Text("Variable Blur demo is iOS-only.")
                .foregroundStyle(.secondary)
                .navigationTitle("Variable Blur")
        }
    }
#endif
