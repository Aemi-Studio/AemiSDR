import Abysm
import QuartzCore

/// A `CABackdropLayer` (QuartzCore, private) that blurs what is under it in its window by a `BlurRecipe` (ADR-0009). Made through
/// Abysm; `-setScale:` is checked to take a double (probed `v24@0:8d16`) and `-setGroupName:` an object. Applying a recipe equal to
/// the last one does nothing; a different one replaces the filter list once.
@MainActor
final class BlurBackdropLayer {
    let layer: CALayer
    private let setScale: (CALayer, Double) throws(RuntimeError) -> Void
    private(set) var applied: BlurRecipe?
    /// Test seam: how many times the filter list was assigned.
    private(set) var filterAssignmentCount = 0

    private init(layer: CALayer, setScale: @escaping (CALayer, Double) throws(RuntimeError) -> Void) {
        self.layer = layer
        self.setScale = setScale
    }

    /// A backdrop layer, or nil when private API is off or the class or its setters do not resolve. Layers with the same
    /// `groupName` share one capture of what is under them.
    static func make(groupName: String? = nil) -> BlurBackdropLayer? {
        guard RuntimeAccess.isEnabled,
            let backdrop = try? RuntimeClass(_InternedKeys.backdropClass, in: .quartzCore),
            let type = backdrop.value as? CALayer.Type,
            let scale = try? backdrop.action(_InternedKeys.setScaleSelector, as: ((Double) -> Void).self),
            let group = try? backdrop.action(_InternedKeys.setGroupNameSelector, as: ((String) -> Void).self)
        else {
            _PrivateAPIDiagnostics.logOnce(
                key: "blurBackdropLayer", "CABackdropLayer unavailable; blur falls back to the material.")
            return nil
        }
        let layer = type.init()
        if let groupName { try? group(on: layer, groupName) }
        return BlurBackdropLayer(layer: layer) { (layer: CALayer, value: Double) throws(RuntimeError) in
            try scale(on: layer, value)
        }
    }

    /// Installs the recipe's filters; false when they could not be made (the caller falls back). Equal recipes do no work.
    @discardableResult
    func apply(_ recipe: BlurRecipe) -> Bool {
        if recipe == applied { return true }
        guard let filters = BlurFilterFactory.filters(for: recipe) else { return false }
        if recipe.captureScale.isFinite, recipe.captureScale > 0, recipe.captureScale != applied?.captureScale {
            try? setScale(layer, recipe.captureScale)
        }
        layer.filters = filters
        filterAssignmentCount += 1
        applied = recipe
        return true
    }
}
