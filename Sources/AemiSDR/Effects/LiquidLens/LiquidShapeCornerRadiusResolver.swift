//
//  LiquidShapeCornerRadiusResolver.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI

    @available(iOS 16.0, *)
    enum LiquidShapeCornerRadiusResolver {
        static func inferCornerRadius<S: Shape>(from shape: S) -> LiquidLensCornerRadius? {
            if shape is Circle || shape is Capsule {
                return .proportional(1.0)
            }

            guard let inferred = extractCornerRadius(from: Mirror(reflecting: shape), depth: 0) else {
                return nil
            }

            return .points(Float(inferred))
        }

        private static func extractCornerRadius(from mirror: Mirror, depth: Int) -> CGFloat? {
            guard depth <= 5 else {
                return nil
            }

            var candidates: [CGFloat] = []

            for child in mirror.children {
                let label = (child.label ?? "").lowercased()

                if label == "cornersize", let size = child.value as? CGSize {
                    candidates.append(min(size.width, size.height))
                } else if label == "cornerradii" {
                    let radii = Mirror(reflecting: child.value).children.compactMap { $0.value as? CGFloat }
                    if let radius = preferredRadius(from: radii) {
                        candidates.append(radius)
                    }
                } else if label.contains("cornerradius"), let radius = asCGFloat(child.value) {
                    candidates.append(radius)
                } else if label.hasPrefix("corner"), let radius = asCGFloat(child.value) {
                    candidates.append(radius)
                }

                let nestedMirror = Mirror(reflecting: child.value)
                if !nestedMirror.children.isEmpty,
                   let nested = extractCornerRadius(from: nestedMirror, depth: depth + 1)
                {
                    candidates.append(nested)
                }
            }

            return preferredRadius(from: candidates)
        }

        private static func preferredRadius(from values: [CGFloat]) -> CGFloat? {
            let normalized = values.filter { $0 >= 0 }
            guard !normalized.isEmpty else {
                return nil
            }

            if let positiveMinimum = normalized.filter({ $0 > 0 }).min() {
                return positiveMinimum
            }
            return normalized.min()
        }

        private static func asCGFloat(_ value: Any) -> CGFloat? {
            switch value {
            case let value as CGFloat:
                return value
            case let value as Double:
                return CGFloat(value)
            case let value as Float:
                return CGFloat(value)
            case let value as Int:
                return CGFloat(value)
            default:
                return nil
            }
        }
    }
#endif
