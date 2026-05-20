//
//  DemoSettingsKit.swift
//  AemiSDRDemo
//
//  Shared SwiftUI primitives used by every demo screen's settings sheet.
//  Centralizes:
//    - `ParameterSlider`: the label / slider / value-label row pattern.
//    - `SettingsButton`: the toolbar trigger that toggles a sheet.
//    - `demoSettingsSheet(...)`: the sheet presentation modifier with
//      consistent detents, background interaction, and scroll behavior.
//    - `ParameterIntSlider`: integer-stepped variant.
//
//  Replaces four near-identical copies (`sliderRow`, `parameterSlider`)
//  scattered across the demos and the inconsistent
//  `NavigationStack → List → NavigationLink → Form` indirection some demos
//  used for what's essentially a single-page Form.
//

import SwiftUI

// MARK: - ParameterSlider

/// A label / slider / formatted-value row. Works with any
/// `BinaryFloatingPoint` (Double, CGFloat, Float) so each demo can keep
/// its native binding type without bridging.
struct ParameterSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    let label: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value.Stride?
    let format: String

    init(
        _ label: String,
        value: Binding<Value>,
        range: ClosedRange<Value>,
        step: Value.Stride? = nil,
        format: String = "%.2f"
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .frame(width: 92, alignment: .leading)

            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }

            Text(String(format: format, Double(value)))
                .monospacedDigit()
                .font(.caption2)
                .frame(width: 56, alignment: .trailing)
        }
    }
}

// MARK: - ParameterIntSlider

/// Integer-typed slider for parameters like FPS or count selectors.
struct ParameterIntSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    init(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String = ""
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.unit = unit
    }

    var body: some View {
        let binding = Binding<Double>(
            get: { Double(value) },
            set: { value = Int($0.rounded()) }
        )
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .frame(width: 92, alignment: .leading)
            Slider(value: binding, in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            Text(unit.isEmpty ? "\(value)" : "\(value) \(unit)")
                .monospacedDigit()
                .font(.caption2)
                .frame(width: 56, alignment: .trailing)
        }
    }
}

// MARK: - Settings toolbar + sheet (iOS only)

#if os(iOS)
    /// Trailing-toolbar button that toggles a binding-controlled sheet.
    ///
    /// Icon flips between `slider.horizontal.2.square` (closed) and
    /// `slider.horizontal.2.square.on.square` (open) so the affordance reads
    /// consistently across screens.
    struct SettingsToolbarButton: View {
        @Binding var isPresented: Bool

        var body: some View {
            Button {
                isPresented.toggle()
            } label: {
                Image(
                    systemName: isPresented
                        ? "slider.horizontal.2.square.on.square"
                        : "slider.horizontal.2.square"
                )
                .accessibilityLabel(isPresented ? "Hide settings" : "Show settings")
            }
        }
    }

    extension View {
        /// Presents a settings sheet with the standard demo presentation:
        /// medium/large detents, scroll-aware content interaction, and
        /// background interaction enabled so the underlying preview keeps
        /// updating while the sheet is open.
        func demoSettingsSheet<Content: View>(
            isPresented: Binding<Bool>,
            @ViewBuilder content: @escaping () -> Content
        ) -> some View {
            self.sheet(isPresented: isPresented) {
                content()
                    .presentationDetents([.medium, .large])
                    .presentationContentInteraction(.scrolls)
                    .presentationBackgroundInteraction(.enabled)
            }
        }

        /// Adds the trailing settings-toolbar button bound to `isPresented`.
        /// Call alongside `demoSettingsSheet(isPresented:content:)` to get
        /// the full pattern.
        func demoSettingsToolbar(isPresented: Binding<Bool>) -> some View {
            self.toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton(isPresented: isPresented)
                }
            }
        }
    }
#endif

// MARK: - Conditional row

/// Hides a row entirely when `condition` is false. Use in Form sections
/// instead of nesting `if`s that confuse SwiftUI's ViewBuilder identity.
struct ConditionalRow<Content: View>: View {
    let condition: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if condition { content() }
    }
}
