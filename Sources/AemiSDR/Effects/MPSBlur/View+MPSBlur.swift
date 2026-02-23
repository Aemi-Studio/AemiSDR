//
//  View+MPSBlur.swift
//  AemiSDR
//

#if os(iOS)
    import SwiftUI

    extension View {
        /// Applies an MPS Gaussian blur effect as a background.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func mpsBlurBackground(
            _ configuration: MPSBlurConfiguration = .standard,
            ignoreSafeArea: Bool = false
        ) -> some View {
            background {
                MPSBlurView(configuration: configuration)
                    .conditionalIgnoreSafeArea(ignoreSafeArea)
            }
        }

        /// Applies an MPS Gaussian blur effect as an overlay.
        @available(iOS 15.0, *)
        @ViewBuilder
        public func mpsBlurOverlay(
            _ configuration: MPSBlurConfiguration = .standard,
            ignoreSafeArea: Bool = false
        ) -> some View {
            overlay {
                MPSBlurView(configuration: configuration)
                    .conditionalIgnoreSafeArea(ignoreSafeArea)
            }
        }
    }
#endif
