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
            transition: TransitionAlgorithm = .eased,
            scale: CGFloat = 1
        ) -> some View {
            overlay {
                VariableBlurView(
                    cornerStyle,
                    maxBlurRadius: maxBlurRadius,
                    cornerRadius: cornerRadius,
                    fadeWidth: fadeWidth,
                    transition: transition,
                    scale: scale
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
            ignoreSafeArea: Bool = true,
            scale: CGFloat = 1
        ) -> some View {
            overlay {
                VariableBlurView(
                    maxBlurRadius: maxBlurRadius,
                    type: .uniform,
                    scale: scale
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
            ignoreSafeArea: Bool = true,
            scale: CGFloat = 1
        ) -> some View {
            let hasTop = edges.contains(.top)
            let hasBottom = edges.contains(.bottom)
            let needsSpacer = hasTop && hasBottom || height != .infinity

            // Convention: Apple's variableBlur CAFilter reads the mask as
            // luminance-drives-blur — white pixels (alpha=1) receive maximum
            // blur, black pixels (alpha=0) are left crisp.
            //
            // For the TOP band (placed at the top of the view), max blur
            // should land at the band's TOP edge (= the view's outermost
            // edge), fading to 0 as we move down into the content. The
            // mask whose alpha peaks at the top is `.linearTopToBottom` /
            // `.easeInTopToBottom` — the case names match the docstring
            // semantics ("top is masked/blurred" = alpha peaks at top).
            //
            // For the BOTTOM band (placed at the bottom of the view), max
            // blur should land at the band's BOTTOM edge — `.linearBottomToTop`
            // / `.easeInBottomToTop`.
            overlay {
                VStack(spacing: 0) {
                    if hasTop {
                        let topType: MaskType =
                            transition == .linear ? .linearTopToBottom : .easeInTopToBottom
                        VariableBlurView(
                            maxBlurRadius: maxBlurRadius,
                            type: topType,
                            scale: scale
                        )
                        .frame(height: height == .infinity ? nil : height)
                        .frame(maxHeight: height == .infinity ? .infinity : nil)
                    }

                    if needsSpacer {
                        Spacer()
                    }

                    if hasBottom {
                        let bottomType: MaskType =
                            transition == .linear ? .linearBottomToTop : .easeInBottomToTop
                        VariableBlurView(
                            maxBlurRadius: maxBlurRadius,
                            type: bottomType,
                            scale: scale
                        )
                        .frame(height: height == .infinity ? nil : height)
                        .frame(maxHeight: height == .infinity ? .infinity : nil)
                    }
                }
                .conditionalIgnoreSafeArea(ignoreSafeArea)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        /// Spotlight-style variable blur: the vertical centre stays crisp
        /// and both top and bottom edges receive maximum blur, with a
        /// quadratic ease fading the blur inward toward the centre row.
        ///
        /// Visually the inverse of "blur peaked at centre" — the centre
        /// is the focus region and the blur surrounds it. Pair with
        /// `verticalEdgeBlur(edges: .all)` if you want sharper, more
        /// linear edge falloff instead of a smooth inward fade.
        ///
        /// - Parameters:
        ///   - height: Height of the spotlight band in points (.infinity
        ///     for full height, default: .infinity)
        ///   - maxBlurRadius: Maximum blur radius in points (default: 3)
        ///   - ignoreSafeArea: Whether to ignore safe area for the blur
        ///     effect (default: true)
        /// - Returns: A view with the spotlight blur applied
        @available(iOS 15.0, *)
        @ViewBuilder public func verticalCenterBlur(
            height: CGFloat = .infinity,
            maxBlurRadius: CGFloat = 3,
            ignoreSafeArea: Bool = true,
            scale: CGFloat = 1
        ) -> some View {
            overlay {
                VStack(spacing: 0) {
                    if height != .infinity { Spacer() }

                    // `inverted: true` flips the centre-proximity field
                    // so the mask peaks at the top/bottom edges (alpha=1
                    // = max blur) and falls to zero at the centre row
                    // (alpha=0 = crisp). Without the inversion the
                    // pattern would be reversed (blur peaks at centre).
                    VariableBlurView(
                        maxBlurRadius: maxBlurRadius,
                        type: .easeInCenterVertical,
                        inverted: true,
                        scale: scale
                    )
                    .frame(height: height == .infinity ? nil : height)
                    .frame(maxHeight: height == .infinity ? .infinity : nil)

                    if height != .infinity { Spacer() }
                }
                .conditionalIgnoreSafeArea(ignoreSafeArea)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        /// Applies variable blur effects to the horizontal edges (leading
        /// and trailing) of a view. Mirror of `verticalEdgeBlur` for the
        /// X-axis — useful for fading content that scrolls past the edges
        /// of a horizontally-scrolling row or for soft overflow indicators.
        ///
        /// - Parameters:
        ///   - width: Width of each blur band in points (.infinity for full
        ///     width, default: .infinity)
        ///   - maxBlurRadius: Maximum blur radius in points (default: 3)
        ///   - edges: Which horizontal edges to blur — combinable .leading
        ///     and .trailing (default: .all)
        ///   - transition: Transformation function — linear or eased
        ///     (default: .eased)
        ///   - ignoreSafeArea: Whether to ignore safe area for the blur
        ///     effect (default: true)
        @available(iOS 15.0, *)
        @ViewBuilder public func horizontalEdgeBlur(
            width: CGFloat = .infinity,
            maxBlurRadius: CGFloat = 3,
            edges: HorizontalEdge.Set = .all,
            transition: TransitionAlgorithm = .eased,
            ignoreSafeArea: Bool = true,
            scale: CGFloat = 1
        ) -> some View {
            let hasLeading = edges.contains(.leading)
            let hasTrailing = edges.contains(.trailing)
            let needsSpacer = hasLeading && hasTrailing || width != .infinity

            // Same mask-direction inversion as `verticalEdgeBlur`: white
            // mask drives max blur, so the leading band's mask must peak
            // at the leading edge and decay toward the inner side — that
            // profile comes from the "Right-to-Left" gradient case
            // (xNorm flipped so alpha=1 at the leading edge). The
            // trailing band mirrors it. See the comment block in
            // `verticalEdgeBlur` for the underlying CAFilter convention.
            overlay {
                HStack(spacing: 0) {
                    if hasLeading {
                        let leadingType: MaskType =
                            transition == .linear ? .linearRightToLeft : .easeInRightToLeft
                        VariableBlurView(
                            maxBlurRadius: maxBlurRadius,
                            type: leadingType,
                            scale: scale
                        )
                        .frame(width: width == .infinity ? nil : width)
                        .frame(maxWidth: width == .infinity ? .infinity : nil)
                    }

                    if needsSpacer {
                        Spacer()
                    }

                    if hasTrailing {
                        let trailingType: MaskType =
                            transition == .linear ? .linearLeftToRight : .easeInLeftToRight
                        VariableBlurView(
                            maxBlurRadius: maxBlurRadius,
                            type: trailingType,
                            scale: scale
                        )
                        .frame(width: width == .infinity ? nil : width)
                        .frame(maxWidth: width == .infinity ? .infinity : nil)
                    }
                }
                .conditionalIgnoreSafeArea(ignoreSafeArea)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        /// Spotlight-style variable blur: the horizontal centre stays
        /// crisp and both leading and trailing edges receive maximum
        /// blur, with a quadratic ease fading the blur inward toward
        /// the centre column. Mirror of `verticalCenterBlur` for the
        /// X-axis.
        ///
        /// Visually the inverse of "blur peaked at centre" — the centre
        /// is the focus region and the blur surrounds it. Useful for
        /// fading overflow on a horizontally-scrolling row while keeping
        /// the on-screen item in focus.
        ///
        /// - Parameters:
        ///   - width: Width of the spotlight band in points (.infinity
        ///     for full width, default: .infinity)
        ///   - maxBlurRadius: Maximum blur radius in points (default: 3)
        ///   - ignoreSafeArea: Whether to ignore safe area for the blur
        ///     effect (default: true)
        @available(iOS 15.0, *)
        @ViewBuilder public func horizontalCenterBlur(
            width: CGFloat = .infinity,
            maxBlurRadius: CGFloat = 3,
            ignoreSafeArea: Bool = true,
            scale: CGFloat = 1
        ) -> some View {
            overlay {
                HStack(spacing: 0) {
                    if width != .infinity { Spacer() }

                    // See `verticalCenterBlur` for the `inverted: true`
                    // rationale — same flip on the X-axis: blur peaks at
                    // the leading and trailing edges, centre column stays
                    // crisp.
                    VariableBlurView(
                        maxBlurRadius: maxBlurRadius,
                        type: .easeInCenterHorizontal,
                        inverted: true,
                        scale: scale
                    )
                    .frame(width: width == .infinity ? nil : width)
                    .frame(maxWidth: width == .infinity ? .infinity : nil)

                    if width != .infinity { Spacer() }
                }
                .conditionalIgnoreSafeArea(ignoreSafeArea)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
#endif
