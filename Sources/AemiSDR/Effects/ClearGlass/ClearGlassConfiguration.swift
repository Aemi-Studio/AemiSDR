//
//  ClearGlassConfiguration.swift
//  AemiSDR
//
//  The look of clear glass, as measured on native Liquid Glass (clear), in points. See ADR-0008.
//

import CoreGraphics

public struct ClearGlassConfiguration: Equatable, Sendable {
    public var shape: GlassShape
    /// Standard deviation of the Gaussian blur of what is behind the glass, in points.
    public var blur: CGFloat
    /// How far the backdrop is pulled inward at the very edge, in points.
    public var rimDepth: CGFloat
    /// Width of the Gaussian falloff of that pull away from the edge, in points.
    public var rimWidth: CGFloat
    /// The additive lift over black, 0...1.
    public var lift: CGFloat
    /// How quickly the lift fades as the backdrop gets brighter, 0...1.
    public var liftFalloff: CGFloat

    public init(
        shape: GlassShape = .roundedRect(radii: GlassCornerRadii(32)), blur: CGFloat = 0.94, rimDepth: CGFloat = 27.9,
        rimWidth: CGFloat = 9.1, lift: CGFloat = 0.131, liftFalloff: CGFloat = 0.72
    ) {
        self.shape = shape
        self.blur = blur
        self.rimDepth = rimDepth
        self.rimWidth = rimWidth
        self.lift = lift
        self.liftFalloff = liftFalloff
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
    var pad0: Float = 0
    var pad1: Float = 0
    var pad2: Float = 0
}

extension ClearGlassConfiguration {
    /// Uniforms for a view of `size` points drawn at `scale` pixels per point over a source texture.
    func uniforms(size: CGSize, scale: CGFloat, sourceOrigin: CGPoint, sourceSize: CGSize) -> ClearGlassUniforms {
        ClearGlassUniforms(
            viewSize: SIMD2(Float(size.width * scale), Float(size.height * scale)),
            sourceOrigin: SIMD2(Float(sourceOrigin.x), Float(sourceOrigin.y)),
            sourceSize: SIMD2(Float(sourceSize.width), Float(sourceSize.height)),
            halfSize: SIMD2(Float(size.width * scale / 2), Float(size.height * scale / 2)),
            radii: shape.shaderRadii(size: size, scale: scale),
            sdfRect: SIMD4(0, 0, Float(size.width * scale), Float(size.height * scale)),
            rimDepth: Float(rimDepth * scale), rimWidth: Float(rimWidth * scale), lift: Float(lift),
            lumaFalloff: Float(liftFalloff), edge: 1)
    }
}
