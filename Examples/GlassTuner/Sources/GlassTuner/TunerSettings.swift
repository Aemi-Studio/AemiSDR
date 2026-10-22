import AemiSDR
import CoreGraphics
import Foundation

enum TunerShape: String, Codable, CaseIterable, Identifiable {
    case rectangle = "Rectangle"
    case rounded = "Rounded rectangle"
    case capsule = "Capsule"
    case circle = "Circle"
    case triangle = "Triangle"
    var id: Self { self }
}

enum TunerBlur: String, Codable, CaseIterable, Identifiable {
    case native = "Native approximation"
    case gaussian = "Gaussian"
    case optical = "Optical approximation"
    case frosted = "Frosted"
    var id: Self { self }
}

enum TunerPattern: String, Codable, CaseIterable, Identifiable {
    case complex, grid, checker, dots, stripes, black, gray, white
    var id: Self { self }
}

/// Exported values, not view state. Versioned, finite and bounded before imported values reach Metal.
struct TunerSettings: Codable, Equatable, Sendable {
    static let canvasSize = CGSize(width: 400, height: 440)
    var version = 1
    var shape = TunerShape.rounded
    var pattern = TunerPattern.grid
    var darkAppearance = false
    var width = 280.0
    var height = 190.0
    var radius = 36.0
    var perCorner = false
    var topLeft = 8.0
    var topRight = 59.0
    var bottomLeft = 8.0
    var bottomRight = 59.0
    var continuous = true
    var blur = TunerBlur.native
    var blurScale = 1.0
    var gaussianRadius = 1.0
    var edgeClarity = 0.0
    var rampDepth = 12.0
    var rampCurve = 1.0
    var refraction = true
    var arc = true
    var pull = 60.0
    var pullHeight = 20.0
    var gaussianPull = 1.743
    var gaussianWidth = 7.32
    var veil = true
    var veilStrength = 32.0 / 255.0
    var veilRed = 1.0
    var veilGreen = 1.0
    var veilBlue = 1.0
    var innerLight = 1.0
    var outerRing = 1.0
    var aberration = 0.0

    var size: CGSize { CGSize(width: width, height: shape == .circle ? width : height) }
    var origin: CGPoint {
        CGPoint(x: (Self.canvasSize.width - size.width) / 2, y: (Self.canvasSize.height - size.height) / 2)
    }

    var radii: GlassCornerRadii {
        GlassCornerRadii(
            topLeading: perCorner ? topLeft : radius, topTrailing: perCorner ? topRight : radius,
            bottomLeading: perCorner ? bottomLeft : radius, bottomTrailing: perCorner ? bottomRight : radius)
    }

    var glassShape: GlassShape {
        switch shape {
        case .rectangle: .roundedRect(radii: GlassCornerRadii(0))
        case .rounded: .roundedRect(radii: radii, curve: continuous ? .continuous : .circular)
        case .capsule: .capsule
        case .circle: .circle
        case .triangle: .path(Self.triangle(in: CGRect(origin: .zero, size: size)))
        }
    }

    static func triangle(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    var configuration: ClearGlassConfiguration {
        var config = ClearGlassConfiguration.nativeClear(shape: glassShape)
        config.blur = resolvedBlur
        config.rim =
            !refraction
            ? .none
            : arc
                ? .circularArc(depth: pull, height: pullHeight)
                : ClearGlassRim(
                    edgeDepth: pull, edgeFalloff: pullHeight, bodyDepth: gaussianPull, bodyWidth: gaussianWidth)
        config.lift = veil ? veilStrength : 0
        config.veilColor = ClearGlassColor(red: veilRed, green: veilGreen, blue: veilBlue)
        config.rimLight.edgeStrength *= innerLight
        config.rimLight.tailStrength *= innerLight
        config.outline *= outerRing
        config.chromatic = aberration
        return config
    }

    private var resolvedBlur: ClearGlassBlur {
        var result: ClearGlassBlur =
            switch blur {
            case .native: .nativeClear
            case .gaussian: .gaussian(gaussianRadius)
            case .optical: .optical
            case .frosted: .frosted
            }
        for index in result.components.indices { result.components[index].radius *= blurScale }
        guard edgeClarity > 0 else { return result }
        // Preserve the interior kernel. Three-component presets use their existing sharpest component at the edge.
        if result.components.count < 3 {
            result.components.insert(.init(radius: 0.05, edgeWeight: 0, innerWeight: 0), at: 0)
        }
        for index in result.components.indices {
            result.components[index].edgeWeight = result.components[index].innerWeight * (1 - edgeClarity)
        }
        result.components[0].edgeWeight += edgeClarity
        result.rampDepth = rampDepth
        result.rampCurve = rampCurve
        return result
    }

    func validated() throws -> Self {
        guard version == 1 else { throw SettingsError.unsupportedVersion }
        let fields: [(String, Double, ClosedRange<Double>)] = [
            ("width", width, 40...380), ("height", height, 40...400), ("radius", radius, 0...180),
            ("topLeft", topLeft, 0...180), ("topRight", topRight, 0...180),
            ("bottomLeft", bottomLeft, 0...180), ("bottomRight", bottomRight, 0...180),
            ("blurScale", blurScale, 0...4), ("gaussianRadius", gaussianRadius, 0...8),
            ("edgeClarity", edgeClarity, 0...1), ("rampDepth", rampDepth, 0...40), ("rampCurve", rampCurve, 0.1...8),
            ("pull", pull, 0...100), ("pullHeight", pullHeight, 0.1...60),
            ("gaussianPull", gaussianPull, 0...30), ("gaussianWidth", gaussianWidth, 0.1...40),
            ("veilStrength", veilStrength, 0...0.5), ("veilRed", veilRed, 0...1),
            ("veilGreen", veilGreen, 0...1), ("veilBlue", veilBlue, 0...1),
            ("innerLight", innerLight, 0...2), ("outerRing", outerRing, 0...2), ("aberration", aberration, 0...0.2),
        ]
        for (name, value, range) in fields {
            guard value.isFinite, range.contains(value) else { throw SettingsError.outOfRange(name) }
        }
        return self
    }

    func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(validated())
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 65_536 else { throw SettingsError.tooLarge }
        return try JSONDecoder().decode(Self.self, from: data).validated()
    }

    enum SettingsError: LocalizedError {
        case unsupportedVersion, tooLarge
        case outOfRange(String)
        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: "Unsupported settings version."
            case .tooLarge: "Settings must be at most 64 KiB."
            case .outOfRange(let field): "Invalid or out-of-range setting: \(field)."
            }
        }
    }
}
