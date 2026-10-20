import AemiSDR
import UIKit
import simd

/// Draws one scene: a 1:1 pixel background and, depending on `mode`, native Liquid Glass or the AemiSDR lens in an identical shape.
final class LabViewController: UIViewController {
    private let arguments: LabArguments
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
        case "native": addNative(frame: frame)
        case "aemi": addAemi(frame: frame, image: image, center: center)
        default: break
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
            arguments.shape == "rrect"
            ? .uniformCorners(radius: .fixed(arguments.radius)) : .capsule()
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
