//
//  AlphaMaskUIView.swift
//  AemiSDR
//

#if os(iOS)
import OSLog
import UIKit

/// A UIView that renders alpha masks using Metal shaders for destination-out compositing effects.
///
/// AlphaMaskUIView creates sophisticated alpha masks that can be used to selectively hide or reveal
/// portions of content placed behind it. The view itself becomes the mask, where:
/// - Transparent areas allow content to show through
/// - White areas hide the content behind (destination-out effect)
/// - The alpha channel from the Metal shaders determines the final transparency
///
/// Key Features:
/// - Multiple mask types: linear gradients, rounded rectangles, and superellipse squircles
/// - Hardware-accelerated Metal shader rendering for optimal performance
/// - Automatic caching and regeneration based on view size and configuration changes
/// - Support for both linear and eased (smooth) transition functions
/// - Configurable inversion for different masking effects
///
/// The view automatically updates its mask when layout changes occur and caches the generated
/// mask images to avoid unnecessary recomputation.
open class AlphaMaskUIView: UIView {
  // MARK: - Configuration Properties

  /// The type of mask shape to generate (linear, rounded rectangle, superellipse, etc.)
  private var configuredMaskType: MaskType

  /// Start offset for linear gradients (as fraction) or transition smoothness for shaped masks
  private var configuredStartOffset: CGFloat

  /// Corner radius in points for rounded rectangle and superellipse masks
  private var configuredCornerRadius: CGFloat

  /// Width of the fade transition zone in points
  private var configuredFadeWidth: CGFloat

  /// Whether to invert the mask (true = destination-out effect, false = normal mask)
  private var configuredInverted: Bool

  /// Current display scale, used for pixel-accurate mask generation
  private var currentScale: CGFloat {
    window?.screen.scale ?? UIScreen.main.scale
  }

  // MARK: - Initialization

  /// Creates a new alpha mask view with the specified configuration.
  ///
  /// - Parameters:
  ///   - maskType: The type of mask to generate (default: linear top-to-bottom)
  ///   - startOffset: Start position for linear gradients or transition control for shapes (default: 0)
  ///   - cornerRadius: Corner radius in points for rounded shapes (default: UIScreen.displayCornerRadius)
  ///   - fadeWidth: Width of fade transition in points (default: 16)
  ///   - inverted: Whether to invert the mask effect (default: true for destination-out)
  public init(
    maskType: MaskType = .linearTopToBottom,
    startOffset: CGFloat = 0,
    cornerRadius: CGFloat = UIScreen.displayCornerRadius,
    fadeWidth: CGFloat = 16,
    inverted: Bool = true
  ) {
    configuredMaskType = maskType
    configuredStartOffset = startOffset
    configuredCornerRadius = cornerRadius
    configuredFadeWidth = fadeWidth
    configuredInverted = inverted

    super.init(frame: .zero)

    // Configure view for optimal masking performance
    isUserInteractionEnabled = false // No touch handling needed for mask views
    backgroundColor = .clear // Start with clear background
    isOpaque = false // Ensure proper alpha blending

    // Generate initial mask
    updateMask(for: bounds.size)
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Configuration Updates

  /// Updates the mask configuration and regenerates if necessary.
  ///
  /// This method compares the new configuration against the current one and only
  /// triggers a mask regeneration if actual changes are detected. This optimization
  /// prevents unnecessary GPU work during animations or frequent updates.
  ///
  /// - Parameters:
  ///   - maskType: The type of mask to generate
  ///   - startOffset: Start position for gradients or transition control
  ///   - cornerRadius: Corner radius for rounded shapes
  ///   - fadeWidth: Fade transition width
  ///   - inverted: Whether to invert the mask
  public func updateConfiguration(
    maskType: MaskType,
    startOffset: CGFloat,
    cornerRadius: CGFloat,
    fadeWidth: CGFloat,
    inverted: Bool
  ) {
    // Check if any configuration has actually changed
    let needsUpdate = configuredMaskType != maskType ||
      configuredStartOffset != startOffset ||
      configuredCornerRadius != cornerRadius ||
      configuredFadeWidth != fadeWidth ||
      configuredInverted != inverted

    if needsUpdate {
      configuredMaskType = maskType
      configuredStartOffset = startOffset
      configuredCornerRadius = cornerRadius
      configuredFadeWidth = fadeWidth
      configuredInverted = inverted

      // Force mask regeneration with new parameters
      updateMask(for: bounds.size)
    }
  }

  // MARK: - Mask Generation

  /// Updates the mask for the specified size, with optional forced regeneration.
  ///
  /// This is the core method that manages mask generation and caching. It compares
  /// the current parameters against the last generation to avoid unnecessary work.
  ///
  /// - Parameters:
  ///   - size: The target size for the mask
  private func updateMask(for size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }

    let maskImage = generateAlphaMask(size: size, scale: currentScale)

    // Apply the generated mask to the layer
    if let maskImage {
      let maskLayer = CALayer()
      maskLayer.frame = bounds
      maskLayer.contents = maskImage
      layer.mask = maskLayer
    }

    // Set white background so the mask effect is visible
    // The alpha channel from the shader determines final transparency
    backgroundColor = .white
  }

  /// Generates the actual alpha mask image using Metal shaders.
  ///
  /// This method calls the appropriate shader kernel based on the configured mask type
  /// and returns a CGImage that can be used as a layer mask. All generation happens
  /// on the GPU for optimal performance.
  ///
  /// - Parameters:
  ///   - size: The size in points for the mask
  ///   - scale: The display scale for pixel-accurate rendering
  /// - Returns: A CGImage containing the alpha mask, or nil if generation fails
  private func generateAlphaMask(size: CGSize, scale: CGFloat) -> CGImage? {
    // Calculate pixel dimensions
    let scaledWidth = max(1, ceil(size.width * scale))
    let scaledHeight = max(1, ceil(size.height * scale))
    let extent = CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)

    // Generate appropriate mask based on type
    switch configuredMaskType {
    case .linearTopToBottom:
      let inverted = configuredInverted ? 1.0 : 0.0
      let args: [Any] = [scaledWidth, scaledHeight, configuredStartOffset, inverted]
      return AlphaMaskCache.generateCGImage(
        kernel: AlphaMaskCache.linearMask,
        extent: extent,
        arguments: args
      )

    case .linearBottomToTop:
      // Flip logic for bottom-to-top direction
      let inverted = configuredInverted ? 0.0 : 1.0
      let args: [Any] = [scaledWidth, scaledHeight, configuredStartOffset, inverted]
      return AlphaMaskCache.generateCGImage(
        kernel: AlphaMaskCache.linearMask,
        extent: extent,
        arguments: args
      )

    case .easeInTopToBottom:
      // Ease-in gradient from top, startOffset defines easing start point
      let inverted = configuredInverted ? 1.0 : 0.0
      let args: [Any] = [scaledWidth, scaledHeight, configuredStartOffset, 0.0, inverted]
      return AlphaMaskCache.generateCGImage(
        kernel: AlphaMaskCache.easeInAlphaMask,
        extent: extent,
        arguments: args
      )

    case .easeInBottomToTop:
      let inverted = configuredInverted ? 1.0 : 0.0
      let args: [Any] = [scaledWidth, scaledHeight, configuredStartOffset, 1.0, inverted]
      return AlphaMaskCache.generateCGImage(
        kernel: AlphaMaskCache.easeInAlphaMask,
        extent: extent,
        arguments: args
      )

    case .roundedRectangle:
      // Standard rounded rectangle with linear falloff
      let scaledCornerRadius = configuredCornerRadius * scale
      let scaledFadeWidth = configuredFadeWidth * scale
      let inverted = configuredInverted ? 1.0 : 0.0
      let args: [Any] = [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth, inverted]
      return AlphaMaskCache.generateCGImage(
        kernel: AlphaMaskCache.roundedRectAlphaMask,
        extent: extent,
        arguments: args
      )

    case .easedRoundedRectangle:
      let scaledCornerRadius = configuredCornerRadius * scale
      let scaledFadeWidth = configuredFadeWidth * scale
      let inverted = configuredInverted ? 1.0 : 0.0
      let args: [Any] = [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth, inverted]
      return AlphaMaskCache.generateCGImage(
        kernel: AlphaMaskCache.roundedRectEaseAlphaMask,
        extent: extent,
        arguments: args
      )

    case .superellipseSquircle:
      let scaledCornerRadius = configuredCornerRadius * scale
      let scaledFadeWidth = configuredFadeWidth * scale
      let inverted = configuredInverted ? 1.0 : 0.0
      let args: [Any] = [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth, 2, inverted]
      return AlphaMaskCache.generateCGImage(
        kernel: AlphaMaskCache.superellipseAlphaMask,
        extent: extent,
        arguments: args
      )

    case .easedSuperellipseSquircle:
      let scaledCornerRadius = configuredCornerRadius * scale
      let scaledFadeWidth = configuredFadeWidth * scale
      let inverted = configuredInverted ? 1.0 : 0.0
      let args: [Any] = [scaledWidth, scaledHeight, scaledCornerRadius, scaledFadeWidth, 2, inverted]
      return AlphaMaskCache.generateCGImage(
        kernel: AlphaMaskCache.superellipseEaseAlphaMask,
        extent: extent,
        arguments: args
      )
    }
  }

  // MARK: - UIView Overrides

  /// Responds to layout changes by updating the mask if necessary.
  ///
  /// This ensures the mask always matches the current view bounds and maintains
  /// pixel-perfect accuracy across different screen sizes and orientations.
  override open func layoutSubviews() {
    super.layoutSubviews()
    updateMask(for: bounds.size)
  }
}
#endif
