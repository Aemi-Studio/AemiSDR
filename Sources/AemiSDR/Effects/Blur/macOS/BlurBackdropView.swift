#if os(macOS)
    import SwiftUI

    /// A SwiftUI view that blurs what is under it in its window (ADR-0009): place it behind a bar, sized to the blurred area.
    ///
    /// ```swift
    /// BlurBackdropView(.variable(radius: 24, mask: .edge(.top, solid: 38, fade: 38)))
    ///     .frame(height: 76)
    /// ```
    ///
    /// It takes no clicks. Without the private backdrop it is the system's material, cut by the same mask; with Reduce Transparency,
    /// the window's background colour.
    public struct BlurBackdropView: NSViewRepresentable {
        private let recipe: BlurRecipe
        private let groupName: String?

        /// `groupName`: backdrops with the same name share one capture (cheaper when several sit over the same content).
        public init(_ recipe: BlurRecipe, groupName: String? = nil) {
            self.recipe = recipe
            self.groupName = groupName
        }

        public func makeNSView(context: Context) -> BlurBackdropNSView {
            let view = BlurBackdropNSView(frame: .zero)
            view.groupName = groupName
            view.recipe = recipe
            return view
        }

        public func updateNSView(_ view: BlurBackdropNSView, context: Context) {
            // Only stored here; the view applies it on the next turn, outside SwiftUI's update.
            view.recipe = recipe
        }
    }
#endif
