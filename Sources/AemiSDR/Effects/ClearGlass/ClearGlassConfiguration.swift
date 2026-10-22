//
//  ClearGlassConfiguration.swift
//  AemiSDR
//
//  The look of clear glass, as measured on native Liquid Glass (clear), in points. See ADR-0008.
//

import CoreGraphics

/// A colour for the veil, as red, green and blue in 0...1.
public struct ClearGlassColor: Equatable, Sendable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = ClearGlassColor(red: 1, green: 1, blue: 1)
}

/// The blur of what is behind the glass: a sum of up to three exact Gaussians, whose weights can change with the depth below
/// the edge.
///
/// Each component has a weight at the edge and a weight deep inside, and the weights move from one to the other over
/// `rampDepth` along `rampCurve`, so the glass can be crisper at the rim and softer inside (or the reverse). Weights are
/// normalised at each depth, so the blur never changes brightness. With a `rampDepth` of zero the inner weights apply
/// everywhere.
///
/// Measured on native clear glass the blur is not one Gaussian: a sharp core over a long soft halo (the best-fit kernel has
/// weight 0.31 at one pixel and a flat tail of about 0.05 out to eight). Two Gaussians reproduce that with half the error of
/// one (rms 0.0157 against 0.0276 in the interior) and stay smooth and free of the plateau of a box or disc.
public struct ClearGlassBlur: Equatable, Sendable {
    public struct Component: Equatable, Sendable {
        /// Standard deviation of this Gaussian, in points.
        public var radius: CGFloat
        /// Its weight at the very edge.
        public var edgeWeight: CGFloat
        /// Its weight deep inside.
        public var innerWeight: CGFloat

        public init(radius: CGFloat, edgeWeight: CGFloat, innerWeight: CGFloat) {
            self.radius = radius
            self.edgeWeight = edgeWeight
            self.innerWeight = innerWeight
        }

        /// A component with the same weight at every depth.
        public init(radius: CGFloat, weight: CGFloat) {
            self.init(radius: radius, edgeWeight: weight, innerWeight: weight)
        }
    }

    /// The Gaussians, one to three; any beyond the third are ignored.
    public var components: [Component]
    /// Depth over which the weights move from their edge values to their inner values, in points. Zero: no ramp.
    public var rampDepth: CGFloat
    /// The shape of that move: 1 is smooth, larger holds the edge values longer.
    public var rampCurve: CGFloat

    public init(components: [Component], rampDepth: CGFloat = 0, rampCurve: CGFloat = 1) {
        self.components = components.isEmpty ? [Component(radius: 1, weight: 1)] : Array(components.prefix(3))
        self.rampDepth = rampDepth
        self.rampCurve = rampCurve
    }

    /// Public mutation must obey the same one-to-three component contract as construction.
    fileprivate var activeComponents: [Component] {
        components.isEmpty ? [Component(radius: 1, weight: 1)] : Array(components.prefix(3))
    }

    /// Two Gaussians with a constant mix.
    public init(coreRadius: CGFloat, haloRadius: CGFloat, coreWeight: CGFloat) {
        self.init(components: [
            Component(radius: coreRadius, weight: coreWeight), Component(radius: haloRadius, weight: 1 - coreWeight),
        ])
    }

    /// A single Gaussian of standard deviation `radius` points.
    public static func gaussian(_ radius: CGFloat) -> ClearGlassBlur {
        ClearGlassBlur(components: [Component(radius: radius, weight: 1)])
    }

    /// The blur measured on native clear glass: a 21% core of 0.24 pt over a 79% halo of 1.41 pt.
    public static let nativeClear = ClearGlassBlur(coreRadius: 0.243, haloRadius: 1.41, coreWeight: 0.21)

    /// A heavier-tailed, lens-like blur: a tight core, a mid component and a wide glow, close to the soft shoulder and long
    /// tail of a real defocused point (a Moffat-like profile) and without the plateau of a box or disc.
    public static let optical = ClearGlassBlur(components: [
        Component(radius: 0.35, weight: 0.45), Component(radius: 1.2, weight: 0.35),
        Component(radius: 3.6, weight: 0.20),
    ])

    /// Frosted glass: no sharp core, a soft body and a wide halo.
    public static let frosted = ClearGlassBlur(components: [
        Component(radius: 1.2, weight: 0.35), Component(radius: 3.2, weight: 0.65),
    ])
}

/// How far the backdrop is pulled inward near the edge, as a function of the depth below the edge, in points.
///
/// Native clear glass uses a circular arc: `depth * (1 - sqrt(t * (2 - t)))`, with `t = clamp(d / height, 0, 1)`.
/// This has the steep slope at the very edge that an exponential/Gaussian approximation misses (diary 15).
public struct ClearGlassRim: Equatable, Sendable {
    public enum Profile: Equatable, Sendable {
        case exponentialAndGaussian
        case circularArc
    }

    public var profile: Profile
    /// Exponential amplitude, or the arc's total pull at the edge, in points.
    public var edgeDepth: CGFloat
    /// Exponential falloff depth, or the arc's height, in points.
    public var edgeFalloff: CGFloat
    public var bodyDepth: CGFloat
    public var bodyWidth: CGFloat

    public init(
        edgeDepth: CGFloat, edgeFalloff: CGFloat, bodyDepth: CGFloat, bodyWidth: CGFloat,
        profile: Profile = .exponentialAndGaussian
    ) {
        self.profile = profile
        self.edgeDepth = edgeDepth
        self.edgeFalloff = edgeFalloff
        self.bodyDepth = bodyDepth
        self.bodyWidth = bodyWidth
    }

    /// No pull: the glass shows what is directly behind it.
    public static let none = ClearGlassRim(edgeDepth: 0, edgeFalloff: 1, bodyDepth: 0, bodyWidth: 1)

    /// A single Gaussian pull, `depth` points at the edge falling off over `width` points.
    public static func gaussian(depth: CGFloat, width: CGFloat) -> ClearGlassRim {
        ClearGlassRim(edgeDepth: 0, edgeFalloff: 1, bodyDepth: depth, bodyWidth: width)
    }

    /// A circular-arc pull, strongest at the edge and exactly zero past `height` points inside.
    /// `edgeDepth` holds the amplitude and `edgeFalloff` the height; the Gaussian body is unused in this profile.
    public static func circularArc(depth: CGFloat, height: CGFloat) -> ClearGlassRim {
        ClearGlassRim(edgeDepth: depth, edgeFalloff: height, bodyDepth: 0, bodyWidth: 1, profile: .circularArc)
    }

    /// How far, in points, the backdrop is pulled inward at `depth` points below the edge.
    public func pull(atDepth depth: CGFloat) -> CGFloat {
        if profile == .circularArc {
            let t = min(max(depth / max(edgeFalloff, 0.001), 0), 1)
            return edgeDepth * (1 - sqrt(t * (2 - t)))
        }
        return edgeDepth * exp(-depth / max(edgeFalloff, 0.001))
            + bodyDepth * exp(-(depth * depth) / (bodyWidth * bodyWidth))
    }

    /// The AIR shader's circular-arc form, with amplitude/height inferred from native captures: 60 pt over 20 pt.
    public static let nativeClear = circularArc(depth: 60, height: 20)
}

/// The light bouncing around the inside of the rim: a bright stroke along the edge that fades with depth.
///
/// Measured on native clear glass it is added where the edge faces up or down and is absent on the left and right edges,
/// rises with the brightness of the backdrop, and has two parts: a sharp spike at the edge (about 0.37 of full scale over
/// half a point, following |n.y|^1.4) and a soft tail (about 0.14 over 1.75 pt, concentrated on the horizontal edges,
/// |n.y|^10). `n` is the outward normal of the edge.
public struct ClearGlassRimLight: Equatable, Sendable {
    /// Strength of the sharp part at the edge, 0...1 of full scale.
    public var edgeStrength: CGFloat
    /// Depth over which the sharp part fades, in points.
    public var edgeFalloff: CGFloat
    /// How the sharp part concentrates on horizontal edges: it scales as |n.y| to this power (0: the same all round).
    public var edgePower: CGFloat
    /// Strength of the soft tail at the edge, 0...1.
    public var tailStrength: CGFloat
    /// Depth over which the tail fades, in points.
    public var tailFalloff: CGFloat
    /// The same for the tail.
    public var tailPower: CGFloat
    /// How much a brighter backdrop raises the light: it is multiplied by `1 + gain * luma`.
    public var backdropGain: CGFloat

    public init(
        edgeStrength: CGFloat, edgeFalloff: CGFloat, edgePower: CGFloat, tailStrength: CGFloat, tailFalloff: CGFloat,
        tailPower: CGFloat, backdropGain: CGFloat
    ) {
        self.edgeStrength = edgeStrength
        self.edgeFalloff = edgeFalloff
        self.edgePower = edgePower
        self.tailStrength = tailStrength
        self.tailFalloff = tailFalloff
        self.tailPower = tailPower
        self.backdropGain = backdropGain
    }

    public static let none = ClearGlassRimLight(
        edgeStrength: 0, edgeFalloff: 1, edgePower: 0, tailStrength: 0, tailFalloff: 1, tailPower: 0, backdropGain: 0)

    /// The light measured on native clear glass.
    public static let nativeClear = ClearGlassRimLight(
        edgeStrength: 0.365, edgeFalloff: 0.503, edgePower: 1.39, tailStrength: 0.142, tailFalloff: 1.753,
        tailPower: 10,
        backdropGain: 1.43)

    /// The light added at `depth` points below an edge facing straight up or down, over a backdrop of encoded luma `luma`.
    public func contribution(atDepth depth: CGFloat, backdropLuma luma: CGFloat) -> CGFloat {
        (edgeStrength * exp(-depth / max(edgeFalloff, 0.001)) + tailStrength * exp(-depth / max(tailFalloff, 0.001)))
            * (1 + backdropGain * luma)
    }
}

public struct ClearGlassConfiguration: Equatable, Sendable {
    public var shape: GlassShape
    /// The blur of what is behind the glass.
    public var blur: ClearGlassBlur
    /// How the backdrop is pulled inward near the edge.
    public var rim: ClearGlassRim
    /// The additive lift over black, 0...1.
    public var lift: CGFloat
    /// How quickly the lift fades as the backdrop gets brighter, 0...1.
    public var liftFalloff: CGFloat
    /// The colour of the lift over black. White is the neutral veil of native glass; set `lift` to 0 to remove it.
    public var veilColor: ClearGlassColor
    /// Colour fringing at the rim: red is pulled `1 + chromatic` times as far as green and blue `1 - chromatic` times. Native
    /// clear glass has none; it is off by default.
    public var chromatic: CGFloat
    /// How the light bouncing around the rim looks.
    public var rimLight: ClearGlassRimLight
    /// Strength of the dark ring just outside the shape, 0...1. Zero turns it off.
    public var outline: CGFloat
    /// 0 darkens the ring equally all round; 1 only where the edge faces left or right, as native glass does.
    public var outlineDirection: CGFloat
    /// How far outside the edge the ring reaches, in points.
    public var outlineReach: CGFloat

    public init(
        shape: GlassShape = .roundedRect(radii: GlassCornerRadii(32)), blur: ClearGlassBlur = .nativeClear,
        rim: ClearGlassRim = .nativeClear,
        lift: CGFloat = 32.0 / 255, liftFalloff: CGFloat = 0.83, veilColor: ClearGlassColor = .white,
        chromatic: CGFloat = 0,
        rimLight: ClearGlassRimLight = .nativeClear,
        outline: CGFloat = 0.3785, outlineReach: CGFloat = 0.82, outlineDirection: CGFloat = 1
    ) {
        self.shape = shape
        self.blur = blur
        self.rim = rim
        self.lift = lift
        self.liftFalloff = liftFalloff
        self.veilColor = veilColor
        self.chromatic = chromatic
        self.rimLight = rimLight
        self.outline = outline
        self.outlineReach = outlineReach
        self.outlineDirection = outlineDirection
    }

    /// Native clear glass as fitted against iOS 27 (light appearance).
    public static func nativeClear(shape: GlassShape) -> ClearGlassConfiguration {
        ClearGlassConfiguration(shape: shape)
    }
}

/// The shader's uniform block. The layout is the Metal struct's, field for field; `ClearGlassLayoutTests` pins it.
struct ClearGlassUniforms: Equatable {
    var viewSize: SIMD2<Float>
    var sourceOrigin: SIMD2<Float>
    var sourceSize: SIMD2<Float>
    var halfSize: SIMD2<Float>
    var radii: SIMD4<Float>
    var sdfRect: SIMD4<Float>
    var rimEdge: Float
    var rimEdgeFalloff: Float
    var rimBody: Float
    var rimBodyWidth: Float
    var lift: Float
    var lumaFalloff: Float
    var outline: Float
    var outlineReach: Float
    var outlineDirection: Float
    var lightEdge: Float
    var lightEdgeFalloff: Float
    var lightEdgePower: Float
    var lightTail: Float
    var lightTailFalloff: Float
    var lightTailPower: Float
    var lightGain: Float
    var weightsEdge: SIMD4<Float>
    var weightsInner: SIMD4<Float>
    var veilColor: SIMD4<Float>
    var rampDepth: Float
    var rampCurve: Float
    var chromatic: Float
    var rimProfile: Int32
}

extension ClearGlassConfiguration {
    /// The ring outside the shape needs room to be drawn: the layer extends this many points beyond the shape.
    var margin: CGFloat { outline > 0 ? (outlineReach + 1).rounded(.up) : 0 }

    /// Uniforms for glass of `size` points drawn at `scale` pixels per point, in a view that extends `margin` points
    /// beyond the shape on every side, over a source texture. `sourceOrigin` is where the view's top-left sits in the
    /// source, in pixels.
    func uniforms(size: CGSize, scale: CGFloat, sourceOrigin: CGPoint, sourceSize: CGSize) -> ClearGlassUniforms {
        let outer = CGSize(width: size.width + 2 * margin, height: size.height + 2 * margin)
        let rim = self.rim.constrained(to: size, chromatic: chromatic)
        return ClearGlassUniforms(
            viewSize: SIMD2(Float(outer.width * scale), Float(outer.height * scale)),
            sourceOrigin: SIMD2(Float(sourceOrigin.x), Float(sourceOrigin.y)),
            sourceSize: SIMD2(Float(sourceSize.width), Float(sourceSize.height)),
            halfSize: SIMD2(Float(size.width * scale / 2), Float(size.height * scale / 2)),
            radii: shape.shaderRadii(size: size, scale: scale),
            sdfRect: SIMD4(0, 0, Float(outer.width * scale), Float(outer.height * scale)),
            rimEdge: Float(rim.edgeDepth * scale), rimEdgeFalloff: Float(rim.edgeFalloff * scale),
            rimBody: Float(rim.bodyDepth * scale), rimBodyWidth: Float(rim.bodyWidth * scale), lift: Float(lift),
            lumaFalloff: Float(liftFalloff), outline: Float(outline),
            outlineReach: Float(outlineReach * scale), outlineDirection: Float(outlineDirection),
            lightEdge: Float(rimLight.edgeStrength), lightEdgeFalloff: Float(rimLight.edgeFalloff * scale),
            lightEdgePower: Float(rimLight.edgePower), lightTail: Float(rimLight.tailStrength),
            lightTailFalloff: Float(rimLight.tailFalloff * scale), lightTailPower: Float(rimLight.tailPower),
            lightGain: Float(rimLight.backdropGain), weightsEdge: blurWeights.edge, weightsInner: blurWeights.inner,
            veilColor: SIMD4(Float(veilColor.red), Float(veilColor.green), Float(veilColor.blue), 0),
            rampDepth: Float(blur.rampDepth * scale), rampCurve: Float(blur.rampCurve), chromatic: Float(chromatic),
            rimProfile: rim.profile == .circularArc ? 1 : 0
        )
    }
}

extension ClearGlassConfiguration {
    /// The blur weights at the edge and deep inside, each normalised to sum to one over the components in use.
    var blurWeights: (edge: SIMD4<Float>, inner: SIMD4<Float>) {
        func normalised(_ values: [CGFloat]) -> SIMD4<Float> {
            let clamped = values.map { $0.isFinite ? max($0, 0) : 0 }
            guard let largest = clamped.max(), largest > 0 else { return SIMD4(1, 0, 0, 0) }
            // Scaling before summing avoids overflow for finite but very large weights.
            let scaled = clamped.map { $0 / largest }
            let total = scaled.reduce(0, +)
            var result = SIMD4<Float>.zero
            for (index, value) in scaled.enumerated() { result[index] = Float(value / total) }
            return result
        }
        return (
            normalised(blur.activeComponents.map(\.edgeWeight)), normalised(blur.activeComponents.map(\.innerWeight))
        )
    }
}

extension ClearGlassConfiguration {
    /// The rim's pull, in pixels, at a depth in pixels, for a layer drawn at `scale`.
    func pullInPixels(atDepth depth: Float, scale: CGFloat, rim: ClearGlassRim? = nil) -> Float {
        Float((rim ?? self.rim).pull(atDepth: CGFloat(depth) / scale) * scale)
    }

    /// How far beyond the layer the glass can look, in pixels, so the blur can be computed that far out.
    ///
    /// The rim pulls the backdrop from along the inward normal by up to `pull(0)` pixels. A shape thinner than that, or one
    /// whose inward normals point toward its own bounding box (a triangle's base corners), looks past the box; samples there
    /// would otherwise read texels the blur never wrote, which are black. `field` is the shape's field when it is a path;
    /// an analytic shape is a rounded rectangle, whose normals point inward, so only a thin one can look out.
    func lookReach(size: CGSize, scale: CGFloat, field: GlassDistanceField?) -> Float {
        let rim = self.rim.constrained(to: size, chromatic: chromatic)
        if let field {
            return field.lookReach(chromatic: Float(chromatic)) { pullInPixels(atDepth: $0, scale: scale, rim: rim) }
        }
        // Straight opposite edges `thickness` apart: from depth d a sample lands d + pull(d) from the near edge.
        let thickness = Float(min(size.width, size.height) * scale)
        var overshoot: Float = 0
        var depth: Float = 0
        while depth <= thickness {
            let pull = pullInPixels(atDepth: depth, scale: scale, rim: rim)
            for factor in [1 - Float(chromatic), 1 + Float(chromatic)] {
                let position = depth + pull * factor
                overshoot = max(overshoot, -position, position - thickness)
            }
            depth += 1
        }
        return overshoot
    }
}

#if canImport(Metal)
    extension ClearGlassConfiguration {
        /// The blur in pixels of a source drawn at `scale` pixels per point.
        func blurPlan(scale: CGFloat) -> BlurPlan {
            BlurPlan(sigmas: blur.activeComponents.map { Float($0.radius * scale) })
        }
    }
#endif
