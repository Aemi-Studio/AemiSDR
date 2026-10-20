import AemiSDR
import SwiftUI
import UIKit
import simd

/// Draws one scene: a 1:1 pixel background and, depending on `mode`, native Liquid Glass or the AemiSDR lens in an identical shape.
final class LabViewController: UIViewController {
    let arguments: LabArguments
    private var built = false

    init(arguments: LabArguments) {
        self.arguments = arguments
        super.init(nibName: nil, bundle: nil)
        overrideUserInterfaceStyle = arguments.dark ? .dark : .light
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !built, view.bounds.width > 0 else { return }
        built = true
        build()
    }

    private func build() {
        let scale = view.traitCollection.displayScale
        let pixelWidth = Int((view.bounds.width * scale).rounded())
        let pixelHeight = Int((view.bounds.height * scale).rounded())
        view.backgroundColor = .black
        guard let image = LabBackground.image(named: arguments.background, width: pixelWidth, height: pixelHeight)
        else {
            return
        }

        let backdrop = UIImageView(image: UIImage(cgImage: image, scale: scale, orientation: .up))
        backdrop.frame = view.bounds
        backdrop.layer.magnificationFilter = .nearest
        backdrop.layer.minificationFilter = .nearest
        view.addSubview(backdrop)

        let center = CGPoint(
            x: arguments.centerX ?? view.bounds.midX, y: arguments.centerY ?? view.bounds.midY)
        let frame = CGRect(
            x: center.x - arguments.width / 2, y: center.y - arguments.height / 2,
            width: arguments.width, height: arguments.height)

        switch arguments.mode {
        case "native":
            if arguments.shape == "triangle" { addNativeTriangle(frame: frame) } else { addNative(frame: frame) }
        case "clear": addClear(frame: frame, image: image)
        case "aemi":
            // The lens has no arbitrary-shape input; a triangle leaves the plain background (reported as unsupported).
            if arguments.shape != "triangle" { addAemi(frame: frame, image: image, center: center) }
        default: break
        }

        // The capture script waits for this line: a screenshot taken earlier shows the launch screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            print("READY")
            fflush(stdout)
        }
    }

    private var cornerRadius: CGFloat {
        switch arguments.shape {
        case "capsule", "circle": return min(arguments.width, arguments.height) / 2
        default: return arguments.radius
        }
    }

    private func addNative(frame: CGRect) {
        let effect = UIGlassEffect(style: arguments.style == "clear" ? .clear : .regular)
        let glass = UIVisualEffectView(effect: effect)
        glass.frame = frame
        glass.cornerConfiguration =
            arguments.shape == "rrect" || arguments.shape == "square"
            ? .uniformCorners(radius: .fixed(cornerRadius)) : .capsule()
        view.addSubview(glass)
    }

    private func addAemi(frame: CGRect, image: CGImage, center: CGPoint) {
        let p = arguments.parameters
        var configuration = LiquidLensConfiguration(
            center: SIMD2(Float(center.x), Float(center.y)),
            halfSize: SIMD2(Float(frame.width / 2), Float(frame.height / 2)),
            strength: Float(p["strength"] ?? 1.0),
            lensCurvature: Float(p["curvature"] ?? 1.0),
            cornerRadius: .points(Float(cornerRadius)),
            falloff: .exponential,
            falloffLength: Float(p["falloffLength"] ?? 1.0),
            falloffIntensity: Float(p["falloffIntensity"] ?? 1.0),
            chromaticAmount: Float(p["chromatic"] ?? 3.0),
            material: .water,
            overlayMode: true,
            diagonalBand: Float(p["diagonalBand"] ?? 6.0)
        )
        configuration.enableSpectral = (p["spectral"] ?? 0) > 0
        let lens = LiquidLensUIView(configuration: configuration)
        lens.frame = view.bounds
        view.addSubview(lens)
        lens.setSourceImage(image)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TriangleGlass: View {
    let clear: Bool
    var body: some View {
        Color.clear.glassEffect(clear ? .clear : .regular, in: Triangle())
    }
}

extension LabViewController {
    /// Native glass in a non-rectangular shape: only SwiftUI's `glassEffect(in:)` takes an arbitrary shape.
    fileprivate func addNativeTriangle(frame: CGRect) {
        let host = UIHostingController(rootView: TriangleGlass(clear: arguments.style == "clear"))
        host.view.backgroundColor = .clear
        host.view.frame = frame
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

extension LabViewController {
    /// The package's clear glass, in the same shape as the native glass it is compared with.
    fileprivate func addClear(frame: CGRect, image: CGImage) {
        let shape: GlassShape
        switch arguments.shape {
        case "capsule": shape = .capsule
        case "circle": shape = .circle
        case "square": shape = .roundedRect(radii: .zero)
        case "triangle":
            let path = CGMutablePath()
            path.move(to: CGPoint(x: frame.width / 2, y: 0))
            path.addLine(to: CGPoint(x: frame.width, y: frame.height))
            path.addLine(to: CGPoint(x: 0, y: frame.height))
            path.closeSubpath()
            shape = .path(path)
        default: shape = .roundedRect(radii: GlassCornerRadii(arguments.radius), curve: .continuous)
        }
        var configuration = ClearGlassConfiguration.nativeClear(shape: shape)
        let p = arguments.parameters
        if let value = p["blur"] { configuration.blur = .gaussian(value) }
        if let value = p["blurCore"] { configuration.blur.coreRadius = value }
        if let value = p["blurHalo"] { configuration.blur.haloRadius = value }
        if let value = p["blurMix"] { configuration.blur.coreWeight = value }
        if let value = p["outline"] { configuration.outline = value }
        if let value = p["rimEdge"] { configuration.rim.edgeDepth = value }
        if let value = p["rimEdgeFalloff"] { configuration.rim.edgeFalloff = value }
        if let value = p["rimBody"] { configuration.rim.bodyDepth = value }
        if let value = p["rimBodyWidth"] { configuration.rim.bodyWidth = value }
        if let value = p["lift"] { configuration.lift = value }
        if let value = p["liftFalloff"] { configuration.liftFalloff = value }
        let glass = ClearGlassUIView(configuration: configuration)
        glass.frame = frame
        view.addSubview(glass)
        glass.setSourceImage(image, origin: frame.origin)
    }
}
