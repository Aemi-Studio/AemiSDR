//
//  View+AlphaMask.swift
//  AemiSDR
//

import SwiftUI

// MARK: - Alpha Mask View Modifiers

#if os(iOS)
public extension View {
  /// Applies an alpha mask effect to the view using the specified parameters.
  ///
  /// This modifier creates a destination-out compositing effect where the mask
  /// selectively hides or reveals portions of the content. The mask is generated
  /// using Metal shaders for optimal performance.
  ///
  /// - Parameters:
  ///   - cornerStyle: The corner style to apply - .circular or .continuous (default: .continuous)
  ///   - cornerRadius: Corner radius in points (default: UIScreen.displayCornerRadius)
  ///   - fadeWidth: Width of the fade transition in points (default: 16)
  ///   - inverted: Whether to invert the mask effect (default: true)
  ///   - ignoreSafeArea: Whether to ignore safe area for the mask effect (default: true)
  ///   - transition: Transformation function - linear or eased (default: .eased)
  /// - Returns: A view with the alpha mask effect applied
  @available(iOS 15.0, *)
  @ViewBuilder func roundedRectMask(
    _ cornerStyle: RoundedCornerStyle = .continuous,
    cornerRadius: CGFloat = UIScreen.displayCornerRadius,
    fadeWidth: CGFloat = 16,
    inverted: Bool = true,
    ignoreSafeArea: Bool = true,
    transition: TransitionAlgorithm = .eased
  ) -> some View {
    mask {
      AlphaMaskView(
        cornerStyle,
        cornerRadius: cornerRadius,
        fadeWidth: fadeWidth,
        inverted: inverted,
        transition: transition
      )
      .conditionalIgnoreSafeArea(ignoreSafeArea)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  /// Applies alpha mask effects to the vertical edges (top and bottom) of a view.
  ///
  /// This modifier creates mask effects on the top and/or bottom of the view, with a
  /// customizable mask area size and separation between the masked edges and center content.
  /// The center spacer uses Color.black to maintain proper masking.
  ///
  /// - Parameters:
  ///   - height: Height of the mask area in points (.infinity for full height, default: .infinity)
  ///   - edges: Which vertical edges to mask - can combine .top and .bottom (default: .all)
  ///   - transition: Transformation function - linear or eased (default: .eased)
  ///   - ignoreSafeArea: Whether to ignore safe area for the mask effect (default: true)
  ///   - inverted: Whether to invert the mask effect (default: true)
  /// - Returns: A view with vertical edge mask effects applied
  @available(iOS 15.0, *)
  @ViewBuilder func verticalEdgeMask(
    height: CGFloat = .infinity,
    edges: VerticalEdge.Set = .all,
    transition: TransitionAlgorithm = .eased,
    ignoreSafeArea: Bool = true,
    inverted: Bool = true
  ) -> some View {
    let hasTop = edges.contains(.top)
    let hasBottom = edges.contains(.bottom)
    let needsSpacer = (hasTop && hasBottom) || height != .infinity

    mask {
      VStack(spacing: 0) {
        if hasTop {
          let topType: MaskType =
            transition == .linear ? .linearTopToBottom : .easeInTopToBottom
          AlphaMaskView(
            type: topType,
            inverted: inverted
          )
          .frame(height: height == .infinity ? nil : height)
          .frame(maxHeight: height == .infinity ? .infinity : nil)
        }

        // Center spacer (when both edges are present OR when height is constrained)
        if needsSpacer {
          Color.black
        }

        // Bottom edge mask
        if hasBottom {
          let bottomType: MaskType =
            transition == .linear ? .linearBottomToTop : .easeInBottomToTop
          AlphaMaskView(
            type: bottomType,
            inverted: inverted
          )
          .frame(height: height == .infinity ? nil : height)
          .frame(maxHeight: height == .infinity ? .infinity : nil)
        }
      }
      .conditionalIgnoreSafeArea(ignoreSafeArea)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
#endif
