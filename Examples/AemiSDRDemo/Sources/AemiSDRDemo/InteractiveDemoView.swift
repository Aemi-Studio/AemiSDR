import AemiSDR
import SwiftUI

// MARK: - Shared Blur Settings

@Observable
final class BlurSettings {
    var blurRadius: CGFloat = 24
    var saturationDeltaFactor: CGFloat = 1.8
    var scale: CGFloat = 1
    var colorTintAlpha: CGFloat = 0.15
    var colorTint: Color = .white
    var grayscaleTintLevel: CGFloat = 0
    var darkeningTintAlpha: CGFloat = 0

    var configuration: VisualEffectConfiguration {
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

    func reset() {
        blurRadius = 24
        saturationDeltaFactor = 1.8
        scale = 1
        colorTintAlpha = 0.15
        colorTint = .white
        grayscaleTintLevel = 0
        darkeningTintAlpha = 0
    }
}

/// A compact settings panel for live-tuning blur properties.
private struct BlurSettingsPanel: View {
    @Bindable var settings: BlurSettings

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Blur Settings")
                    .font(.headline)
                Spacer()
                Button("Reset", action: settings.reset)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            row("Blur", value: $settings.blurRadius, range: 0...50)
            row("Saturation", value: $settings.saturationDeltaFactor, range: 0...3)
            row("Scale", value: $settings.scale, range: 0...2)

            HStack(spacing: 8) {
                Text("Tint")
                    .frame(width: 70, alignment: .leading)
                ColorPicker("", selection: $settings.colorTint, supportsOpacity: false)
                    .labelsHidden()
                    .fixedSize()
                Slider(value: $settings.colorTintAlpha, in: 0...1)
                Text(String(format: "%.2f", settings.colorTintAlpha))
                    .monospacedDigit()
                    .font(.caption)
                    .frame(width: 36, alignment: .trailing)
            }

            row("Grayscale", value: $settings.grayscaleTintLevel, range: 0...1)
            row("Darkening", value: $settings.darkeningTintAlpha, range: 0...1)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func row(
        _ label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 70, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.2f", value.wrappedValue))
                .monospacedDigit()
                .font(.caption)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

/// Adds a toolbar gear button and settings sheet to any demo view.
private struct WithBlurSettings<Content: View>: View {
    @State private var showSettings = false
    @State var settings = BlurSettings()
    let title: String
    @ViewBuilder let content: (BlurSettings) -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            content(settings)

            if showSettings {
                BlurSettingsPanel(settings: settings)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        showSettings.toggle()
                    }
                } label: {
                    Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                }
            }
        }
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Navigation

struct InteractiveDemoView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Scroll Under Blur") {
                    ScrollUnderBlurDemo()
                }
                NavigationLink("Draggable Blur Panel") {
                    DraggablePanelDemo()
                }
                NavigationLink("Blur Over Form") {
                    BlurOverFormDemo()
                }
                NavigationLink("Chat Overlay") {
                    ChatOverlayDemo()
                }
            }
            .navigationTitle("Interactive")
        }
    }
}

// MARK: - 1. Scroll Under Blur

private struct ScrollUnderBlurDemo: View {
    @State private var name = ""
    @State private var email = ""
    @State private var volume: Double = 0.5
    @State private var wifiEnabled = true
    @State private var bluetoothEnabled = false
    @State private var selectedColor = Color.blue
    @State private var rating = 3
    @State private var date = Date()
    @State private var sliderA: Double = 0.3
    @State private var sliderB: Double = 0.7
    @State private var agreedToTerms = false

    var body: some View {
        WithBlurSettings(title: "Scroll Under Blur") { settings in
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 60)

                        VStack(spacing: 20) {
                            nativeControlsSection
                            moreControlsSection
                            textContentSection
                        }
                        .padding()

                        Color.clear.frame(height: 80)
                    }
                }

                VStack {
                    Text("Scroll content underneath")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .visualEffectBackground(settings.configuration)

                    Spacer()

                    HStack(spacing: 20) {
                        Label("Home", systemImage: "house.fill")
                        Spacer()
                        Label("Search", systemImage: "magnifyingglass")
                        Spacer()
                        Label("Profile", systemImage: "person.fill")
                    }
                    .font(.caption)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .visualEffectBackground(settings.configuration)
                }
            }
        }
    }

    private var nativeControlsSection: some View {
        GroupBox("Text Fields") {
            VStack(spacing: 12) {
                TextField("Full Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Email Address", text: $email)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                        .keyboardType(.emailAddress)
                    #endif
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
        }
    }

    private var moreControlsSection: some View {
        GroupBox("Controls") {
            VStack(spacing: 12) {
                Toggle("Wi-Fi", isOn: $wifiEnabled)
                Toggle("Bluetooth", isOn: $bluetoothEnabled)
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: $volume)
                    Image(systemName: "speaker.wave.3.fill")
                }
                ColorPicker("Accent Color", selection: $selectedColor)
                Stepper("Rating: \(rating)", value: $rating, in: 1...5)
                HStack {
                    Text("Slider A")
                    Slider(value: $sliderA)
                }
                HStack {
                    Text("Slider B")
                    Slider(value: $sliderB)
                }
                Toggle("Agree to Terms", isOn: $agreedToTerms)
                    .toggleStyle(.switch)
                Button("Submit") {}
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var textContentSection: some View {
        GroupBox("Text Content") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<6) { i in
                    Label(
                        sampleParagraphs[i % sampleParagraphs.count],
                        systemImage: "doc.text"
                    )
                    .font(.subheadline)
                    if i < 5 { Divider() }
                }
            }
        }
    }
}

// MARK: - 2. Draggable Blur Panel

private struct DraggablePanelDemo: View {
    @State private var panelOffset: CGSize = .zero
    @State private var dragAccumulator: CGSize = .zero

    var body: some View {
        WithBlurSettings(title: "Draggable Panel") { settings in
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(0..<20) { i in
                            nativeRow(index: i)
                        }
                    }
                    .padding()
                }

                VStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .font(.title2)
                    Text("Drag me")
                        .font(.caption.bold())
                }
                .foregroundStyle(.secondary)
                .frame(width: 180, height: 180)
                .visualEffectBackground(settings.configuration)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 10)
                .offset(x: panelOffset.width, y: panelOffset.height)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            panelOffset = CGSize(
                                width: dragAccumulator.width + value.translation.width,
                                height: dragAccumulator.height + value.translation.height
                            )
                        }
                        .onEnded { value in
                            dragAccumulator = CGSize(
                                width: dragAccumulator.width + value.translation.width,
                                height: dragAccumulator.height + value.translation.height
                            )
                        }
                )
            }
        }
    }

    private func nativeRow(index i: Int) -> some View {
        GroupBox {
            HStack {
                Image(systemName: iconNames[i % iconNames.count])
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 36)

                VStack(alignment: .leading) {
                    Text("Item \(i + 1)")
                        .font(.headline)
                    Text(sampleParagraphs[i % sampleParagraphs.count])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if i % 3 == 0 {
                    Toggle("", isOn: .constant(i % 2 == 0))
                        .labelsHidden()
                } else if i % 3 == 1 {
                    Button("Action") {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - 3. Blur Over Form

private struct BlurOverFormDemo: View {
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = true
    @State private var server = "Production"
    @State private var showOverlay = false
    @State private var brightness: Double = 0.5
    @State private var textSize: Double = 14

    private let servers = ["Production", "Staging", "Development", "Local"]

    var body: some View {
        WithBlurSettings(title: "Blur Over Form") { settings in
            ZStack(alignment: .bottom) {
                Form {
                    Section("Account") {
                        TextField("Username", text: $username)
                        SecureField("Password", text: $password)
                        Toggle("Remember Me", isOn: $rememberMe)
                    }

                    Section("Server") {
                        Picker("Environment", selection: $server) {
                            ForEach(servers, id: \.self) { Text($0) }
                        }
                    }

                    Section("Display") {
                        HStack {
                            Image(systemName: "sun.min")
                            Slider(value: $brightness)
                            Image(systemName: "sun.max.fill")
                        }
                        HStack {
                            Text("Text Size")
                            Slider(value: $textSize, in: 10...24, step: 1)
                            Text("\(Int(textSize))pt")
                                .monospacedDigit()
                                .frame(width: 36)
                        }
                    }

                    Section("Actions") {
                        Button("Show Blur Overlay") {
                            withAnimation(.spring(duration: 0.4)) {
                                showOverlay = true
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Section {
                        ForEach(0..<8) { i in
                            Label(
                                "Setting \(i + 1)",
                                systemImage: iconNames[i % iconNames.count]
                            )
                        }
                    }
                }

                if showOverlay {
                    VStack(spacing: 16) {
                        Capsule()
                            .frame(width: 40, height: 5)
                            .foregroundStyle(.secondary)

                        Text("Blur Overlay")
                            .font(.title3.bold())

                        Text("This panel slides over native Form elements. The blur lets the underlying controls remain partially visible.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Divider()

                        HStack(spacing: 16) {
                            Button("Cancel") {
                                withAnimation(.spring(duration: 0.3)) {
                                    showOverlay = false
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Confirm") {
                                withAnimation(.spring(duration: 0.3)) {
                                    showOverlay = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .visualEffectBackground(settings.configuration)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                    .shadow(radius: 20)
                    .transition(.move(edge: .bottom))
                }
            }
        }
    }
}

// MARK: - 4. Chat Overlay

private struct ChatOverlayDemo: View {
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = ChatMessage.samples

    var body: some View {
        WithBlurSettings(title: "Chat Overlay") { settings in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                        }
                        Color.clear.frame(height: 70)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    TextField("Message...", text: $messageText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        guard !messageText.isEmpty else { return }
                        messages.append(
                            ChatMessage(
                                text: messageText,
                                isFromMe: true,
                                time: "Now"
                            )
                        )
                        messageText = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .visualEffectBackground(settings.configuration)
            }
        }
    }
}

private struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromMe: Bool
    let time: String

    static let samples: [ChatMessage] = [
        .init(text: "Hey! Have you seen the new blur effects?", isFromMe: false, time: "10:01"),
        .init(text: "Yes! The VisualEffectView is incredible", isFromMe: true, time: "10:02"),
        .init(text: "It works on both iOS and macOS now with the same API", isFromMe: true, time: "10:02"),
        .init(text: "That's awesome. How's the performance?", isFromMe: false, time: "10:03"),
        .init(text: "Really smooth. It uses the native backdrop layer under the hood", isFromMe: true, time: "10:03"),
        .init(text: "Can you customize the blur radius and saturation?", isFromMe: false, time: "10:04"),
        .init(text: "Everything. Blur radius, saturation, color tint, darkening, scale...", isFromMe: true, time: "10:04"),
        .init(text: "And there are presets that match the system materials", isFromMe: true, time: "10:05"),
        .init(text: "Nice, I'll check it out. Does it support the frosted glass look?", isFromMe: false, time: "10:06"),
        .init(text: "Yep, there's a .frostedGlassBackground() modifier", isFromMe: true, time: "10:06"),
        .init(text: "And .tintedBlurBackground(color:) for colored blurs", isFromMe: true, time: "10:07"),
        .init(text: "This is exactly what I needed for my app. Thanks!", isFromMe: false, time: "10:08"),
        .init(text: "No problem! The input bar you're typing in right now uses it", isFromMe: true, time: "10:08"),
    ]
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromMe { Spacer(minLength: 60) }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(message.isFromMe ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundStyle(message.isFromMe ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(message.time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !message.isFromMe { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Sample Data

private let sampleParagraphs = [
    "The quick brown fox jumps over the lazy dog. This sentence contains every letter of the alphabet.",
    "SwiftUI provides views, controls, and layout structures for declaring your app's user interface.",
    "Visual effects add depth and polish to your interface by letting content show through blurred layers.",
    "Combine framework provides a declarative API for processing values over time.",
    "Core Animation provides high frame-rate animations without burdening the CPU.",
    "Metal gives your app almost direct access to the graphics processing unit (GPU).",
]

private let iconNames = [
    "star.fill", "heart.fill", "bolt.fill", "leaf.fill",
    "flame.fill", "drop.fill", "snowflake", "moon.fill",
    "sun.max.fill", "cloud.fill", "wind", "tornado",
    "wifi", "antenna.radiowaves.left.and.right", "battery.100", "lock.fill",
    "bell.fill", "tag.fill", "bookmark.fill", "paperclip",
]
