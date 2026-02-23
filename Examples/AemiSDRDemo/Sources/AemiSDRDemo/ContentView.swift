import AemiSDR
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Blur", systemImage: "aqi.medium") {
                VariableBlurDemo()
            }
            Tab("Mask", systemImage: "square.on.circle") {
                AlphaMaskDemo()
            }
            Tab("Glass", systemImage: "rectangle.on.rectangle") {
                VisualEffectDemo()
            }
            Tab("Liquid", systemImage: "drop.circle") {
                LiquidLensDemoView()
            }
            Tab("Stack", systemImage: "square.stack.3d.up.fill") {
                StickyHeaderStackDemo()
            }
        }
    }
}


struct StickyHeaderStackDemo: View {
    private enum EdgeSelection: String, CaseIterable {
        case top
        case bottom
        case both

        var edgeSet: VerticalEdge.Set {
            switch self {
            case .top:
                return .top
            case .bottom:
                return .bottom
            case .both:
                return .all
            }
        }
    }

    private enum BackdropTint: String, CaseIterable {
        case none
        case white
        case cyan
        case mint
        case orange

        var color: Color? {
            switch self {
            case .none:
                return nil
            case .white:
                return .white
            case .cyan:
                return .cyan
            case .mint:
                return .mint
            case .orange:
                return .orange
            }
        }
    }

    private enum EffectKind: String, CaseIterable, Identifiable {
        case backdropBlur
        case liquid
        case variableBlur
        case alphaMask

        var id: String { rawValue }

        var title: String {
            switch self {
            case .backdropBlur:
                return "Backdrop Blur"
            case .liquid:
                return "Liquid"
            case .variableBlur:
                return "Variable Blur"
            case .alphaMask:
                return "Alpha Mask"
            }
        }

        var subtitle: String {
            switch self {
            case .backdropBlur:
                return "Backdrop material + saturation"
            case .liquid:
                return "Refraction + chromatic dispersion"
            case .variableBlur:
                return "Directional blur shaping"
            case .alphaMask:
                return "Edge opacity shaping"
            }
        }
    }

    private struct BackdropSettings {
        var blurRadius: CGFloat = 20
        var saturation: CGFloat = 1.8
        var tint: BackdropTint = .white
        var tintAlpha: CGFloat = 0.16

        var configuration: BackdropBlurConfiguration {
            BackdropBlurConfiguration(
                blurRadius: blurRadius,
                colorTint: tint.color,
                colorTintAlpha: tint == .none ? 0 : tintAlpha,
                saturationDeltaFactor: saturation
            )
        }
    }

    private struct EdgeBlurSettings {
        var maxBlurRadius: CGFloat = 8
        var height: CGFloat = 60
        var useFullHeight = false
        var edges: EdgeSelection = .bottom
        var transition: TransitionAlgorithm = .eased
    }

    private struct EdgeMaskSettings {
        var height: CGFloat = 60
        var useFullHeight = false
        var edges: EdgeSelection = .bottom
        var transition: TransitionAlgorithm = .eased
        var inverted = true
    }

    private struct EffectItem: Identifiable {
        var id = UUID()
        var kind: EffectKind
        var isEnabled = true
        var backdrop = BackdropSettings()
        var liquid = LiquidGlassConfiguration.regular
        var variableBlur = EdgeBlurSettings()
        var alphaMask = EdgeMaskSettings()
    }

    @State private var headerCornerRadius: Double = 20
    @State private var headerHeight: Double = 62
    @State private var showSettings = false
    @State private var effectStack: [EffectItem] = [
        Self.defaultEffect(for: .liquid),
//        Self.defaultEffect(for: .backdropBlur),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                    Section {
                        contentCards
                    } header: {
                        stickyHeader
                    }
                }
            }
            .navigationTitle("Sticky Stack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.2.square")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
        }
    }

    private var stickyHeader: some View {
        let rounded = RoundedRectangle(
            cornerRadius: headerCornerRadius,
            style: .continuous
        )

        return ZStack {
            rounded
                .fill(.white.opacity(0.08))
                .overlay(
                    rounded.strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .background {
                    applyEffectStack()
                }
                .clipShape(rounded)
            
            HStack(spacing: 10) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.title3)
                Text("Sticky Header Stack")
                    .font(.headline)
                Spacer()
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .padding(.horizontal, 14)
            .foregroundStyle(.white)
        }
        .frame(height: headerHeight)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var contentCards: some View {
        ForEach(0..<20, id: \.self) { index in
            VStack(alignment: .leading, spacing: 8) {
                Text("Playlist \(index + 1)")
                    .font(.headline)
                Text("Scroll to inspect pinned-header composition and stacking order changes in real time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 120)
    }

    private var settingsSheet: some View {
        NavigationStack {
            List {
                Section("Stacking Order (top row is top-most layer)") {
                    ForEach(effectStack) { effect in
                        HStack(spacing: 10) {
                            Toggle(isOn: isEnabledBinding(for: effect.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(effect.kind.title)
                                    Text(effect.kind.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            NavigationLink {
                                if let effectBinding = bindingForEffect(id: effect.id) {
                                    effectSettingsView(effect: effectBinding)
                                } else {
                                    Text("Effect no longer exists.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove(perform: moveEffects)
                    .onDelete(perform: deleteEffects)
                }

                Section("Header") {
                    NavigationLink("Header Appearance") {
                        headerSettingsView
                    }
                }
            }
            .navigationTitle("Sticky Header Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(availableKindsToAdd) { kind in
                            Button(kind.title) {
                                addEffect(kind)
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(availableKindsToAdd.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var headerSettingsView: some View {
        Form {
            sliderRow(
                "Corner Radius",
                value: $headerCornerRadius,
                range: 0...36,
                format: "%.0f"
            )
            sliderRow(
                "Height",
                value: $headerHeight,
                range: 48...96,
                format: "%.0f pt"
            )
        }
        .navigationTitle("Header Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func effectSettingsView(effect: Binding<EffectItem>) -> some View {
        switch effect.wrappedValue.kind {
        case .backdropBlur:
            backdropSettingsView(effect: effect)
        case .liquid:
            liquidSettingsView(effect: effect)
        case .variableBlur:
            variableBlurSettingsView(effect: effect)
        case .alphaMask:
            alphaMaskSettingsView(effect: effect)
        }
    }

    private func backdropSettingsView(effect: Binding<EffectItem>) -> some View {
        Form {
            sliderRow(
                "Blur Radius",
                value: effect.backdrop.blurRadius,
                range: 0...50,
                format: "%.1f"
            )
            sliderRow(
                "Saturation",
                value: effect.backdrop.saturation,
                range: 0...3,
                format: "%.2f"
            )
            Picker("Tint", selection: effect.backdrop.tint) {
                ForEach(BackdropTint.allCases, id: \.self) { tint in
                    Text(tint.rawValue.capitalized).tag(tint)
                }
            }
            if effect.wrappedValue.backdrop.tint != .none {
                sliderRow(
                    "Tint Alpha",
                    value: effect.backdrop.tintAlpha,
                    range: 0...1,
                    format: "%.2f"
                )
            }
        }
        .navigationTitle("Backdrop Blur")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func liquidSettingsView(effect: Binding<EffectItem>) -> some View {
        Form {
            sliderRow(
                "Strength",
                value: floatBinding(effect, \.strength),
                range: 0...1
            )
            sliderRow(
                "Curvature",
                value: floatBinding(effect, \.lensCurvature),
                range: 0...1
            )
            sliderRow(
                "Chromatic",
                value: floatBinding(effect, \.chromaticAmount),
                range: 0...2
            )
            sliderRow(
                "Falloff Len",
                value: floatBinding(effect, \.falloffLength),
                range: 0.01...1
            )
            sliderRow(
                "Falloff Int",
                value: floatBinding(effect, \.falloffIntensity),
                range: 0...1
            )

            Picker("Material", selection: effect.liquid.material) {
                ForEach(LiquidLensMaterial.allCases, id: \.self) { material in
                    Text(materialTitle(material)).tag(material)
                }
            }

            Picker("Falloff Curve", selection: effect.liquid.falloff) {
                ForEach(LiquidLensFalloff.allCases, id: \.self) { value in
                    Text(falloffTitle(value)).tag(value)
                }
            }

            Toggle("Extra Radial Emphasis", isOn: effect.liquid.useRadialDirection)
        }
        .navigationTitle("Liquid")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func variableBlurSettingsView(effect: Binding<EffectItem>) -> some View {
        Form {
            sliderRow(
                "Max Radius",
                value: effect.variableBlur.maxBlurRadius,
                range: 1...20,
                format: "%.1f"
            )

            if !effect.wrappedValue.variableBlur.useFullHeight {
                sliderRow(
                    "Height",
                    value: effect.variableBlur.height,
                    range: 20...120,
                    format: "%.0f pt"
                )
            }

            Toggle("Full Height", isOn: effect.variableBlur.useFullHeight)

            Picker("Edges", selection: effect.variableBlur.edges) {
                Text("Top").tag(EdgeSelection.top)
                Text("Bottom").tag(EdgeSelection.bottom)
                Text("Both").tag(EdgeSelection.both)
            }

            Picker("Transition", selection: effect.variableBlur.transition) {
                Text("Linear").tag(TransitionAlgorithm.linear)
                Text("Eased").tag(TransitionAlgorithm.eased)
            }
        }
        .navigationTitle("Variable Blur")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func alphaMaskSettingsView(effect: Binding<EffectItem>) -> some View {
        Form {
            if !effect.wrappedValue.alphaMask.useFullHeight {
                sliderRow(
                    "Height",
                    value: effect.alphaMask.height,
                    range: 20...120,
                    format: "%.0f pt"
                )
            }

            Toggle("Full Height", isOn: effect.alphaMask.useFullHeight)
            Toggle("Inverted", isOn: effect.alphaMask.inverted)

            Picker("Edges", selection: effect.alphaMask.edges) {
                Text("Top").tag(EdgeSelection.top)
                Text("Bottom").tag(EdgeSelection.bottom)
                Text("Both").tag(EdgeSelection.both)
            }

            Picker("Transition", selection: effect.alphaMask.transition) {
                Text("Linear").tag(TransitionAlgorithm.linear)
                Text("Eased").tag(TransitionAlgorithm.eased)
            }
        }
        .navigationTitle("Alpha Mask")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var availableKindsToAdd: [EffectKind] {
        EffectKind.allCases.filter { kind in
            !effectStack.contains(where: { $0.kind == kind })
        }
    }

    private func addEffect(_ kind: EffectKind) {
        guard !effectStack.contains(where: { $0.kind == kind }) else { return }
        effectStack.append(Self.defaultEffect(for: kind))
    }

    private func moveEffects(from source: IndexSet, to destination: Int) {
        effectStack.move(fromOffsets: source, toOffset: destination)
    }

    private func deleteEffects(at offsets: IndexSet) {
        effectStack.remove(atOffsets: offsets)
    }

    private func effectIndex(for id: UUID) -> Int? {
        effectStack.firstIndex(where: { $0.id == id })
    }

    private func bindingForEffect(id: UUID) -> Binding<EffectItem>? {
        guard let snapshot = effectStack.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { effectStack.first(where: { $0.id == id }) ?? snapshot },
            set: { updated in
                guard let index = effectIndex(for: id) else { return }
                effectStack[index] = updated
            }
        )
    }

    private func isEnabledBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { effectStack.first(where: { $0.id == id })?.isEnabled ?? false },
            set: { newValue in
                guard let index = effectIndex(for: id) else { return }
                effectStack[index].isEnabled = newValue
            }
        )
    }

    private func applyEffectStack() -> some View {
        ZStack {
            ForEach(effectStack) { effect in
                if effect.isEnabled {
                    switch effect.kind {
                        case .backdropBlur:
                            BackdropBlurView(configuration: effect.backdrop.configuration)
                        case .liquid:
                            LiquidGlassView(
                                configuration: effect.liquid,
                                shape: .rect(cornerRadius: 12),
                                cornerRadius: .points(12)
                            )
                        case .variableBlur:
                            EmptyView()
                        case .alphaMask:
                            EmptyView()
                    }
                } else {
                    EmptyView()
                }
            }
        }
    }

    private func sliderRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String = "%.2f"
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 92, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue))
                .monospacedDigit()
                .font(.caption2)
                .frame(width: 58, alignment: .trailing)
        }
    }

    private func sliderRow(
        _ label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        format: String = "%.2f"
    ) -> some View {
        sliderRow(
            label,
            value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = CGFloat($0) }
            ),
            range: Double(range.lowerBound)...Double(range.upperBound),
            format: format
        )
    }

    private func floatBinding(
        _ effect: Binding<EffectItem>,
        _ keyPath: WritableKeyPath<LiquidGlassConfiguration, Float>
    ) -> Binding<Double> {
        Binding<Double>(
            get: { Double(effect.wrappedValue.liquid[keyPath: keyPath]) },
            set: { effect.wrappedValue.liquid[keyPath: keyPath] = Float($0) }
        )
    }

    private func materialTitle(_ material: LiquidLensMaterial) -> String {
        switch material {
        case .crownGlass:
            return "Crown Glass"
        case .flintGlass:
            return "Flint Glass"
        case .water:
            return "Water"
        case .acrylic:
            return "Acrylic"
        case .diamond:
            return "Diamond"
        }
    }

    private func falloffTitle(_ falloff: LiquidLensFalloff) -> String {
        switch falloff {
        case .linear:
            return "Linear"
        case .easeIn:
            return "Ease In"
        case .easeOut:
            return "Ease Out"
        case .easeInOut:
            return "Ease In-Out"
        case .cubic:
            return "Cubic"
        case .exponential:
            return "Exponential"
        }
    }

    private static func defaultEffect(for kind: EffectKind) -> EffectItem {
        var item = EffectItem(kind: kind)

        switch kind {
        case .backdropBlur:
            item.backdrop = BackdropSettings(
                blurRadius: 22,
                saturation: 1.8,
                tint: .white,
                tintAlpha: 0.14
            )
        case .liquid:
            item.liquid = LiquidGlassConfiguration(
                strength: 0.3,
                lensCurvature: 0.55,
                cornerRadius: nil,
                falloff: .easeInOut,
                falloffLength: 1,
                falloffIntensity: 0.45,
                chromaticAmount: 0.45,
                material: .crownGlass,
                useRadialDirection: true,
                continuousCapture: true,
                refreshRate: 30,
                captureScale: 1
            )
        case .variableBlur:
            item.variableBlur = EdgeBlurSettings(
                maxBlurRadius: 8,
                height: 60,
                useFullHeight: false,
                edges: .bottom,
                transition: .eased
            )
        case .alphaMask:
            item.alphaMask = EdgeMaskSettings(
                height: 60,
                useFullHeight: false,
                edges: .bottom,
                transition: .eased,
                inverted: true
            )
        }

        return item
    }
}

#Preview {
    StickyHeaderStackDemo()
}
