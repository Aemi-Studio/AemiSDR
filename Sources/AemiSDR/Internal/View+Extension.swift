//
//  View+Extension.swift
//  AemiSDR
//

import SwiftUI

#if os(iOS)
    import UIKit

    // MARK: - UIView Display Scale

    extension UIView {
        /// The current display scale factor, falling back to the main screen scale.
        var displayScale: CGFloat {
            window?.screen.scale ?? UIScreen.main.scale
        }
    }
#endif

// MARK: - Internal View Extensions

extension View {
    /// Conditionally applies `ignoresSafeArea()` modifier to the view.
    ///
    /// This is a helper modifier that conditionally applies safe area ignorance
    /// based on a boolean parameter, avoiding repetitive conditional code in
    /// other view modifiers.
    ///
    /// - Parameter ignore: Whether to ignore safe area (default: false when not specified)
    /// - Returns: The view with or without safe area ignorance applied
    @ViewBuilder
    func conditionalIgnoreSafeArea(_ ignore: Bool) -> some View {
        if ignore {
            ignoresSafeArea()
        } else {
            self
        }
    }
}
