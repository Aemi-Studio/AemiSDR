//
//  LiquidLensConfiguration.swift
//  AemiSDR
//

import Foundation
import simd

/// Hashable specialization key selecting which compiled fragment-shader
/// variant the renderer should use. The renderer caches one
/// `MTLRenderPipelineState` per distinct key (per device), built lazily on
/// first use. All fields correspond to Metal function constants defined in
/// `LiquidLens.metal`.
public struct LiquidLensPipelineKey: Hashable, Sendable {
    public let chromaticEnabled: Bool  // function_constant(0)
    public let falloffType: Int32  // function_constant(1)
    public let enableFresnel: Bool  // function_constant(2)
    public let enableSpectral: Bool  // function_constant(3)
    public let enableAspheric: Bool  // function_constant(4)

    public init(
        chromaticEnabled: Bool,
        falloffType: Int32,
        enableFresnel: Bool = false,
        enableSpectral: Bool = false,
        enableAspheric: Bool = false
    ) {
        self.chromaticEnabled = chromaticEnabled
        self.falloffType = falloffType
        self.enableFresnel = enableFresnel
        self.enableSpectral = enableSpectral
        self.enableAspheric = enableAspheric
    }
}

/// How corner radius is specified for the liquid lens shape.
public enum LiquidLensCornerRadius: Sendable, Equatable, Hashable {
    /// A fraction of the longer half-size dimension (0 = square, 1 = fully rounded).
    ///
    /// At 1.0, the corner radius equals `max(halfSize.x, halfSize.y)`,
    /// which the shader clamps to `min(halfSize.x, halfSize.y)` producing a capsule or circle.
    case proportional(Float)

    /// An explicit value in points.
    case points(Float)

    /// Resolves to a corner radius in points for the given half-size.
    internal func resolve(halfSize: SIMD2<Float>) -> Float {
        switch self {
        case .proportional(let fraction):
            return fraction * max(halfSize.x, halfSize.y)
        case .points(let pts):
            return pts
        }
    }
}

/// Uniform buffer matching the Metal `LiquidLensUniforms` struct layout.
///
/// This struct must remain byte-identical to the Metal-side definition.
/// Verify with `MemoryLayout<LiquidLensUniforms>.stride` (expected 104).
public struct LiquidLensUniforms: Sendable, Equatable {
    public var center: SIMD2<Float>
    public var textureSize: SIMD2<Float>
    public var halfSize: SIMD2<Float>
    public var strength: Float
    public var lensCurvature: Float
    public var cornerRadius: Float
    public var falloffType: Int32
    public var falloffLength: Float
    public var falloffIntensity: Float
    public var chromaticAmount: Float
    public var materialType: Int32
    public var overlayMode: Int32
    public var refractiveIndexRed: Float
    public var refractiveIndexGreen: Float
    public var refractiveIndexBlue: Float
    /// Ratio `n_air / n_λ` for the red channel (656.3 nm, Fraunhofer C). The
    /// shader uses this directly as the `eta` argument to MSL `refract()` for
    /// per-fragment Snell refraction. Stored on CPU side as `airRefractiveIndex
    /// / refractiveIndexRed`.
    public var airOverRed: Float
    /// Ratio `n_air / n_λ` for the green channel (546.1 nm, Fraunhofer e).
    public var airOverGreen: Float
    /// Ratio `n_air / n_λ` for the blue channel (486.1 nm, Fraunhofer F).
    public var airOverBlue: Float
    /// Pixel-space width of the soft transition band that smooths the inner-rect
    /// medial-axis (q.x = q.y) discontinuity in the SDF gradient. Resolved from
    /// `LiquidLensConfiguration.diagonalBand` (points) at `toUniforms` time.
    public var diagonalBand: Float
    /// Aspheric profile coefficient applied as `surfaceTilt = c·r·(1 + k2·(c·r)² + k4·(c·r)⁴)`.
    /// Only consumed when the pipeline is specialized with `kEnableAspheric = true`.
    /// `0` produces a pure spherical cap.
    public var asphericK2: Float
    public var asphericK4: Float
    /// `n_air / n_λ` ratio at 440 nm (deep blue) for 5-wavelength spectral
    /// integration. Only sampled when the pipeline is specialized with
    /// `kEnableSpectral = true`.
    public var spectralAirOver0: Float
    /// `n_air / n_λ` ratio at 580 nm (yellow) for 5-wavelength spectral
    /// integration.
    public var spectralAirOver1: Float
}

/// Configuration for the liquid lens distortion effect.
///
/// All spatial values (center, halfSize, cornerRadius) are in points and will be
/// converted to pixel coordinates by `toUniforms(textureSize:)`.
public struct LiquidLensConfiguration: Sendable, Equatable, Hashable {
    /// Center of the lens effect in points.
    public var center: SIMD2<Float>

    /// Half-size of the lens region in points (width/2, height/2).
    public var halfSize: SIMD2<Float>

    /// Overall effect strength multiplier. Negative values invert the lens.
    public var strength: Float

    /// Lens surface curvature (0 = flat, 1 = hemisphere).
    public var lensCurvature: Float

    /// Corner rounding for the lens shape.
    public var cornerRadius: LiquidLensCornerRadius

    /// Falloff transition curve.
    public var falloff: LiquidLensFalloff

    /// Width of the edge fade region as a fraction of min(halfSize).
    /// At 0, the effect has sharp edges; at 1, the fade extends to the center.
    public var falloffLength: Float

    /// Falloff strength multiplier (0 = no falloff, 1 = full).
    public var falloffIntensity: Float

    /// Chromatic aberration amplifier.
    ///
    /// `0` disables chromatic separation. `30` (the default) is the calibrated
    /// baseline producing visible color fringing at strength 1.0. Higher values
    /// exaggerate the effect; lower values reduce it. Clamped to `[0, 30]` internally.
    ///
    /// This is an artistic amplifier rather than a physical [0, 1] interpolation:
    /// the shader uses `mix(green, channel, amount)` where `amount > 1` extrapolates
    /// beyond the physically-correct displacement.
    public var chromaticAmount: Float

    /// Optical material determining dispersion characteristics.
    public var material: LiquidLensMaterial

    /// When `true`, pixels outside the lens area are transparent instead of showing
    /// the undistorted source. Use this when the lens is an overlay on live content.
    public var overlayMode: Bool

    /// Width (in points) of the soft transition band that smooths the
    /// inner-rectangle medial-axis discontinuity in the SDF gradient. Inside
    /// the band the displacement direction blends smoothly across the
    /// `q.x = q.y` diagonal; outside the band it equals the true axial SDF
    /// normal. Smaller values = sharper diagonal transition; larger values =
    /// wider smoothing zone. Default `6` points is invisible at retina
    /// densities while removing the rate-of-change kink that earlier
    /// `normalize((dy, dx))` form had at the diagonal.
    public var diagonalBand: Float

    /// Second-order aspheric coefficient. `0` (default) gives a pure spherical
    /// cap surface. Non-zero values reshape the surface profile by reducing or
    /// amplifying spherical aberration. Only takes effect when `enableAspheric`
    /// is true.
    public var asphericK2: Float

    /// Fourth-order aspheric coefficient. See `asphericK2`.
    public var asphericK4: Float

    /// Enables Fresnel transmission attenuation in the shader. Real lens
    /// surfaces lose 4–30% of light to reflection (more at grazing angles).
    /// Off by default to preserve the bright artistic look. Triggers a
    /// specialized pipeline variant.
    public var enableFresnel: Bool

    /// Enables 5-wavelength spectral integration for chromatic mode. Replaces
    /// the discrete 3-band RGB sampling with samples at 440/486/546/580/656 nm
    /// reconstructed into RGB. Costs ~2× chromatic-path sample bandwidth.
    /// Eliminates banded fringes at extreme `chromaticAmount` values.
    public var enableSpectral: Bool

    /// Enables the aspheric surface-tilt model in the shader. When `false`,
    /// the lens uses pure spherical-cap geometry regardless of the values of
    /// `asphericK2` / `asphericK4`.
    public var enableAspheric: Bool

    public init(
        center: SIMD2<Float> = .zero,
        halfSize: SIMD2<Float> = SIMD2(150, 150),
        strength: Float = 1.0,
        lensCurvature: Float = 1.0,
        cornerRadius: LiquidLensCornerRadius = .points(0),
        falloff: LiquidLensFalloff = .exponential,
        falloffLength: Float = 1.0,
        falloffIntensity: Float = 1,
        chromaticAmount: Float = 30.0,
        material: LiquidLensMaterial = .water,
        overlayMode: Bool = false,
        diagonalBand: Float = 6.0,
        asphericK2: Float = 0.0,
        asphericK4: Float = 0.0,
        enableFresnel: Bool = false,
        enableSpectral: Bool = false,
        enableAspheric: Bool = false
    ) {
        self.center = center
        self.halfSize = halfSize
        self.strength = strength
        self.lensCurvature = lensCurvature
        self.cornerRadius = cornerRadius
        self.falloff = falloff
        self.falloffLength = falloffLength
        self.falloffIntensity = falloffIntensity
        self.chromaticAmount = chromaticAmount
        self.material = material
        self.overlayMode = overlayMode
        self.diagonalBand = diagonalBand
        self.asphericK2 = asphericK2
        self.asphericK4 = asphericK4
        self.enableFresnel = enableFresnel
        self.enableSpectral = enableSpectral
        self.enableAspheric = enableAspheric
    }

    /// Returns the function-constant key identifying which compiled fragment
    /// shader variant the renderer should use for this configuration.
    public func pipelineKey() -> LiquidLensPipelineKey {
        // Spectral integration implies chromatic sampling (5 wavelengths into RGB).
        let chromatic = enableSpectral || chromaticAmount > 0.0001
        return LiquidLensPipelineKey(
            chromaticEnabled: chromatic,
            falloffType: Int32(falloff.rawValue),
            enableFresnel: enableFresnel,
            enableSpectral: enableSpectral,
            enableAspheric: enableAspheric
        )
    }

    /// Converts the configuration to a Metal-compatible uniform buffer.
    ///
    /// - Parameters:
    ///   - textureSize: The texture dimensions in pixels.
    ///   - scale: Display scale factor (points → pixels). Pass `contentsScale` from `CAMetalLayer`.
    /// - Returns: A `LiquidLensUniforms` ready to be passed to the GPU.
    public func toUniforms(textureSize: SIMD2<Float>, scale: Float = 1.0) -> LiquidLensUniforms {
        let coefficients = Self.sellmeierCoefficients(for: material)
        assert(
            MemoryLayout<LiquidLensUniforms>.stride == 104,
            "LiquidLensUniforms layout mismatch — Metal expects 104-byte stride, got \(MemoryLayout<LiquidLensUniforms>.stride)"
        )

        let nRed = Self.sellmeierIndex(wavelength: Self.redWavelength, coefficients: coefficients)
        let nGreen = Self.sellmeierIndex(wavelength: Self.greenWavelength, coefficients: coefficients)
        let nBlue = Self.sellmeierIndex(wavelength: Self.blueWavelength, coefficients: coefficients)
        let nSpec0 = Self.sellmeierIndex(wavelength: Self.spectral0Wavelength, coefficients: coefficients)
        let nSpec1 = Self.sellmeierIndex(wavelength: Self.spectral1Wavelength, coefficients: coefficients)

        let clampedCurvature = min(max(lensCurvature, 0), 1)
        let nAir = Self.airRefractiveIndex

        // `lensCurvature` is clamped here so the shader can use it directly
        // (per-fragment `asin(normalizedRadius · lensCurvature)` is now
        // computed via MSL `refract()` on a 3D normal; clamping CPU-side keeps
        // the GPU free of one `clamp` per fragment).
        return LiquidLensUniforms(
            center: center * scale,
            textureSize: textureSize,
            halfSize: halfSize * scale,
            strength: strength,
            lensCurvature: clampedCurvature,
            cornerRadius: cornerRadius.resolve(halfSize: halfSize) * scale,
            falloffType: Int32(falloff.rawValue),
            falloffLength: falloffLength,
            falloffIntensity: falloffIntensity,
            chromaticAmount: chromaticAmount,
            materialType: Int32(material.rawValue),
            overlayMode: overlayMode ? 1 : 0,
            refractiveIndexRed: nRed,
            refractiveIndexGreen: nGreen,
            refractiveIndexBlue: nBlue,
            airOverRed: nAir / nRed,
            airOverGreen: nAir / nGreen,
            airOverBlue: nAir / nBlue,
            diagonalBand: max(diagonalBand, 0) * scale,
            asphericK2: asphericK2,
            asphericK4: asphericK4,
            spectralAirOver0: nAir / nSpec0,
            spectralAirOver1: nAir / nSpec1
        )
    }
}

// MARK: - Layout Verification

extension LiquidLensUniforms {
    /// Compile-time sanity check — Metal shader expects exactly 104 bytes.
    @usableFromInline
    static let _stride: Int = {
        let s = MemoryLayout<LiquidLensUniforms>.stride
        assert(s == 104, "LiquidLensUniforms stride changed to \(s) — update Metal struct to match")
        return s
    }()
}

// MARK: - Sellmeier Coefficients

extension LiquidLensConfiguration {
    /// Four-term Sellmeier dispersion coefficients. The C values are squared
    /// resonance wavelengths (λᵢ²) in µm². A term with B = C = 0 contributes
    /// nothing, so three-term fits use B4 = C4 = 0.
    ///
    /// Sources verified against Schott Zemax catalog 2017-01-20 (BK7, SF11),
    /// Daimon & Masumura 2007 Appl. Opt. 46:3811 (water 20 °C, 4-term),
    /// Sultanova et al. 2009 Acta Phys. Polonica A 116:585 (PMMA, 3-term),
    /// and Peter 1923 / refractiveindex.info (diamond, 2-term).
    fileprivate struct SellmeierCoefficients {
        let b1: Float
        let b2: Float
        let b3: Float
        let b4: Float
        let c1: Float
        let c2: Float
        let c3: Float
        let c4: Float
    }

    fileprivate static let redWavelength: Float = 0.6563  // Fraunhofer C (656.3 nm)
    fileprivate static let greenWavelength: Float = 0.5461  // Fraunhofer e (546.1 nm)
    fileprivate static let blueWavelength: Float = 0.4861  // Fraunhofer F (486.1 nm)
    /// Extra deep-blue wavelength used in 5-wavelength spectral integration.
    fileprivate static let spectral0Wavelength: Float = 0.440  // 440 nm
    /// Extra yellow wavelength used in 5-wavelength spectral integration.
    fileprivate static let spectral1Wavelength: Float = 0.580  // 580 nm

    /// Refractive index of air at standard conditions.
    fileprivate static let airRefractiveIndex: Float = 1.000293

    /// CPU equivalent of single-surface Snell deviation (kept for tests only —
    /// runtime refraction is now per-fragment via MSL `refract()` 3D form).
    fileprivate static func snellDeviation(incidentAngle: Float, n1: Float, n2: Float) -> Float {
        let sinIncident = sin(incidentAngle)
        let sinRefracted = (n1 / n2) * sinIncident
        guard abs(sinRefracted) < 1.0 else { return 0 }
        let refractedAngle = asin(sinRefracted)
        return refractedAngle - incidentAngle
    }

    fileprivate static func sellmeierCoefficients(for material: LiquidLensMaterial) -> SellmeierCoefficients {
        switch material {
        case .crownGlass:
            // Schott N-BK7. Three-term fit, ~5e-6 max error 365 nm – 2.3 µm.
            return SellmeierCoefficients(
                b1: 1.03961212, b2: 0.231792344, b3: 1.01046945, b4: 0,
                c1: 0.00600069867, c2: 0.0200179144, c3: 103.560653, c4: 0
            )
        case .flintGlass:
            // Schott N-SF11. Three-term fit.
            return SellmeierCoefficients(
                b1: 1.73759695, b2: 0.313747346, b3: 1.89878101, b4: 0,
                c1: 0.013188707, c2: 0.0623068142, c3: 155.23629, c4: 0
            )
        case .water:
            // Daimon & Masumura 2007 — four-term fit. Including the IR-resonance
            // term (b4/c4) brings water's accuracy in the visible from ~10⁻³ to
            // the same ~10⁻⁶ band as the optical glasses.
            return SellmeierCoefficients(
                b1: 0.5684027565, b2: 0.1726177391, b3: 0.02086189578, b4: 0.1130748688,
                c1: 0.005101829712, c2: 0.01821153936, c3: 0.02620722293, c4: 10.69792721
            )
        case .acrylic:
            // Sultanova et al. 2009 (PMMA). Three-term fit; more accurate than
            // the single-term landing page on refractiveindex.info.
            return SellmeierCoefficients(
                b1: 0.99654, b2: 0.18964, b3: 0.00411, b4: 0,
                c1: 0.00787, c2: 0.02191, c3: 3.85727, c4: 0
            )
        case .diamond:
            // Peter 1923 / refractiveindex.info — two-term fit. The published
            // formula is n²-1 = 0.3306·λ²/(λ² - 0.1750²) + 4.3356·λ²/(λ² - 0.1060²),
            // so the C denominators are already-squared resonance wavelengths
            // (0.1750² = 0.030625, 0.1060² = 0.011236). The pre-fix coefficients
            // stored the un-squared resonance wavelengths and produced n ≈ 2.84
            // at 546 nm instead of the real ~2.42.
            return SellmeierCoefficients(
                b1: 0.3306, b2: 4.3356, b3: 0, b4: 0,
                c1: 0.030625, c2: 0.011236, c3: 0, c4: 0
            )
        }
    }

    fileprivate static func sellmeierIndex(wavelength: Float, coefficients: SellmeierCoefficients) -> Float {
        let l2 = wavelength * wavelength
        // Each term is B·λ²/(λ²-C). When B=C=0 the term collapses to 0
        // (numerator = 0; denominator = λ² ≠ 0 for visible wavelengths),
        // so degenerate trailing terms are safe.
        let t1 = (coefficients.b1 * l2) / (l2 - coefficients.c1)
        let t2 = (coefficients.b2 * l2) / (l2 - coefficients.c2)
        let t3 = coefficients.b3 == 0 ? 0 : (coefficients.b3 * l2) / (l2 - coefficients.c3)
        let t4 = coefficients.b4 == 0 ? 0 : (coefficients.b4 * l2) / (l2 - coefficients.c4)
        let n2 = 1.0 + t1 + t2 + t3 + t4
        return sqrt(max(Float(1.0), n2))
    }
}
