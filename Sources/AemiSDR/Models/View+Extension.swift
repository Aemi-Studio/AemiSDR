//
//  View+Extension.swift
//  AemiSDR
//

import SwiftUI

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
