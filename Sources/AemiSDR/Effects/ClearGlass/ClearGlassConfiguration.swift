//
//  ClearGlassConfiguration.swift
//  AemiSDR
//
//  The look of clear glass, as measured on native Liquid Glass (clear), in points. See ADR-0008.
//

import CoreGraphics

/// The blur of what is behind the glass: a tight core and a wide halo, each an exact Gaussian, mixed.
///
/// Measured on native clear glass the blur is not one Gaussian: a sharp core over a long soft halo (the best-fit kernel
/// has weight 0.31 at one pixel and a flat tail of about 0.05 out to eight). Two Gaussians reproduce that with half the
/// error of one (rms 0.0157 against 0.0276 in the interior) and stay smooth and free of the plateau of a box or disc.
public struct ClearGlassBlur: Equatable, Sendable {
    /// Standard deviation of the tight component, in points.
    public var coreRadius: CGFloat
    /// Standard deviation of the wide component, in points.
    public var haloRadius: CGFloat
    /// How much of the result is the core, 0...1. One makes it a single Gaussian.
    public var coreWeight: CGFloat

    public init(coreRadius: CGFloat, haloRadius: CGFloat, coreWeight: CGFloat) {
        self.coreRadius = coreRadius
        self.haloRadius = haloRadius
        self.coreWeight = coreWeight
    }

    /// A single Gaussian of standard deviation `radius` points.
    public static func gaussian(_ radius: CGFloat) -> ClearGlassBlur {
        ClearGlassBlur(coreRadius: radius, haloRadius: radius, coreWeight: 1)
    }

    /// The blur measured on native clear glass: a 21% core of 0.24 pt over a 79% halo of 1.41 pt.
    public static let nativeClear = ClearGlassBlur(coreRadius: 0.243, haloRadius: 1.41, coreWeight: 0.21)
}

/// How far the backdrop is pulled inward near the edge, as a function of the depth below the edge, in points.
///
/// Measured on native clear glass the pull depends on depth alone, identically for every shape (a square, a capsule, a
/// circle, a rounded rectangle and a triangle agree to 1 or 2 px), and is purely inward. It is the sum of a sharp
/// exponential spike at the edge and a broad Gaussian body: `edgeDepth * exp(-d / edgeFalloff) + bodyDepth * exp(-(d / bodyWidth)^2)`.
public struct ClearGlassRim: Equatable, Sendable {
    public var edgeDepth: CGFloat
    public var edgeFalloff: CGFloat
    public var bodyDepth: CGFloat
    public var bodyWidth: CGFloat

    public init(edgeDepth: CGFloat, edgeFalloff: CGFloat, bodyDepth: CGFloat, bodyWidth: CGFloat) {
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

    /// How far, in points, the backdrop is pulled inward at `depth` points below the edge. The shader evaluates the same sum.
    public func pull(atDepth depth: CGFloat) -> CGFloat {
        edgeDepth * exp(-depth / max(edgeFalloff, 0.001)) + bodyDepth * exp(-(depth * depth) / (bodyWidth * bodyWidth))
    }

    /// The pull measured on native clear glass: 29.1 pt spike decaying over 2.5 pt, plus a 21.4 pt body 9.6 pt wide.
    public static let nativeClear = ClearGlassRim(
        edgeDepth: 29.09, edgeFalloff: 2.522, bodyDepth: 21.37, bodyWidth: 9.63)
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
        lift: CGFloat = 32.0 / 255, liftFalloff: CGFloat = 0.83, rimLight: ClearGlassRimLight = .nativeClear,
        outline: CGFloat = 0.3785, outlineReach: CGFloat = 0.82, outlineDirection: CGFloat = 1
    ) {
        self.shape = shape
        self.blur = blur
        self.rim = rim
        self.lift = lift
        self.liftFalloff = liftFalloff
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
}

extension ClearGlassConfiguration {
    /// The ring outside the shape needs room to be drawn: the layer extends this many points beyond the shape.
    var margin: CGFloat { outline > 0 ? (outlineReach + 1).rounded(.up) : 0 }

    /// Uniforms for glass of `size` points drawn at `scale` pixels per point, in a view that extends `margin` points
    /// beyond the shape on every side, over a source texture. `sourceOrigin` is where the view's top-left sits in the
    /// source, in pixels.
    func uniforms(size: CGSize, scale: CGFloat, sourceOrigin: CGPoint, sourceSize: CGSize) -> ClearGlassUniforms {
        let outer = CGSize(width: size.width + 2 * margin, height: size.height + 2 * margin)
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
            lightGain: Float(rimLight.backdropGain)
        )
    }
}

#if canImport(Metal)
    extension ClearGlassConfiguration {
        /// The blur in pixels of a source drawn at `scale` pixels per point.
        func blurPlan(scale: CGFloat) -> BlurPlan {
            BlurPlan(
                coreSigma: Float(blur.coreRadius * scale), haloSigma: Float(blur.haloRadius * scale),
                coreWeight: Float(min(max(blur.coreWeight, 0), 1)))
        }
    }
#endif
