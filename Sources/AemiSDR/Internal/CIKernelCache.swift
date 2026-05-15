//
//  CIKernelCache.swift
//  AemiSDR
//

import CoreImage
import OSLog

/// CIKernelCache serves as the base class for managing and caching Core Image Metal kernels.
///
/// This class provides the foundational infrastructure for loading Metal-based Core Image kernels
/// from compiled Metal libraries (.metallib files). It handles kernel caching, provides a shared
/// CIContext for image processing operations, and offers utility methods for generating CGImages
/// from kernel operations.
///
/// Key Features:
/// - Lazy loading of Metal library data from bundle resources
/// - Pre-configured CIContext optimized for DisplayP3 color space
/// - Centralized logging for debugging kernel operations
/// - Static methods for common kernel-to-image conversion tasks
///
/// Subclasses should extend this class to provide specific kernel implementations
/// (e.g., VariableBlurCache, AlphaMaskCache).
class CIKernelCache {
    // MARK: - Logging

    /// Shared logger instance for kernel-related operations.
    ///
    /// Uses OSLog with a subsystem identifier for the AemiShader framework
    /// and dynamically sets the category based on the actual class name.
    /// This provides clear, filterable logging for debugging kernel issues.
    static var logger: Logger {
        Logger(subsystem: "studio.aemi.AemiSDR", category: "\(Self.self)")
    }

    // MARK: - Core Image Contexts

    /// Shared CIContext for wide-gamut color-bearing outputs.
    ///
    /// Configured with DisplayP3 working and output color spaces. Use for kernels
    /// whose output carries color information.
    ///
    /// - Note: Intermediate caching disabled to reduce memory pressure;
    ///   `.priorityRequestLow` keeps the main thread responsive under load.
    static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3) as Any,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.displayP3) as Any,
        .cacheIntermediates: false,
        .priorityRequestLow: true,
    ])

    /// Shared CIContext for grayscale alpha-mask outputs.
    ///
    /// All mask kernels in this package emit single-channel alpha. Routing them
    /// through a linear-sRGB working space avoids the wider-gamut P3 conversion
    /// pass without violating CI's requirement that `kCIContextWorkingColorSpace`
    /// be `kCGColorSpaceModelRGB` (CI rejects monochrome working spaces with a
    /// hard error).
    static let maskContext: CIContext = {
        let linearSRGB = CGColorSpace(name: CGColorSpace.linearSRGB)
        return CIContext(options: [
            .workingColorSpace: linearSRGB as Any,
            .outputColorSpace: linearSRGB as Any,
            .cacheIntermediates: false,
            .priorityRequestLow: true,
        ])
    }()

    // MARK: - Metal Library Loading

    /// Platform-specific Metal library resource name.
    ///
    /// Returns the appropriate Metal library filename based on the current platform.
    /// - iOS/tvOS/watchOS/visionOS: Uses the iOS-compiled library
    /// - macOS: Uses the macOS-compiled library
    private static var platformLibraryName: String {
        #if os(macOS)
        return "AemiSDR.macOS"
        #else
        return "AemiSDR.iOS"
        #endif
    }

    /// Lazily loaded Metal library data containing compiled shader functions.
    ///
    /// Attempts to load the platform-specific Metal library from the module bundle.
    /// The library is loaded once and cached for subsequent kernel creation operations.
    ///
    /// **Platform Support**:
    /// - iOS, tvOS, watchOS, visionOS: Loads `AemiSDR.iOS.metallib` (compiled with iOS 14.0+ target)
    /// - macOS: Loads `AemiSDR.macOS.metallib` (compiled with macOS 11.0+ target)
    ///
    /// This platform-specific loading ensures Metal library compatibility across all
    /// supported deployment targets.
    ///
    /// - Returns: Data containing the Metal library, or `nil` if loading fails
    static let libraryData: Data? = {
        guard let url = Bundle.module.url(forResource: platformLibraryName, withExtension: "metallib") else {
            logger.error("Failed to locate \(platformLibraryName).metallib in bundle.")
            return nil
        }

        do {
            // Map the metallib instead of copying it into RAM — the file is
            // read-only and SPM resources sit on the filesystem.
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            logger.error("Failed to load metallib data: \(error.localizedDescription)")
            return nil
        }
    }()

    // MARK: - Kernel Loading

    /// Loads a CIColorKernel from the compiled Metal library by function name.
    ///
    /// Centralizes the boilerplate of checking library data, creating the kernel,
    /// and logging errors. Each kernel property can be defined as a simple one-liner.
    ///
    /// - Parameter name: The Metal function name to load
    /// - Returns: The loaded kernel, or nil if loading fails
    static func loadKernel(_ name: String) -> CIColorKernel? {
        guard let libraryData else {
            logger.error("Library data is nil.")
            return nil
        }
        do {
            return try CIColorKernel(functionName: name, fromMetalLibraryData: libraryData)
        } catch {
            logger.error("Failed to load CIColorKernel '\(name)': \(error)")
            return nil
        }
    }

    // MARK: - Utility Methods

    /// Generates a CGImage from a CIColorKernel using specified parameters.
    ///
    /// This is a convenience method that handles the complete pipeline from kernel
    /// application to final CGImage generation. It provides comprehensive error
    /// handling and logging for each step of the process.
    ///
    /// **Process Flow**:
    /// 1. Validates the kernel is not nil
    /// 2. Applies the kernel with the provided extent and arguments
    /// 3. Renders the resulting CIImage to a CGImage using the shared context
    /// 4. Returns the final CGImage or nil if any step fails
    ///
    /// - Parameters:
    ///   - kernel: The CIColorKernel to apply (must not be nil)
    ///   - extent: The rectangular region to process in pixels
    ///   - arguments: Array of arguments to pass to the kernel function
    /// - Returns: Generated CGImage, or nil if the operation fails
    ///
    /// **Usage Example**:
    /// ```swift
    /// let cgImage = CIKernelCache.generateCGImage(
    ///     kernel: someKernel,
    ///     extent: CGRect(x: 0, y: 0, width: 100, height: 100),
    ///     arguments: [width, height, cornerRadius]
    /// )
    /// ```
    static func generateCGImage(kernel: CIColorKernel?, extent: CGRect, arguments: [Any]) -> CGImage? {
        generateCGImage(kernel: kernel, extent: extent, arguments: arguments, context: context)
    }

    /// Generates a CGImage from a CIColorKernel using a caller-specified context.
    ///
    /// Pass `maskContext` for single-channel alpha masks to skip the P3 → sRGB
    /// conversion pass that the default color context applies on every render.
    static func generateCGImage(
        kernel: CIColorKernel?,
        extent: CGRect,
        arguments: [Any],
        context: CIContext
    ) -> CGImage? {
        guard let kernel else {
            logger.error("Kernel is nil.")
            return nil
        }

        guard let image = kernel.apply(extent: extent, arguments: arguments) else {
            logger.error("Kernel application failed.")
            return nil
        }

        guard let cgImage = context.createCGImage(image, from: extent) else {
            logger.error("CGImage creation failed.")
            return nil
        }

        return cgImage
    }
}

// MARK: - Shared Kernels

extension CIKernelCache {
    // Gradient kernels
    static let linearMask = loadKernel("linearMask")
    static let easeInAlphaMask = loadKernel("easeInAlphaMask")

    // Rounded rectangle kernels (with inversion support)
    static let roundedRectAlphaMask = loadKernel("roundedRectAlphaMask")
    static let roundedRectEaseAlphaMask = loadKernel("roundedRectEaseAlphaMask")

    // Superellipse kernels (with inversion support)
    static let superellipseAlphaMask = loadKernel("superellipseAlphaMask")
    static let superellipseEaseAlphaMask = loadKernel("superellipseEaseAlphaMask")

    // Uniform and center kernels
    static let uniformMask = loadKernel("uniformMask")
    static let easeInCenterMask = loadKernel("easeInCenterMask")
}
