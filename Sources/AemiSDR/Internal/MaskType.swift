//
//  MaskType.swift
//  AemiSDR
//

import CoreImage

/// Mask shapes and gradients used for variable blur and alpha masking.
/// Each case maps to a dedicated, optimized shader.
public enum MaskType: Sendable, Equatable, Hashable, CaseIterable {
    /// Linear gradient: top is masked/blurred; bottom is clear.
    case linearTopToBottom

    /// Linear gradient: bottom is masked/blurred; top is clear.
    case linearBottomToTop

    /// Standard rounded rectangle (SDF) with crisp edges.
    case roundedRectangle

    /// Rounded rectangle with eased corner transitions.
    case easedRoundedRectangle

    /// Mathematical superellipse (squircle).
    case superellipseSquircle

    /// Superellipse with eased edge transitions.
    case easedSuperellipseSquircle

    /// Quadratic ease-in gradient: top is masked/blurred; bottom is clear.
    case easeInTopToBottom

    /// Quadratic ease-in gradient: bottom is masked/blurred; top is clear.
    case easeInBottomToTop

    // MARK: - Convenience Initializer

    /// Creates a MaskType from a corner style and transition algorithm.
    ///
    /// - Parameters:
    ///   - cornerStyle: The corner style to use (.circular or .continuous)
    ///   - transition: The transition algorithm (.linear or .eased)
    public init(cornerStyle: RoundedCornerStyle, transition: TransitionAlgorithm) {
        self = switch (cornerStyle, transition) {
        case (.circular, .linear): .roundedRectangle
        case (.circular, .eased): .easedRoundedRectangle
        case (.continuous, .linear): .superellipseSquircle
        case (.continuous, .eased): .easedSuperellipseSquircle
        case (_, _): .easedSuperellipseSquircle
        }
    }
}

// MARK: - Kernel Descriptor

extension MaskType {
    /// Returns the kernel and arguments needed to generate a mask of this type.
    ///
    /// Centralizes the switch logic previously duplicated in AlphaMaskUIView and VariableBlurUIView.
    ///
    /// - Parameters:
    ///   - size: The view size in points
    ///   - scale: The display scale factor
    ///   - startOffset: Start offset for gradient masks
    ///   - cornerRadius: Corner radius for shape masks
    ///   - fadeWidth: Fade width for shape masks
    ///   - inverted: Whether to invert the mask
    /// - Returns: A tuple of (kernel, arguments) ready for `CIKernelCache.generateCGImage`
    func kernelDescriptor(
        size: CGSize,
        scale: CGFloat,
        startOffset: CGFloat = 0,
        cornerRadius: CGFloat = 0,
        fadeWidth: CGFloat = 16,
        inverted: Bool
    ) -> (kernel: CIColorKernel?, arguments: [Any]) {
        let scaledWidth = max(1, ceil(size.width * scale))
        let scaledHeight = max(1, ceil(size.height * scale))
        let inv: Double = inverted ? 1.0 : 0.0

        switch self {
        case .linearTopToBottom:
            return (CIKernelCache.linearMask,
                    [scaledWidth, scaledHeight, startOffset, inverted ? 1.0 : 0.0])

        case .linearBottomToTop:
            return (CIKernelCache.linearMask,
                    [scaledWidth, scaledHeight, startOffset, inverted ? 0.0 : 1.0])

        case .easeInTopToBottom:
            return (CIKernelCache.easeInAlphaMask,
                    [scaledWidth, scaledHeight, startOffset, 0.0, inv])

        case .easeInBottomToTop:
            return (CIKernelCache.easeInAlphaMask,
                    [scaledWidth, scaledHeight, startOffset, 1.0, inv])

        case .roundedRectangle:
            let cr = cornerRadius * scale
            let fw = fadeWidth * scale
            return (CIKernelCache.roundedRectAlphaMask,
                    [scaledWidth, scaledHeight, cr, fw, inv])

        case .easedRoundedRectangle:
            let cr = cornerRadius * scale
            let fw = fadeWidth * scale
            return (CIKernelCache.roundedRectEaseAlphaMask,
                    [scaledWidth, scaledHeight, cr, fw, inv])

        case .superellipseSquircle:
            let cr = cornerRadius * scale
            let fw = fadeWidth * scale
            return (CIKernelCache.superellipseAlphaMask,
                    [scaledWidth, scaledHeight, cr, fw, 2, inv])

        case .easedSuperellipseSquircle:
            let cr = cornerRadius * scale
            let fw = fadeWidth * scale
            return (CIKernelCache.superellipseEaseAlphaMask,
                    [scaledWidth, scaledHeight, cr, fw, 2, inv])
        }
    }
}
