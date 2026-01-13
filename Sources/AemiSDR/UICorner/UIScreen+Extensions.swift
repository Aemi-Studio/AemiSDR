//
//  UIScreen+Extensions.swift
//  AemiSDR
//

#if os(iOS)
    import UIKit

    extension UIScreen {
        /// The currently active screen based on the most relevant UI context.
        ///
        /// This property attempts to intelligently determine the most appropriate screen
        /// by examining the current application state and connected scenes. It provides
        /// a more context-aware alternative to `UIScreen.main` for multi-screen scenarios.
        ///
        /// The selection priority is:
        /// 1. Screen from the foreground active window scene
        /// 2. Screen from any active window scene
        /// 3. Main screen as ultimate fallback
        ///
        /// - Returns: The most contextually relevant screen, or main screen if unavailable
        /// - Note: On watchOS, always returns the main screen since multi-screen isn't supported
        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
        public static var activeScreen: UIScreen? {
            #if os(watchOS)
                // watchOS always uses the main (and only) screen
                UIScreen.main
            #else
                // Find the most active window scene and use its screen
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .filter { $0.activationState != .unattached }
                    .sorted { lhs, rhs in
                        // Prioritize foreground active over background active
                        if lhs.activationState == .foregroundActive, rhs.activationState != .foregroundActive {
                            return true
                        } else if rhs.activationState == .foregroundActive, lhs.activationState != .foregroundActive {
                            return false
                        }
                        return lhs.activationState.rawValue < rhs.activationState.rawValue
                    }
                    .first?
                    .screen ?? UIScreen.main
            #endif
        }

        /// The display corner radius for this screen instance.
        ///
        /// This property uses a private UIKit API to retrieve the actual corner radius
        /// of the device's display. Returns 0 if the value cannot be determined.
        ///
        /// - Note: On watchOS, this typically returns the Apple Watch's corner radius.
        /// - Note: On macOS, this returns 0 unless running on a device with rounded display corners.
        public var displayCornerRadius: CGFloat {
            value(forKey: "_displayCornerRadius") as? CGFloat ?? 0
        }

        /// Static accessor for the main screen's display corner radius.
        ///
        /// This is a convenience method that attempts to find an appropriate screen
        /// context and retrieve its corner radius with intelligent fallbacks.
        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
        public static var displayCornerRadius: CGFloat {
            getDisplayCornerRadius()
        }

        /// Retrieves the display corner radius from various UI contexts with intelligent fallbacks.
        ///
        /// This method provides a robust way to get the corner radius by trying multiple
        /// approaches in order of preference:
        /// 1. Direct screen access from provided context
        /// 2. Active window scene discovery (iOS/tvOS only)
        /// 3. Device-based estimation as last resort
        ///
        /// - Parameter context: Optional context to determine which screen to use
        /// - Returns: The corner radius in points, or an estimated value if unavailable
        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
        internal static func getDisplayCornerRadius(from context: UICornerContext? = nil) -> CGFloat {
            let screen: UIScreen? =
                switch context {
                case .view(let view):
                    // Traverse view hierarchy to find the containing screen
                    #if os(watchOS)
                        // On watchOS, there's typically only one screen
                        activeScreen
                    #else
                        view.window?.windowScene?.screen
                    #endif

                #if !os(watchOS)
                    case .window(let window):
                        // Direct access to window's screen
                        window.windowScene?.screen
                    case .windowScene(let windowScene):
                        // Direct access to scene's screen
                        windowScene.screen
                #endif

                case .none:
                    activeScreen
                }

            return screen?.displayCornerRadius ?? estimatedCornerRadius()
        }

        /// Provides device-specific corner radius estimates when screen context is unavailable.
        ///
        /// Uses device characteristics to provide reasonable fallback values.
        /// These values are approximations based on common device corner radii.
        /// For watchOS, it uses the active screen's dimensions for more accurate sizing.
        ///
        /// - Returns: Estimated corner radius in points based on device type
        private static func estimatedCornerRadius() -> CGFloat {
            let idiom = UIDevice.current.userInterfaceIdiom

            switch idiom {
            case .phone:
                // Modern iPhones typically have ~42pt corner radius
                return 42.0
            case .pad:
                // iPads have smaller relative corner radius
                return 20.0
            case .tv:
                // Apple TV interfaces typically don't have rounded corners
                return 0.0
            #if !os(watchOS)
                case .carPlay:
                    // CarPlay displays vary, use conservative estimate
                    return 8.0
                case .mac:
                    // Mac displays typically don't have rounded corners in UIKit apps
                    return 0.0
                case .vision:
                    // Vision Pro apps may have rounded corners
                    return 16.0
            #endif
            #if os(watchOS)
                case .watch:
                    // Apple Watch has significant corner radius
                    // Values vary by watch size: 38mm/40mm/41mm ≈ 8pt, 42mm/44mm/45mm/49mm ≈ 10pt
                    // Use activeScreen for better accuracy in case of future multi-screen watch support
                    let screenSize = (activeScreen ?? UIScreen.main).bounds.size
                    let maxDimension = max(screenSize.width, screenSize.height)
                    return maxDimension > 200 ? 10.0 : 8.0
            #endif
            case .unspecified:
                // Unspecified device type - use conservative fallback
                #if os(watchOS)
                    return 8.0  // Assume watch-like behavior for unknown watchOS devices
                #else
                    return 0.0  // Conservative for other platforms
                #endif
            @unknown default:
                // Conservative fallback for future device types
                #if os(watchOS)
                    return 8.0  // Assume watch-like behavior for unknown watchOS devices
                #else
                    return 0.0  // Conservative for other platforms
                #endif
            }
        }
    }

    // MARK: - UICornerDiscoverable Conformances

    extension UICornerDiscoverable where Self: UIView {
        /// Get the corner radius for the screen containing this view.
        ///
        /// Traverses the view hierarchy to find the containing window and screen.
        /// Returns 0 if no screen context can be determined.
        ///
        /// - Note: On watchOS, this uses the main screen directly.
        var screenCornerRadius: CGFloat {
            UIScreen.getDisplayCornerRadius(from: .view(self))
        }
    }

    extension UICornerDiscoverable where Self: UIViewController {
        /// Get the corner radius for the screen containing this view controller.
        ///
        /// Uses the view controller's view to determine the screen context.
        /// Returns 0 if no screen context can be determined.
        var screenCornerRadius: CGFloat {
            UIScreen.getDisplayCornerRadius(from: .view(view))
        }
    }

    #if !os(watchOS)
        extension UICornerDiscoverable where Self: UIWindow {
            /// Get the corner radius for this window's screen.
            ///
            /// Directly accesses the window's associated screen.
            /// Returns 0 if no screen context can be determined.
            ///
            /// - Note: Not available on watchOS as UIWindow doesn't conform to UICornerDiscoverable there.
            var screenCornerRadius: CGFloat {
                UIScreen.getDisplayCornerRadius(from: .window(self))
            }
        }
    #endif

    // MARK: - Default Conformances

    extension UIView: UICornerDiscoverable {}

    extension UIViewController: UICornerDiscoverable {}
#endif
