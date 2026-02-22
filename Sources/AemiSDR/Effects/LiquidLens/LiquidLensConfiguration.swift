//
//  LiquidLensConfiguration.swift
//  AemiSDR
//

import simd

/// Uniform buffer matching the Metal `LiquidLensUniforms` struct layout.
///
/// This struct must remain byte-identical to the Metal-side definition.
/// Verify with `MemoryLayout<LiquidLensUniforms>.stride`.
public struct LiquidLensUniforms: Sendable, Equatable {
    public var center: SIMD2<Float>
    public var textureSize: SIMD2<Float>
    public var radius: Float
    public var strength: Float
    public var lensCurvature: Float
    public var cornerRadius: Float
    public var falloffType: Int32
    public var falloffLength: Float
    public var falloffIntensity: Float
    public var chromaticAmount: Float
    public var materialType: Int32
    public var useRadialDirection: Int32
    public var overlayMode: Int32
}

/// Configuration for the liquid lens distortion effect.
///
/// All spatial values (center, radius, cornerRadius) are in points and will be
/// converted to pixel coordinates by `toUniforms(textureSize:)`.
public struct LiquidLensConfiguration: Sendable, Equatable, Hashable {

    /// Center of the lens effect in points.
    public var center: SIMD2<Float>

    /// Half-size of the lens region in points.
    public var radius: Float

    /// Overall effect strength multiplier. Negative values invert the lens.
    public var strength: Float

    /// Lens surface curvature (0 = flat, 1 = hemisphere).
    public var lensCurvature: Float

    /// Corner rounding for the lens shape (0 = square, radius = circle).
    public var cornerRadius: Float

    /// Falloff transition curve.
    public var falloff: LiquidLensFalloff

    /// Distance from edge where falloff reaches zero (0–1, fraction of radius).
    public var falloffLength: Float

    /// Falloff strength multiplier (0 = no falloff, 1 = full).
    public var falloffIntensity: Float

    /// Chromatic aberration strength (0 = none, 1 = full physics).
    public var chromaticAmount: Float

    /// Optical material determining dispersion characteristics.
    public var material: LiquidLensMaterial

    /// `true` for smooth radial direction, `false` for shape-aware direction.
    public var useRadialDirection: Bool

    /// When `true`, pixels outside the lens area are transparent instead of showing
    /// the undistorted source. Use this when the lens is an overlay on live content.
    public var overlayMode: Bool

    public init(
        center: SIMD2<Float> = .zero,
        radius: Float = 150,
        strength: Float = 1.0,
        lensCurvature: Float = 0.5,
        cornerRadius: Float = 0,
        falloff: LiquidLensFalloff = .easeInOut,
        falloffLength: Float = 1.0,
        falloffIntensity: Float = 0.5,
        chromaticAmount: Float = 1.0,
        material: LiquidLensMaterial = .crownGlass,
        useRadialDirection: Bool = true,
        overlayMode: Bool = false
    ) {
        self.center = center
        self.radius = radius
        self.strength = strength
        self.lensCurvature = lensCurvature
        self.cornerRadius = cornerRadius
        self.falloff = falloff
        self.falloffLength = falloffLength
        self.falloffIntensity = falloffIntensity
        self.chromaticAmount = chromaticAmount
        self.material = material
        self.useRadialDirection = useRadialDirection
        self.overlayMode = overlayMode
    }

    /// Converts the configuration to a Metal-compatible uniform buffer.
    ///
    /// - Parameters:
    ///   - textureSize: The texture dimensions in pixels.
    ///   - scale: Display scale factor (points → pixels). Pass `contentsScale` from `CAMetalLayer`.
    /// - Returns: A `LiquidLensUniforms` ready to be passed to the GPU.
    public func toUniforms(textureSize: SIMD2<Float>, scale: Float = 1.0) -> LiquidLensUniforms {
        LiquidLensUniforms(
            center: center * scale,
            textureSize: textureSize,
            radius: radius * scale,
            strength: strength,
            lensCurvature: lensCurvature,
            cornerRadius: cornerRadius * scale,
            falloffType: Int32(falloff.rawValue),
            falloffLength: falloffLength,
            falloffIntensity: falloffIntensity,
            chromaticAmount: chromaticAmount,
            materialType: Int32(material.rawValue),
            useRadialDirection: useRadialDirection ? 1 : 0,
            overlayMode: overlayMode ? 1 : 0
        )
    }
}
