import Abysm
import QuartzCore

/// `CABackdropLayer` (QuartzCore, private) resolved once through Abysm (ADR-0002): its type, and the setters both its
/// users (a blur, ADR-0009; a luma reader, ADR-0010) give it, typed and checked. Nil when private API is off or a name
/// does not resolve.
struct BackdropLayerClass {
    let runtime: RuntimeClass
    let type: CALayer.Type
    let setScale: (CALayer, Double) throws(RuntimeError) -> Void
    let setGroupName: (CALayer, String) throws(RuntimeError) -> Void

    init?() {
        guard RuntimeAccess.isEnabled,
            let backdrop = try? RuntimeClass(_InternedKeys.backdropClass, in: .quartzCore),
            let type = backdrop.value as? CALayer.Type,
            let scale = try? backdrop.action(_InternedKeys.setScaleSelector, as: ((Double) -> Void).self),
            let group = try? backdrop.action(_InternedKeys.setGroupNameSelector, as: ((String) -> Void).self)
        else { return nil }
        runtime = backdrop
        self.type = type
        setScale = { (layer: CALayer, value: Double) throws(RuntimeError) in try scale(on: layer, value) }
        setGroupName = { (layer: CALayer, name: String) throws(RuntimeError) in try group(on: layer, name) }
    }

    /// A setter of one flag, resolved on the same class.
    func flag(_ selector: String) -> ((CALayer, Bool) throws(RuntimeError) -> Void)? {
        guard let action = try? runtime.action(selector, as: ((Bool) -> Void).self) else { return nil }
        return { (layer: CALayer, value: Bool) throws(RuntimeError) in try action(on: layer, value) }
    }
}
