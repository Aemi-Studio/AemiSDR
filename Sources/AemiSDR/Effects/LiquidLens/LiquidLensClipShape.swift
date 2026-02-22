//
//  LiquidLensClipShape.swift
//  AemiSDR
//

#if os(iOS)
    import CoreGraphics
    import UIKit

    /// A closure that produces a `CGPath` for a given rect, used to communicate
    /// SwiftUI Shape geometry to the UIKit/Metal layer for masking.
    public typealias ShapePathProvider = @Sendable (CGRect) -> CGPath

    /// Pre-built shape path providers for common clip shapes.
    public enum LiquidLensClipShape {

        /// Rounded rectangle with uniform corner radius and continuous (superellipse) corners.
        public static func roundedRect(cornerRadius: CGFloat) -> ShapePathProvider {
            { rect in
                UIBezierPath(
                    roundedRect: rect,
                    cornerRadius: cornerRadius
                ).cgPath
            }
        }

        /// Circle inscribed in the rect (uses the shorter dimension as diameter).
        public static var circle: ShapePathProvider {
            { rect in
                let d = min(rect.width, rect.height)
                let origin = CGPoint(x: rect.midX - d / 2, y: rect.midY - d / 2)
                return CGPath(
                    ellipseIn: CGRect(origin: origin, size: CGSize(width: d, height: d)),
                    transform: nil
                )
            }
        }

        /// Capsule (fully rounded on the shorter axis).
        public static var capsule: ShapePathProvider {
            { rect in
                let r = min(rect.width, rect.height) / 2
                return UIBezierPath(
                    roundedRect: rect,
                    cornerRadius: r
                ).cgPath
            }
        }

        /// Rounded rectangle with independent corner radii.
        public static func unevenRoundedRect(
            topLeading: CGFloat = 0,
            bottomLeading: CGFloat = 0,
            bottomTrailing: CGFloat = 0,
            topTrailing: CGFloat = 0
        ) -> ShapePathProvider {
            { rect in
                let path = UIBezierPath()

                // Top edge (left to right)
                path.move(to: CGPoint(x: rect.minX + topLeading, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX - topTrailing, y: rect.minY))

                // Top-right corner
                if topTrailing > 0 {
                    path.addArc(
                        withCenter: CGPoint(x: rect.maxX - topTrailing, y: rect.minY + topTrailing),
                        radius: topTrailing, startAngle: -.pi / 2, endAngle: 0, clockwise: true
                    )
                }

                // Right edge (top to bottom)
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailing))

                // Bottom-right corner
                if bottomTrailing > 0 {
                    path.addArc(
                        withCenter: CGPoint(x: rect.maxX - bottomTrailing, y: rect.maxY - bottomTrailing),
                        radius: bottomTrailing, startAngle: 0, endAngle: .pi / 2, clockwise: true
                    )
                }

                // Bottom edge (right to left)
                path.addLine(to: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY))

                // Bottom-left corner
                if bottomLeading > 0 {
                    path.addArc(
                        withCenter: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY - bottomLeading),
                        radius: bottomLeading, startAngle: .pi / 2, endAngle: .pi, clockwise: true
                    )
                }

                // Left edge (bottom to top)
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeading))

                // Top-left corner
                if topLeading > 0 {
                    path.addArc(
                        withCenter: CGPoint(x: rect.minX + topLeading, y: rect.minY + topLeading),
                        radius: topLeading, startAngle: .pi, endAngle: -.pi / 2, clockwise: true
                    )
                }

                path.close()
                return path.cgPath
            }
        }
    }
#endif
