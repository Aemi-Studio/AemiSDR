//
//  AlphaMaskCache.swift
//  AemiSDR
//

import CoreImage
import OSLog

/// AlphaMaskCache provides cached Core Image kernels for alpha mask generation with easing effects.
///
/// This class extends CIKernelCache to provide specialized Metal-based Core Image kernels
/// for creating alpha masks with various shapes and easing transitions. These kernels are
/// primarily used for compositing operations where precise alpha channel control is needed.
///
/// The kernels generate grayscale/alpha masks where:
/// - White (1.0) areas are fully opaque
/// - Black (0.0) areas are fully transparent
/// - Gray values provide proportional opacity
/// - Many kernels support inversion for destination-out compositing
///
/// All kernels use `half4` return types for better performance on mobile GPUs.
final class AlphaMaskCache: CIKernelCache {
    // MARK: - Gradient Alpha Masks

    /// Creates an ease-in alpha mask with directional control.
    ///
    /// Generates a quadratic ease-in gradient that starts transparent and becomes opaque.
    /// The easing creates a more natural acceleration compared to linear gradients.
    /// Supports both top-to-bottom and bottom-to-top directions.
    ///
    /// Metal function signature:
    /// `half4 easeInAlphaMask(float widthPx, float heightPx, float startOffset, float direction, float inverted, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the mask in pixels
    /// - heightPx: Height of the mask in pixels
    /// - startOffset: Start position as fraction of height (0.0 to 0.999)
    /// - direction: 0 for top-to-bottom, >0.5 for bottom-to-top
    /// - inverted: 0 for normal, >0.5 for inverted (destination-out style)
    static let easeInAlphaMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "easeInAlphaMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create easeInAlphaMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    // MARK: - Rounded Rectangle Alpha Masks

    /// Creates a rounded rectangle alpha mask with inversion support.
    ///
    /// Generates precise alpha masks in rounded rectangle shapes using signed distance fields.
    /// Supports inversion for destination-out compositing operations. The mask has sharp
    /// edges with smooth antialiasing at the boundaries.
    ///
    /// Metal function signature:
    /// `float4 roundedRectAlphaMask(float widthPx, float heightPx, float cornerRadiusPx, float fadeInWidthPx, float inverted, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the rounded rectangle in pixels
    /// - heightPx: Height of the rounded rectangle in pixels
    /// - cornerRadiusPx: Corner radius in pixels
    /// - fadeInWidthPx: Soft edge transition width in pixels
    /// - inverted: 0 for normal, >0.5 for inverted mask
    static let roundedRectAlphaMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "roundedRectAlphaMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create roundedRectAlphaMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    /// Creates a rounded rectangle alpha mask with eased edge transitions.
    ///
    /// Similar to roundedRectAlphaMask but uses quadratic easing for distance falloff
    /// instead of linear transitions. This creates more natural, organic-looking edges
    /// that blend better with photographic content.
    ///
    /// Metal function signature:
    /// `float4 roundedRectEaseAlphaMask(float widthPx, float heightPx, float cornerRadiusPx, float fadeInWidthPx, float inverted, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the rounded rectangle in pixels
    /// - heightPx: Height of the rounded rectangle in pixels
    /// - cornerRadiusPx: Corner radius in pixels
    /// - fadeInWidthPx: Eased edge transition width in pixels
    /// - inverted: 0 for normal, >0.5 for inverted mask
    static let roundedRectEaseAlphaMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "roundedRectEaseAlphaMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create roundedRectEaseAlphaMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    // MARK: - Superellipse Alpha Masks

    /// Creates a superellipse alpha mask with inversion support.
    ///
    /// Generates mathematically precise superellipse (squircle) shapes that match iOS
    /// design language. Uses gradient-based distance calculation for accurate shape
    /// rendering with smooth antialiasing. Supports inversion for compositing operations.
    ///
    /// Metal function signature:
    /// `float4 superellipseAlphaMask(float widthPx, float heightPx, float cornerRadiusPx, float fadeInWidthPx, float exponent, float inverted, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the superellipse in pixels
    /// - heightPx: Height of the superellipse in pixels
    /// - cornerRadiusPx: Visual corner radius parameter in pixels
    /// - fadeInWidthPx: Soft edge transition width in pixels
    /// - exponent: Superellipse exponent (higher = more rectangular, lower = more circular)
    /// - inverted: 0 for normal, >0.5 for inverted mask
    static let superellipseAlphaMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "superellipseAlphaMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create superellipseAlphaMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    /// Creates a superellipse alpha mask with eased edge transitions and inversion support.
    ///
    /// Combines the mathematical precision of superellipse shapes with quadratic easing
    /// for the most natural-looking masks. This kernel provides the highest visual quality
    /// for iOS-style rounded shapes with organic edge transitions.
    ///
    /// Metal function signature:
    /// `float4 superellipseEaseAlphaMask(float widthPx, float heightPx, float cornerRadiusPx, float fadeInWidthPx, float exponent, float inverted, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the superellipse in pixels
    /// - heightPx: Height of the superellipse in pixels
    /// - cornerRadiusPx: Visual corner radius parameter in pixels
    /// - fadeInWidthPx: Eased edge transition width in pixels
    /// - exponent: Superellipse exponent (higher = more rectangular, lower = more circular)
    /// - inverted: 0 for normal, >0.5 for inverted mask
    static let superellipseEaseAlphaMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "superellipseEaseAlphaMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create superellipseEaseAlphaMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()
}
