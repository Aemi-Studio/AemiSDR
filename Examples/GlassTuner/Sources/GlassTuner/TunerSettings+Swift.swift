import AemiSDR
import Foundation

extension TunerSettings {
    /// A standalone configuration with every resolved coefficient, not a dependence on a future preset's defaults.
    func swiftCode() throws -> String {
        _ = try validated()
        let config = configuration
        let components = config.blur.components.map {
            "        .init(radius: \($0.radius), edgeWeight: \($0.edgeWeight), innerWeight: \($0.innerWeight))"
        }.joined(separator: ",\n")
        let rim = config.rim
        let light = config.rimLight
        return """
            import AemiSDR
            import CoreGraphics

            let glassSize = CGSize(width: \(size.width), height: \(size.height))
            \(shapeCode)
            let configuration = ClearGlassConfiguration(
                shape: shape,
                blur: ClearGlassBlur(components: [
            \(components)
                ], rampDepth: \(config.blur.rampDepth), rampCurve: \(config.blur.rampCurve)),
                rim: ClearGlassRim(
                    edgeDepth: \(rim.edgeDepth), edgeFalloff: \(rim.edgeFalloff),
                    bodyDepth: \(rim.bodyDepth), bodyWidth: \(rim.bodyWidth),
                    profile: .\(rim.profile == .circularArc ? "circularArc" : "exponentialAndGaussian")),
                lift: \(config.lift), liftFalloff: \(config.liftFalloff),
                veilColor: ClearGlassColor(red: \(config.veilColor.red), green: \(config.veilColor.green), blue: \(config.veilColor.blue)),
                chromatic: \(config.chromatic),
                rimLight: ClearGlassRimLight(
                    edgeStrength: \(light.edgeStrength), edgeFalloff: \(light.edgeFalloff), edgePower: \(light.edgePower),
                    tailStrength: \(light.tailStrength), tailFalloff: \(light.tailFalloff), tailPower: \(light.tailPower),
                    backdropGain: \(light.backdropGain)),
                outline: \(config.outline), outlineReach: \(config.outlineReach), outlineDirection: \(config.outlineDirection))
            """
    }

    private var shapeCode: String {
        switch shape {
        case .rectangle: "let shape = GlassShape.roundedRect(radii: .zero)"
        case .capsule: "let shape = GlassShape.capsule"
        case .circle: "let shape = GlassShape.circle"
        case .rounded:
            """
            let shape = GlassShape.roundedRect(radii: GlassCornerRadii(
                topLeading: \(radii.topLeading), topTrailing: \(radii.topTrailing),
                bottomLeading: \(radii.bottomLeading), bottomTrailing: \(radii.bottomTrailing)),
                curve: .\(continuous ? "continuous" : "circular"))
            """
        case .triangle:
            """
            let path = CGMutablePath()
            path.move(to: CGPoint(x: \(size.width / 2), y: 0))
            path.addLine(to: CGPoint(x: \(size.width), y: \(size.height)))
            path.addLine(to: CGPoint(x: 0, y: \(size.height)))
            path.closeSubpath()
            let shape = GlassShape.path(path)
            """
        }
    }
}
