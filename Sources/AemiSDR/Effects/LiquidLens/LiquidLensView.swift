//
//  LiquidLensView.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI
    import UIKit

    /// A SwiftUI view that renders the physics-based liquid lens distortion effect.
    ///
    /// Wraps ``LiquidLensUIView`` via `UIViewRepresentable` to provide a declarative
    /// API for applying Sellmeier-dispersion-based refraction with chromatic aberration.
    ///
    /// ```swift
    /// LiquidLensView(image: myUIImage, configuration: .init(
    ///     center: SIMD2(200, 300),
    ///     halfSize: SIMD2(150, 150),
    ///     material: .flintGlass
    /// ))
    /// ```
    public struct LiquidLensView: UIViewRepresentable {
        public var image: UIImage?
        public var configuration: LiquidLensConfiguration
        public var clipShapePath: ShapePathProvider?

        public init(
            image: UIImage? = nil,
            configuration: LiquidLensConfiguration = .init(),
            clipShapePath: ShapePathProvider? = nil
        ) {
            self.image = image
            self.configuration = configuration
            self.clipShapePath = clipShapePath
        }

        public func makeUIView(context _: Context) -> LiquidLensUIView {
            let view = LiquidLensUIView(configuration: configuration)
            view.clipShapePath = clipShapePath
            if let image {
                view.setSourceImage(image)
            }
            return view
        }

        public func updateUIView(_ uiView: LiquidLensUIView, context _: Context) {
            uiView.updateConfiguration(configuration)
            uiView.clipShapePath = clipShapePath
            if let image {
                uiView.setSourceImage(image)
            }
        }
    }
#endif
