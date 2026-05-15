//
//  View+VariableBlur.swift
//  AemiSDR
//

import SwiftUI

// MARK: - Variable Blur View Modifiers

#if os(iOS)
    extension View {
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
        @ViewBuilder public func roundedRectBlur(
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

        /// Applies a uniform blur across the entire view surface.
        ///
        /// Unlike gradient-based variable blur, this applies the same blur intensity
        /// everywhere. The effect uses the same CAFilter variable blur infrastructure
        /// with a constant alpha mask.
        ///
        /// - Parameters:
        ///   - maxBlurRadius: Maximum blur radius in points (default: 20)
        ///   - ignoreSafeArea: Whether to ignore safe area for the blur effect (default: true)
        /// - Returns: A view with uniform blur applied
        @available(iOS 15.0, *)
        @ViewBuilder public func uniformBlur(
            maxBlurRadius: CGFloat = 20,
            ignoreSafeArea: Bool = true
        ) -> some View {
            overlay {
                VariableBlurView(
                    maxBlurRadius: maxBlurRadius,
                    type: .uniform
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
        @ViewBuilder public func verticalEdgeBlur(
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
        /// Applies a variable blur effect strongest at the vertical center, fading to clear at edges.
        ///
        /// This is the inverse of `verticalEdgeBlur`: the center of the view receives
        /// maximum blur while both top and bottom edges remain sharp.
        ///
        /// - Parameters:
        ///   - height: Height of the blurred center region in points (.infinity for full height, default: .infinity)
        ///   - maxBlurRadius: Maximum blur radius in points (default: 3)
        ///   - ignoreSafeArea: Whether to ignore safe area for the blur effect (default: true)
        /// - Returns: A view with center blur applied
        @available(iOS 15.0, *)
        @ViewBuilder public func verticalCenterBlur(
            height: CGFloat = .infinity,
            maxBlurRadius: CGFloat = 3,
            ignoreSafeArea: Bool = true
        ) -> some View {
            overlay {
                VStack(spacing: 0) {
                    if height != .infinity { Spacer() }

                    VariableBlurView(
                        maxBlurRadius: maxBlurRadius,
                        type: .easeInCenterVertical
                    )
                    .frame(height: height == .infinity ? nil : height)
                    .frame(maxHeight: height == .infinity ? .infinity : nil)

                    if height != .infinity { Spacer() }
                }
                .conditionalIgnoreSafeArea(ignoreSafeArea)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
#endif
