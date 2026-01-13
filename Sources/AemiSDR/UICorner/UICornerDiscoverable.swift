//
//  UICornerDiscoverable.swift
//  AemiSDR
//

#if os(iOS)
    import UIKit

    /// Protocol for UI elements that can discover their screen's corner radius.
    ///
    /// Provides a consistent interface for getting corner radius information
    /// across different UIKit types (views, view controllers, windows).
    ///
    /// - Note: Available across iOS, tvOS, watchOS, and macOS (Mac Catalyst)
    @MainActor
    protocol UICornerDiscoverable {
        /// The corner radius of the screen containing this UI element
        var screenCornerRadius: CGFloat { get }
    }
#endif
