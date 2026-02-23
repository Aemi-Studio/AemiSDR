//
//  BackdropCaptureView.swift
//  AemiSDR
//

#if os(iOS)
    import UIKit

    /// A UIView backed by `CABackdropLayer` that captures composited content behind it
    /// at the window-server level.
    ///
    /// Each effect inserts this as a sibling below itself in the superview. Calling
    /// `drawHierarchy` on this view yields the composited backdrop — no hierarchy walking,
    /// no feedback loops, and stacking multiple effects works naturally.
    ///
    /// On iOS 26+, `windowServerAware` and `layerUsesCoreImageFilters` were removed.
    /// The backdrop layer now enables capture via the `enabled` property (defaults to true)
    /// and supports `captureOnly`, `disablesOccludedBackdropBlurs`, `reducesCaptureBitDepth`
    /// for performance tuning.
    @MainActor
    final class BackdropCaptureView: UIView {
        override class var layerClass: AnyClass {
            NSClassFromString(_InternedKeys.backdropLayerClass) ?? CALayer.self
        }

        init() {
            super.init(frame: .zero)
            configureBackdropLayer()
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Whether the setter for a given key exists on this layer.
        /// Uses `set<Key>:` selector convention which works for both bool (`isX`/`setX:`)
        /// and non-bool (`x`/`setX:`) ObjC properties.
        private static func layerHasSetter(_ key: String, on layer: CALayer) -> Bool {
            let first = key.prefix(1).uppercased()
            let rest = key.dropFirst()
            let setter = NSSelectorFromString("set\(first)\(rest):")
            return layer.responds(to: setter)
        }

        private func configureBackdropLayer() {
            let backdrop = layer

            // Unique group name to avoid cross-effect interference
            backdrop.setValue(UUID().uuidString, forKey: _InternedKeys.backdropGroupNameKey)

            // iOS 26+: use new API surface
            if Self.layerHasSetter(_InternedKeys.backdropEnabledKey, on: backdrop) {
                backdrop.setValue(true, forKey: _InternedKeys.backdropEnabledKey)

                // Render captured content (not capture-only mode) so drawHierarchy works
                if Self.layerHasSetter(_InternedKeys.backdropCaptureOnlyKey, on: backdrop) {
                    backdrop.setValue(false, forKey: _InternedKeys.backdropCaptureOnlyKey)
                }

                // Disable occluded blur optimization — we need accurate capture
                if Self.layerHasSetter(_InternedKeys.backdropDisablesOccludedKey, on: backdrop) {
                    backdrop.setValue(true, forKey: _InternedKeys.backdropDisablesOccludedKey)
                }
            }

            // Pre-iOS 26: legacy keys
            if Self.layerHasSetter(_InternedKeys.windowServerAwareKey, on: backdrop) {
                backdrop.setValue(true, forKey: _InternedKeys.windowServerAwareKey)
            }
            if Self.layerHasSetter(_InternedKeys.coreImageFiltersKey, on: backdrop) {
                backdrop.setValue(false, forKey: _InternedKeys.coreImageFiltersKey)
            }
        }

        /// Enables reduced bit-depth capture for better performance at the cost
        /// of some color precision. Useful when the captured content will be heavily
        /// blurred anyway.
        func setReducedBitDepth(_ enabled: Bool) {
            guard Self.layerHasSetter(_InternedKeys.backdropReducesBitDepthKey, on: layer) else { return }
            layer.setValue(enabled, forKey: _InternedKeys.backdropReducesBitDepthKey)
        }

        /// Sets the backdrop capture scale. Lower values reduce GPU work.
        func setCaptureScale(_ scale: CGFloat) {
            guard Self.layerHasSetter(_InternedKeys.scaleFactorKey, on: layer) else { return }
            layer.setValue(scale, forKey: _InternedKeys.scaleFactorKey)
        }
    }
#endif
