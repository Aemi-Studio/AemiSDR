//
//  VariableBlurCache.swift
//  AemiSDR
//

import CoreImage
import OSLog

/// VariableBlurCache provides cached Core Image kernels for variable blur effects with different mask types.
///
/// This class extends CIKernelCache to provide specialized Metal-based Core Image kernels
/// for creating variable blur effects. Each kernel generates different types of masks that
/// can be used to control blur intensity across different regions of an image.
///
/// The kernels are lazily loaded from a Metal library and cached for performance.
/// All kernels are CIColorKernels that generate grayscale masks where:
/// - White (1.0) areas receive full blur
/// - Black (0.0) areas receive no blur
/// - Gray values create proportional blur intensity
final class VariableBlurCache: CIKernelCache {
    // MARK: - Gradient Masks

    /// Creates an ease-in gradient mask with directional control.
    ///
    /// Generates a quadratic ease-in gradient that starts transparent and becomes opaque.
    /// The easing creates a more natural acceleration compared to linear gradients.
    /// Supports both top-to-bottom and bottom-to-top directions.
    ///
    /// Metal function signature:
    /// `half4 easeInMask(float widthPx, float heightPx, float startOffset, float direction, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the mask in pixels
    /// - heightPx: Height of the mask in pixels
    /// - startOffset: Start position as fraction of height (0.0 to 0.999)
    /// - direction: 0 for top-to-bottom, >0.5 for bottom-to-top
    static let easeInMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "easeInMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create easeInMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    // MARK: - Rounded Rectangle Masks

    /// Creates a rounded rectangle mask with traditional corner rounding.
    ///
    /// Generates a mask in the shape of a rounded rectangle with smooth edge transitions.
    /// The interior is fully opaque (blur applied) while the exterior fades based on fadeInWidth.
    /// Perfect for creating focus effects where content outside a rounded rectangle is blurred.
    ///
    /// Metal function signature:
    /// `float4 roundedRectMask(float widthPx, float heightPx, float cornerRadiusPx, float fadeInWidthPx, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the rounded rectangle in pixels
    /// - heightPx: Height of the rounded rectangle in pixels
    /// - cornerRadiusPx: Corner radius in pixels
    /// - fadeInWidthPx: Soft edge transition width in pixels
    static let roundedRectMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "roundedRectMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create roundedRectMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    /// Creates a rounded rectangle mask with eased edge transitions.
    ///
    /// Similar to roundedRectMask but uses quadratic easing for distance falloff
    /// instead of smooth hermite interpolation. This creates more natural, organic-looking edges
    /// with faster acceleration near the boundary for better visual appeal.
    ///
    /// Metal function signature:
    /// `float4 roundedRectEaseMask(float widthPx, float heightPx, float cornerRadiusPx, float fadeInWidthPx, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the rounded rectangle in pixels
    /// - heightPx: Height of the rounded rectangle in pixels
    /// - cornerRadiusPx: Corner radius in pixels
    /// - fadeInWidthPx: Eased edge transition width in pixels (uses quadratic ease-in)
    static let roundedRectEaseMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "roundedRectEaseMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create roundedRectEaseMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    // MARK: - Superellipse Masks

    /// Creates a superellipse (true squircle) mask following mathematical precision.
    ///
    /// Generates a mask using the superellipse mathematical formula, which creates
    /// shapes that are more rounded than rectangles but less circular than ellipses.
    /// This closely matches the shape of iOS app icons and UI elements.
    ///
    /// Metal function signature:
    /// `float4 superellipseMask(float widthPx, float heightPx, float cornerRadiusPx, float fadeInWidthPx, float exponent, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the superellipse in pixels
    /// - heightPx: Height of the superellipse in pixels
    /// - cornerRadiusPx: Visual corner radius parameter in pixels
    /// - fadeInWidthPx: Soft edge transition width in pixels
    /// - exponent: Superellipse exponent (higher = more rectangular, lower = more circular)
    static let superellipseMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "superellipseMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create superellipseMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    /// Creates a superellipse mask with eased edge transitions.
    ///
    /// Combines the mathematical precision of superellipse shapes with quadratic easing
    /// for the most natural-looking masks. Uses ease-in acceleration instead of linear
    /// or hermite transitions, providing organic edge falloff that works well with photography.
    ///
    /// Metal function signature:
    /// `float4 superellipseEaseMask(float widthPx, float heightPx, float cornerRadiusPx, float fadeInWidthPx, float exponent, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the superellipse in pixels
    /// - heightPx: Height of the superellipse in pixels
    /// - cornerRadiusPx: Visual corner radius parameter in pixels
    /// - fadeInWidthPx: Eased edge transition width in pixels (uses quadratic ease-in)
    /// - exponent: Superellipse exponent (higher = more rectangular, lower = more circular)
    static let superellipseEaseMask: CIColorKernel? = {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }

        do {
            return try CIColorKernel(functionName: "superellipseEaseMask", fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to create superellipseEaseMask kernel: \(error.localizedDescription)")
            return nil
        }
    }()

    // MARK: - Alpha Masks with Inversion

    /// Creates a rounded rectangle alpha mask with inversion support.
    ///
    /// Similar to roundedRectMask but with the ability to invert the mask.
    /// Ideal for destination-out compositing or creating inverse blur effects.
    ///
    /// Metal function signature:
    /// `float4 roundedRectAlphaMask(float widthPx, float heightPx, float cornerRadiusPx, float fadeInWidthPx, float inverted, coreimage::destination dest)`
    ///
    /// Parameters:
    /// - widthPx: Width of the rounded rectangle in pixels
    /// - heightPx: Height of the rounded rectangle in pixels
    /// - cornerRadiusPx: Corner radius in pixels
    /// - fadeInWidthPx: Soft edge transition width in pixels
    /// - inverted: 0 for normal, 1 for inverted mask
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

    /// Creates a superellipse alpha mask with inversion support.
    ///
    /// Combines the aesthetic appeal of superellipse shapes with inversion capability.
    /// Provides the most natural-looking masks that match iOS design language while
    /// supporting both normal and inverted blur effects.
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
    /// - inverted: 0 for normal, 1 for inverted mask
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
}
