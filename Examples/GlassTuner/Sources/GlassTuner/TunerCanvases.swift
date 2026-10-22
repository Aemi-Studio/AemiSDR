import AemiSDR
import SwiftUI

struct NativeGlassCanvas: View {
    let settings: TunerSettings
    let image: CGImage?
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            #if os(macOS)
                Text("Native macOS clear glass").font(.headline)
            #else
                Text("Native iOS clear glass").font(.headline)
            #endif
            PatternCanvas(image: image, scale: scale) {
                nativeGlass.frame(width: settings.size.width, height: settings.size.height)
            }
            Text("Actual system glass; no custom optical parameters.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var nativeGlass: some View {
        switch settings.shape {
        case .rectangle:
            Color.clear.glassEffect(.clear, in: Rectangle())
        case .rounded:
            Color.clear.glassEffect(
                .clear,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: settings.radii.topLeading, bottomLeadingRadius: settings.radii.bottomLeading,
                    bottomTrailingRadius: settings.radii.bottomTrailing, topTrailingRadius: settings.radii.topTrailing,
                    style: settings.continuous ? .continuous : .circular))
        case .capsule:
            Color.clear.glassEffect(.clear, in: Capsule(style: .continuous))
        case .circle:
            Color.clear.glassEffect(.clear, in: Circle())
        case .triangle:
            Color.clear.glassEffect(.clear, in: NativeTriangle())
        }
    }
}

struct CustomGlassCanvas: View {
    let image: CGImage?
    let rendered: ClearGlassRenderedImage?
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            Text("AemiSDR").font(.headline)
            PatternCanvas(image: image, scale: scale) {
                if let rendered {
                    Image(decorative: rendered.image, scale: rendered.scale)
                        .interpolation(.none)
                        // Pixel rounding may leave unequal right/bottom padding. Align the shape, not the image bounds.
                        .offset(
                            x: CGFloat(rendered.image.width) / (2 * rendered.scale) - rendered.contentRect.midX,
                            y: CGFloat(rendered.image.height) / (2 * rendered.scale) - rendered.contentRect.midY)
                }
            }
            Text("Still-image preview; optical controls affect this panel only.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct PatternCanvas<Content: View>: View {
    let image: CGImage?
    let scale: CGFloat
    let content: Content

    init(image: CGImage?, scale: CGFloat, @ViewBuilder content: () -> Content) {
        self.image = image
        self.scale = scale
        self.content = content()
    }

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: scale).interpolation(.none)
            } else {
                Color.gray
                ProgressView()
            }
            content
        }
        .frame(width: TunerSettings.canvasSize.width, height: TunerSettings.canvasSize.height)
        .clipped()
    }
}

private struct NativeTriangle: Shape {
    func path(in rect: CGRect) -> Path { Path(TunerSettings.triangle(in: rect)) }
}
