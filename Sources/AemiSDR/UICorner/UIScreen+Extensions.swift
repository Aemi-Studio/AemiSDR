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
            activeScene?.screen ?? UIScreen.main
        }

        /// The most active window scene: foreground active first, then by activation state.
        static var activeScene: UIWindowScene? {
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
                .first
        }

        /// The radius of each corner of this screen's display.
        ///
        /// On a uniform display all four are equal. On the iPhone Duo they are not (8 pt hinge side, 59 pt on the
        /// other side, probed on the iOS 27.2 simulator), which is why this exists: a single number cannot say so.
        ///
        /// Reads the scene's per-corner configuration when a scene shows this screen, then the scalar sources, then
        /// an estimate by idiom. Every private read is signature-checked and never raises.
        public var displayCornerRadii: DisplayCornerRadii {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.screen === self && $0.activationState != .unattached }
                .min { $0.activationState.rawValue < $1.activationState.rawValue }
            return Self.displayCornerRadii(scene: scene, screen: self)
        }

        /// The display corner radius for this screen: the largest of the four corners.
        ///
        /// Prefer `displayCornerRadii`. This is the conservative single value for content that must clear every
        /// corner, and equals the system's own scalar on every display probed, including the Duo's 59 pt.
        public var displayCornerRadius: CGFloat {
            displayCornerRadii.maximum
        }

        /// Static accessor for the active screen's display corner radius.
        @available(iOS 13.0, tvOS 13.0, *)
        public static var displayCornerRadius: CGFloat {
            getDisplayCornerRadii().maximum
        }

        /// Static accessor for the active screen's per-corner radii.
        @available(iOS 13.0, tvOS 13.0, *)
        public static var displayCornerRadii: DisplayCornerRadii {
            getDisplayCornerRadii()
        }

        static func displayCornerRadii(scene: UIWindowScene?, screen: UIScreen) -> DisplayCornerRadii {
            DisplayCornerRadii.resolve(
                DisplayCornerSources.read(scene: scene, screen: screen),
                estimate: estimatedCornerRadius()
            )
        }

        /// Retrieves the display corner radii from the context given, falling back to the active scene's.
        @available(iOS 13.0, tvOS 13.0, *)
        internal static func getDisplayCornerRadii(from context: UICornerContext? = nil) -> DisplayCornerRadii {
            let scene: UIWindowScene? =
                switch context {
                case .view(let view): view.window?.windowScene
                case .window(let window): window.windowScene
                case .windowScene(let windowScene): windowScene
                case .none: activeScene
                }
            guard let screen = scene?.screen ?? activeScreen else {
                return DisplayCornerRadii(uniform: estimatedCornerRadius())
            }
            return displayCornerRadii(scene: scene, screen: screen)
        }

        /// The scalar form of `getDisplayCornerRadii`, kept for existing call sites.
        @available(iOS 13.0, tvOS 13.0, *)
        internal static func getDisplayCornerRadius(from context: UICornerContext? = nil) -> CGFloat {
            getDisplayCornerRadii(from: context).maximum
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

#endif
