import AemiSDR
import SwiftUI

#if os(iOS)
    struct AlphaMaskDemo: View {
        enum MaskMode: String, CaseIterable, Identifiable {
            case verticalEdge = "Vertical Edge"
            case horizontalEdge = "Horizontal Edge"
            case verticalCenter = "Vertical Center"
            case horizontalCenter = "Horizontal Center"
            case roundedRect = "Rounded Rectangle"

            var id: Self { self }
        }

        enum VerticalEdgeSelection: String, CaseIterable {
            case top, bottom, both

            var edgeSet: VerticalEdge.Set {
                switch self {
                case .top: .top
                case .bottom: .bottom
                case .both: .all
                }
            }
        }

        enum HorizontalEdgeSelection: String, CaseIterable {
            case leading, trailing, both

            var edgeSet: HorizontalEdge.Set {
                switch self {
                case .leading: .leading
                case .trailing: .trailing
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
        @State private var mode: MaskMode = .verticalEdge

        // Common — band size
        @State private var bandLength: CGFloat = 100
        @State private var useFullExtent = false

        // Common — appearance
        @State private var transition: TransitionAlgorithm = .eased
        @State private var inverted = true
        @State private var ignoreSafeArea = true

        // Edge selection (one for each axis to preserve user selections across modes)
        @State private var verticalEdges: VerticalEdgeSelection = .both
        @State private var horizontalEdges: HorizontalEdgeSelection = .both

        // Rounded rect parameters
        @State private var rrCornerStyle: CornerStyleSelection = .continuous
        @State private var rrCornerRadius: CGFloat = 32
        @State private var rrFadeWidth: CGFloat = 16

        @State private var showSettings = false

        var body: some View {
            NavigationStack {
                ZStack {
                    LinearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    maskedContent
                }
                .navigationTitle("Alpha Mask")
                .demoSettingsToolbar(isPresented: $showSettings)
                .demoSettingsSheet(isPresented: $showSettings) {
                    settingsSheet
                }
            }
        }

        @ViewBuilder
        private var maskedContent: some View {
            switch mode {
            case .verticalEdge:
                SharedScrollContent()
                    .verticalEdgeMask(
                        height: useFullExtent ? .infinity : bandLength,
                        edges: verticalEdges.edgeSet,
                        transition: transition,
                        ignoreSafeArea: ignoreSafeArea,
                        inverted: inverted
                    )
            case .horizontalEdge:
                SharedScrollContent()
                    .horizontalEdgeMask(
                        width: useFullExtent ? .infinity : bandLength,
                        edges: horizontalEdges.edgeSet,
                        transition: transition,
                        ignoreSafeArea: ignoreSafeArea,
                        inverted: inverted
                    )
            case .verticalCenter:
                SharedScrollContent()
                    .verticalCenterMask(
                        height: useFullExtent ? .infinity : bandLength,
                        ignoreSafeArea: ignoreSafeArea,
                        inverted: inverted
                    )
            case .horizontalCenter:
                SharedScrollContent()
                    .horizontalCenterMask(
                        width: useFullExtent ? .infinity : bandLength,
                        ignoreSafeArea: ignoreSafeArea,
                        inverted: inverted
                    )
            case .roundedRect:
                SharedScrollContent()
                    .roundedRectMask(
                        rrCornerStyle.cornerStyle,
                        cornerRadius: rrCornerRadius,
                        fadeWidth: rrFadeWidth,
                        inverted: inverted,
                        ignoreSafeArea: ignoreSafeArea,
                        transition: transition
                    )
            }
        }

        private var settingsSheet: some View {
            Form {
                Section("Mode") {
                    Picker("Mask Type", selection: $mode) {
                        ForEach(MaskMode.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                }

                // Size band — applies to edge & center modes only
                if mode != .roundedRect {
                    Section("Band") {
                        Toggle("Full \(mode.isHorizontal ? "Width" : "Height")", isOn: $useFullExtent)
                        if !useFullExtent {
                            ParameterSlider(
                                mode.isHorizontal ? "Width" : "Height",
                                value: $bandLength,
                                range: 20...400,
                                format: "%.0f pt"
                            )
                        }
                    }
                }

                // Edge picker — only for edge modes
                switch mode {
                case .verticalEdge:
                    Section("Edges") {
                        Picker("Edges", selection: $verticalEdges) {
                            Text("Top").tag(VerticalEdgeSelection.top)
                            Text("Bottom").tag(VerticalEdgeSelection.bottom)
                            Text("Both").tag(VerticalEdgeSelection.both)
                        }
                    }
                case .horizontalEdge:
                    Section("Edges") {
                        Picker("Edges", selection: $horizontalEdges) {
                            Text("Leading").tag(HorizontalEdgeSelection.leading)
                            Text("Trailing").tag(HorizontalEdgeSelection.trailing)
                            Text("Both").tag(HorizontalEdgeSelection.both)
                        }
                    }
                default:
                    EmptyView()
                }

                // Rounded-rect specifics
                if mode == .roundedRect {
                    Section("Shape") {
                        Picker("Corner Style", selection: $rrCornerStyle) {
                            ForEach(CornerStyleSelection.allCases, id: \.self) { value in
                                Text(value.rawValue.capitalized).tag(value)
                            }
                        }
                        ParameterSlider("Corner Radius", value: $rrCornerRadius, range: 0...120, format: "%.0f pt")
                        ParameterSlider("Fade Width", value: $rrFadeWidth, range: 0...64, format: "%.0f pt")
                    }
                }

                Section("Appearance") {
                    if mode.supportsTransition {
                        Picker("Transition", selection: $transition) {
                            Text("Linear").tag(TransitionAlgorithm.linear)
                            Text("Eased").tag(TransitionAlgorithm.eased)
                        }
                    }
                    Toggle("Inverted", isOn: $inverted)
                    Toggle("Ignore Safe Area", isOn: $ignoreSafeArea)
                }

                Section {
                    Text(
                        "Alpha masks render at the host view's resolution. The capture-scale knob you'll find on Variable Blur / Backdrop demos does not apply here — there's no separate capture step."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }
            }
        }
    }

    extension AlphaMaskDemo.MaskMode {
        fileprivate var isHorizontal: Bool {
            switch self {
            case .horizontalEdge, .horizontalCenter: true
            default: false
            }
        }

        fileprivate var supportsTransition: Bool {
            switch self {
            case .verticalEdge, .horizontalEdge, .roundedRect: true
            case .verticalCenter, .horizontalCenter: false
            }
        }
    }
#else
    struct AlphaMaskDemo: View {
        var body: some View {
            Text("Alpha Mask demo is iOS-only.")
                .foregroundStyle(.secondary)
                .navigationTitle("Alpha Mask")
        }
    }
#endif
