//
//  View+VariableBlur.swift
//  AemiSDR
//

import SwiftUI

// MARK: - Variable Blur View Modifiers

#if os(iOS)
public extension View {
  /// Applies a variable blur effect to the view using rounded rectangle masking.
  ///
  /// This modifier creates a blur effect where the blur intensity varies across
  /// different regions based on a rounded rectangle mask pattern. The blur is
  /// strongest at the edges and gradually decreases toward the center.
  ///
  /// - Parameters:
  ///   - cornerStyle: The corner style to apply - .circular or .continuous (default: .continuous)
  ///   - maxBlurRadius: Maximum blur radius in points (default: 3)
  ///   - cornerRadius: Corner radius in points (default: UIScreen.displayCornerRadius)
  ///   - fadeWidth: Width of the fade transition in points (default: 16)
  ///   - ignoreSafeArea: Whether to ignore safe area for the blur effect (default: true)
  ///   - transition: Transformation function - linear or eased (default: .eased)
  /// - Returns: A view with the variable blur effect applied
  @available(iOS 15.0, *)
  @ViewBuilder func roundedRectBlur(
    _ cornerStyle: RoundedCornerStyle = .continuous,
    maxBlurRadius: CGFloat = 3,
    cornerRadius: CGFloat = UIScreen.displayCornerRadius,
    fadeWidth: CGFloat = 16,
    ignoreSafeArea: Bool = true,
    transition: TransitionAlgorithm = .eased
  ) -> some View {
    overlay {
      VariableBlurView(
        cornerStyle,
        maxBlurRadius: maxBlurRadius,
        cornerRadius: cornerRadius,
        fadeWidth: fadeWidth,
        transition: transition
      )
      .conditionalIgnoreSafeArea(ignoreSafeArea)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  /// Applies variable blur effects to the vertical edges (top and bottom) of a view.
  ///
  /// This modifier creates blur effects on the top and/or bottom of the view, with a
  /// customizable blur area size and separation between the blurred edges and center content.
  ///
  /// - Parameters:
  ///   - height: Height of the blur area in points (.infinity for full height, default: .infinity)
  ///   - maxBlurRadius: Maximum blur radius in points (default: 20)
  ///   - edges: Which vertical edges to blur - can combine .top and .bottom (default: .all)
  ///   - transition: Transformation function - linear or eased (default: .eased)
  ///   - ignoreSafeArea: Whether to ignore safe area for the blur effect (default: true)
  /// - Returns: A view with vertical edge blur effects applied
  @available(iOS 15.0, *)
  @ViewBuilder func verticalEdgeBlur(
    height: CGFloat = .infinity,
    maxBlurRadius: CGFloat = 3,
    edges: VerticalEdge.Set = .all,
    transition: TransitionAlgorithm = .eased,
    ignoreSafeArea: Bool = true
  ) -> some View {
    let hasTop = edges.contains(.top)
    let hasBottom = edges.contains(.bottom)
    let needsSpacer = hasTop && hasBottom || height != .infinity

    overlay {
      VStack(spacing: 0) {
        if hasTop {
          let topType: MaskType =
            transition == .linear ? .linearTopToBottom : .easeInTopToBottom
          VariableBlurView(
            maxBlurRadius: maxBlurRadius,
            type: topType
          )
          .frame(height: height == .infinity ? nil : height)
          .frame(maxHeight: height == .infinity ? .infinity : nil)
        }

        if needsSpacer {
          Spacer()
        }

        // Bottom edge blur
        if hasBottom {
          let bottomType: MaskType =
            transition == .linear ? .linearBottomToTop : .easeInBottomToTop
          VariableBlurView(
            maxBlurRadius: maxBlurRadius,
            type: bottomType
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
