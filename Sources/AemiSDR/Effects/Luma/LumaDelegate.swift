import Foundation
import ObjectiveC
import QuartzCore

/// The delegate a tracking backdrop calls with its luma. Its one method is private API by name, so it is not declared
/// with `@objc(…)` (that would put the name in the binary in clear, ADR-0003): it is added to this class at run time,
/// once, under the interned selector, with the encoding the system's own implementations have (`v32@0:8@16d24`, probed
/// on `SwiftUI.SDFLayer` and AppKit's scroll pocket on macOS 27.2).
/// `@unchecked Sendable`: its only state is a `let` holding a main-actor closure, which is `Sendable`.
final class LumaDelegate: NSObject, CALayerDelegate, @unchecked Sendable {
    /// Called on the main actor with each luma the layer reports.
    let report: @MainActor @Sendable (Double) -> Void

    init(report: @escaping @MainActor @Sendable (Double) -> Void) {
        self.report = report
        super.init()
        _ = Self.installOnce
    }

    /// Adds the method on first use; false when the class already had it or the runtime refused.
    private static let installOnce: Bool = {
        let selector = NSSelectorFromString(_InternedKeys.lumaChangeSelector)
        let body: @convention(block) (AnyObject, AnyObject, Double) -> Void = { this, _, luma in
            guard let delegate = this as? LumaDelegate else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated { delegate.report(luma) }
            } else {
                Task { @MainActor in delegate.report(luma) }
            }
        }
        // The block's type matches the encoding the method is added with: the receiver, the layer, a double.
        let implementation = unsafe imp_implementationWithBlock(body)
        return unsafe class_addMethod(LumaDelegate.self, selector, implementation, "v32@0:8@16d24")
    }()
}
