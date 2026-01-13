//
//  UICornerContext.swift
//  AemiSDR
//

#if os(iOS)
    import UIKit

    /// Context types for determining the appropriate screen when discovering display corner radius.
    /// Used to provide fallback mechanisms when direct screen access isn't available.
    ///
    /// - Note: On watchOS, only view contexts are meaningful as there's typically one screen.
    /// - Note: On macOS with Mac Catalyst, window and windowScene contexts work normally.
    enum UICornerContext: Sendable, Equatable, Hashable {
        /// Context from a UIView - will traverse up to find the containing screen
        case view(UIView)

        #if !os(watchOS)
            /// Context from a UIWindow - directly accesses the window's screen
            /// - Note: Not available on watchOS
            case window(UIWindow)
            /// Context from a UIWindowScene - directly accesses the scene's screen
            /// - Note: Not available on watchOS
            case windowScene(UIWindowScene)
        #endif
    }
#endif
