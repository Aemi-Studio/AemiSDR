//
//  View+AlphaMask.swift
//  AemiSDR
//

import SwiftUI

// MARK: - Alpha Mask View Modifiers

#if os(iOS)
    extension View {
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
        @ViewBuilder public func roundedRectMask(
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

        /// Fades the top and/or bottom edges of a view to transparent.
        ///
        /// SwiftUI's `.mask` reads the mask's alpha as a visibility map —
        /// alpha = 1 reveals the underlying content, alpha = 0 hides it.
        /// The mask kernels we ship pair naturally with that convention:
        /// the top band uses a top-to-bottom ease (alpha = 0 at the top
        /// edge, alpha = 1 toward the centre) so the content fades out at
        /// the edge and stays solid inward; the bottom band mirrors it.
        /// The interior `Color.black` spacer is fully opaque (alpha = 1)
        /// so the centre region is left untouched.
        ///
        /// - Parameters:
        ///   - height: Height of each edge band in points (`.infinity`
        ///     for full height, default: `.infinity`)
        ///   - edges: Which vertical edges to feather — combinable `.top`
        ///     and `.bottom` (default: `.all`)
        ///   - transition: Linear or eased falloff (default: `.eased`)
        ///   - ignoreSafeArea: Whether the mask ignores safe area
        ///     (default: `true`)
        ///   - inverted: Flips the alpha so the edges become opaque and
        ///     the inner side fades — useful for a "reveal the edges, hide
        ///     the centre" cut-out effect (default: `false`)
        /// - Returns: A view with vertical edge alpha-feathering applied
        @available(iOS 15.0, *)
        @ViewBuilder public func verticalEdgeMask(
            height: CGFloat = .infinity,
            edges: VerticalEdge.Set = .all,
            transition: TransitionAlgorithm = .eased,
            ignoreSafeArea: Bool = true,
            inverted: Bool = false
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

                    if needsSpacer {
                        Color.black
                    }

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

        /// Fades the leading and/or trailing edges of a view to transparent.
        /// X-axis mirror of `verticalEdgeMask` — same convention notes.
        ///
        /// - Parameters:
        ///   - width: Width of each edge band in points (`.infinity` for
        ///     full width, default: `.infinity`)
        ///   - edges: Which horizontal edges to feather — combinable
        ///     `.leading` and `.trailing` (default: `.all`)
        ///   - transition: Linear or eased falloff (default: `.eased`)
        ///   - ignoreSafeArea: Whether the mask ignores safe area
        ///     (default: `true`)
        ///   - inverted: Flips alpha so the edges stay opaque and the
        ///     inner side fades (default: `false`)
        /// - Returns: A view with horizontal edge alpha-feathering applied
        @available(iOS 15.0, *)
        @ViewBuilder public func horizontalEdgeMask(
            width: CGFloat = .infinity,
            edges: HorizontalEdge.Set = .all,
            transition: TransitionAlgorithm = .eased,
            ignoreSafeArea: Bool = true,
            inverted: Bool = false
        ) -> some View {
            let hasLeading = edges.contains(.leading)
            let hasTrailing = edges.contains(.trailing)
            let needsSpacer = (hasLeading && hasTrailing) || width != .infinity

            mask {
                HStack(spacing: 0) {
                    if hasLeading {
                        let leadingType: MaskType =
                            transition == .linear ? .linearLeftToRight : .easeInLeftToRight
                        AlphaMaskView(
                            type: leadingType,
                            inverted: inverted
                        )
                        .frame(width: width == .infinity ? nil : width)
                        .frame(maxWidth: width == .infinity ? .infinity : nil)
                    }

                    if needsSpacer {
                        Color.black
                    }

                    if hasTrailing {
                        let trailingType: MaskType =
                            transition == .linear ? .linearRightToLeft : .easeInRightToLeft
                        AlphaMaskView(
                            type: trailingType,
                            inverted: inverted
                        )
                        .frame(width: width == .infinity ? nil : width)
                        .frame(maxWidth: width == .infinity ? .infinity : nil)
                    }
                }
                .conditionalIgnoreSafeArea(ignoreSafeArea)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        /// Spotlight alpha mask along the Y-axis: the centre row stays
        /// opaque (content visible) and both top and bottom edges fade to
        /// transparent. Uses the `easeInCenterVertical` mask with its
        /// natural (non-inverted) orientation — the centre-proximity
        /// field already peaks at the vertical centre and falls to zero
        /// at the edges, which is exactly what SwiftUI's `.mask` wants
        /// for a centre-reveal.
        ///
        /// - Parameters:
        ///   - height: Height of the spotlight band in points
        ///     (`.infinity` for full height, default: `.infinity`)
        ///   - ignoreSafeArea: Whether the mask ignores safe area
        ///     (default: `true`)
        ///   - inverted: Flips the spotlight so the edges stay opaque and
        ///     the centre fades — useful for a "hide centre, keep edges"
        ///     effect (default: `false`)
        /// - Returns: A view masked with the vertical spotlight
        @available(iOS 15.0, *)
        @ViewBuilder public func verticalCenterMask(
            height: CGFloat = .infinity,
            ignoreSafeArea: Bool = true,
            inverted: Bool = false
        ) -> some View {
            mask {
                VStack(spacing: 0) {
                    if height != .infinity { Color.black }

                    AlphaMaskView(
                        type: .easeInCenterVertical,
                        inverted: inverted
                    )
                    .frame(height: height == .infinity ? nil : height)
                    .frame(maxHeight: height == .infinity ? .infinity : nil)

                    if height != .infinity { Color.black }
                }
                .conditionalIgnoreSafeArea(ignoreSafeArea)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        /// Spotlight alpha mask along the X-axis: the centre column stays
        /// opaque and both leading and trailing edges fade to transparent.
        /// Mirror of `verticalCenterMask` for the X-axis — same
        /// convention notes.
        ///
        /// - Parameters:
        ///   - width: Width of the spotlight band in points (`.infinity`
        ///     for full width, default: `.infinity`)
        ///   - ignoreSafeArea: Whether the mask ignores safe area
        ///     (default: `true`)
        ///   - inverted: Flips the spotlight so the edges stay opaque and
        ///     the centre fades (default: `false`)
        /// - Returns: A view masked with the horizontal spotlight
        @available(iOS 15.0, *)
        @ViewBuilder public func horizontalCenterMask(
            width: CGFloat = .infinity,
            ignoreSafeArea: Bool = true,
            inverted: Bool = false
        ) -> some View {
            mask {
                HStack(spacing: 0) {
                    if width != .infinity { Color.black }

                    AlphaMaskView(
                        type: .easeInCenterHorizontal,
                        inverted: inverted
                    )
                    .frame(width: width == .infinity ? nil : width)
                    .frame(maxWidth: width == .infinity ? .infinity : nil)

                    if width != .infinity { Color.black }
                }
                .conditionalIgnoreSafeArea(ignoreSafeArea)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
#endif
