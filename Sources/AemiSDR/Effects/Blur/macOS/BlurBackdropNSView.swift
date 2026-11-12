#if os(macOS)
    import AppKit

    /// A view that blurs what is under it in its window by a `BlurRecipe` (ADR-0009, roadmap 0020). A recipe given is applied on
    /// the next main-actor turn, never in the one it was given in: SwiftUI gives it during an update, and changing the layer tree
    /// then crashes on macOS 26 (noted in `BackdropBlurView`). Several recipes in one turn are applied once, the last.
    ///
    /// Without the private backdrop (policy off, class missing) it is the system's material, cut by the same mask; with Reduce
    /// Transparency it is the window's background colour.
    public final class BlurBackdropNSView: NSView {
        public var recipe: BlurRecipe? {
            didSet { if recipe != oldValue { schedule() } }
        }
        /// Backdrops with the same group share one capture of what is under them.
        public var groupName: String?

        private(set) var mode: BlurBackdropMode?
        private var backdrop: BlurBackdropLayer?
        private var material: NSVisualEffectView?
        private var scheduled = false
        private var accessibilityObserver: (any NSObjectProtocol)?

        /// Test seam: the backdrop's filter assignments.
        var filterAssignmentCount: Int { backdrop?.filterAssignmentCount ?? 0 }

        override public init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedule(rebuild: true) }
            }
        }

        @available(*, unavailable)
        public required init?(coder: NSCoder) { nil }

        isolated deinit {
            if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) }
        }

        override public func hitTest(_ point: NSPoint) -> NSView? { nil }

        override public func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            backdrop?.layer.frame = bounds
            CATransaction.commit()
            material?.frame = bounds
        }

        private var rebuildPending = false

        private func schedule(rebuild: Bool = false) {
            rebuildPending = rebuildPending || rebuild
            guard !scheduled else { return }
            scheduled = true
            Task { @MainActor [weak self] in self?.applyPending() }
        }

        /// Applies the latest recipe now. Called on the turn after it was given (and by tests).
        func applyPending() {
            scheduled = false
            let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            if rebuildPending || mode == nil || (mode == .opaque) != reduce {
                rebuild(reduceTransparency: reduce)
            }
            rebuildPending = false
            guard let recipe else { return }
            switch mode {
            case .backdrop:
                if backdrop?.apply(recipe) == false {
                    backdrop?.layer.removeFromSuperlayer()
                    backdrop = nil
                    installMaterial(for: recipe)
                }
            case .material: installMaterial(for: recipe)
            case .opaque, nil: break
            }
        }

        private func rebuild(reduceTransparency: Bool) {
            backdrop?.layer.removeFromSuperlayer()
            backdrop = nil
            material?.removeFromSuperview()
            material = nil
            layer?.backgroundColor = nil
            let made = reduceTransparency ? nil : BlurBackdropLayer.make(groupName: groupName)
            mode = BlurBackdropMode.choose(reduceTransparency: reduceTransparency, backdropAvailable: made != nil)
            switch mode {
            case .backdrop:
                guard let made else { return }
                made.layer.frame = bounds
                layer?.addSublayer(made.layer)
                backdrop = made
            case .opaque: layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            case .material, nil: break
            }
        }

        /// The system's material in the backdrop's place, within the window, cut by the recipe's mask so that a variable blur's
        /// fallback fades too.
        private func installMaterial(for recipe: BlurRecipe) {
            let view = material ?? NSVisualEffectView(frame: bounds)
            view.blendingMode = .withinWindow
            view.material = .headerView
            view.state = .followsWindowActiveState
            if case .variable(let mask) = recipe.shape, let image = BlurMaskImages.image(for: mask) {
                view.maskImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            } else {
                view.maskImage = nil
            }
            if material == nil {
                view.autoresizingMask = [.width, .height]
                addSubview(view)
                material = view
            }
        }
    }
#endif
