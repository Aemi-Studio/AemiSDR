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

public struct ClearGlassConfiguration: Equatable, Sendable {
    public var shape: GlassShape
    /// The blur of what is behind the glass.
    public var blur: ClearGlassBlur
    /// How far the backdrop is pulled inward at the very edge, in points.
    public var rimDepth: CGFloat
    /// Width of the Gaussian falloff of that pull away from the edge, in points.
    public var rimWidth: CGFloat
    /// The additive lift over black, 0...1.
    public var lift: CGFloat
    /// How quickly the lift fades as the backdrop gets brighter, 0...1.
    public var liftFalloff: CGFloat
    /// Strength of the dark ring just outside the shape, 0...1. Zero turns it off.
    public var outline: CGFloat
    /// How far outside the edge the ring reaches, in points.
    public var outlineReach: CGFloat

    public init(
        shape: GlassShape = .roundedRect(radii: GlassCornerRadii(32)), blur: ClearGlassBlur = .nativeClear,
        rimDepth: CGFloat = 27.9,
        rimWidth: CGFloat = 9.1, lift: CGFloat = 0.1216, liftFalloff: CGFloat = 0.57, outline: CGFloat = 0.3785,
        outlineReach: CGFloat = 0.82
    ) {
        self.shape = shape
        self.blur = blur
        self.rimDepth = rimDepth
        self.rimWidth = rimWidth
        self.lift = lift
        self.liftFalloff = liftFalloff
        self.outline = outline
        self.outlineReach = outlineReach
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
    var rimDepth: Float
    var rimWidth: Float
    var lift: Float
    var lumaFalloff: Float
    var edge: Float
    var outline: Float
    var outlineReach: Float
    var pad2: Float = 0
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
            rimDepth: Float(rimDepth * scale), rimWidth: Float(rimWidth * scale), lift: Float(lift),
            lumaFalloff: Float(liftFalloff), edge: 1, outline: Float(outline), outlineReach: Float(outlineReach * scale)
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
