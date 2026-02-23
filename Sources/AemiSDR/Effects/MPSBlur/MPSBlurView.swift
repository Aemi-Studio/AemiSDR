//
//  MPSBlurView.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI

    /// A background-style MPS Gaussian blur surface that auto-sizes to its container.
    ///
    /// This captures the composited backdrop via `CABackdropLayer` and applies a GPU
    /// Gaussian blur using Metal Performance Shaders.
    @available(iOS 15.0, *)
    public struct MPSBlurView: View {
        public var configuration: MPSBlurConfiguration

        public init(configuration: MPSBlurConfiguration = .standard) {
            self.configuration = configuration
        }

        public var body: some View {
            _MPSBlurOverlay(configuration: configuration)
                .allowsHitTesting(false)
        }
    }
#endif
