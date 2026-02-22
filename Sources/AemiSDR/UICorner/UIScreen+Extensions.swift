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
        @available(iOS 13.0, tvOS 13.0, *)
        public static var activeScreen: UIScreen? {
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
        }

        /// The display corner radius for this screen instance.
        ///
        /// This property uses a private UIKit API to retrieve the actual corner radius
        /// of the device's display. Returns 0 if the value cannot be determined.
        ///
        /// - Note: Returns 0 on devices without rounded display corners (e.g. Mac Catalyst).
        public var displayCornerRadius: CGFloat {
            value(forKey: _InternedKeys.screenCornerRadiusKey) as? CGFloat ?? 0
        }

        /// Static accessor for the main screen's display corner radius.
        ///
        /// This is a convenience method that attempts to find an appropriate screen
        /// context and retrieve its corner radius with intelligent fallbacks.
        @available(iOS 13.0, tvOS 13.0, *)
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
        @available(iOS 13.0, tvOS 13.0, *)
        internal static func getDisplayCornerRadius(from context: UICornerContext? = nil) -> CGFloat {
            let screen: UIScreen? =
                switch context {
                case .view(let view):
                    view.window?.windowScene?.screen
                case .window(let window):
                    window.windowScene?.screen
                case .windowScene(let windowScene):
                    windowScene.screen
                case .none:
                    activeScreen
                }

            return screen?.displayCornerRadius ?? estimatedCornerRadius()
        }

        /// Provides device-specific corner radius estimates when screen context is unavailable.
        ///
        /// Uses device characteristics to provide reasonable fallback values.
        /// These values are approximations based on common device corner radii.
        ///
        /// - Returns: Estimated corner radius in points based on device type
        private static func estimatedCornerRadius() -> CGFloat {
            let idiom = UIDevice.current.userInterfaceIdiom

            switch idiom {
            case .phone:
                return 42.0
            case .pad:
                return 20.0
            case .tv:
                return 0.0
            case .carPlay:
                return 8.0
            case .mac:
                return 0.0
            case .vision:
                return 16.0
            case .unspecified:
                return 0.0
            @unknown default:
                return 0.0
            }
        }
    }

    // MARK: - UICornerDiscoverable Conformances

    extension UICornerDiscoverable where Self: UIView {
        /// Get the corner radius for the screen containing this view.
        ///
        /// Traverses the view hierarchy to find the containing window and screen.
        /// Returns 0 if no screen context can be determined.
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

    extension UICornerDiscoverable where Self: UIWindow {
        /// Get the corner radius for this window's screen.
        var screenCornerRadius: CGFloat {
            UIScreen.getDisplayCornerRadius(from: .window(self))
        }
    }

    // MARK: - Default Conformances

    extension UIView: UICornerDiscoverable {}

    extension UIViewController: UICornerDiscoverable {}
#endif
