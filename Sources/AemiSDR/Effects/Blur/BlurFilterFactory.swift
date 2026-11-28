import Abysm
import Foundation
import QuartzCore

/// Makes the `CAFilter` a `BlurFilterSpec` describes, through Abysm (ADR-0002, ADR-0009): the class is checked to come from
/// QuartzCore, `+filterWithType:` and `-inputKeys` are checked against their type encodings (probed: `@24@0:8@16`, `@16@0:8`; `+filterTypes` `@16@0:8`),
/// resolved once per process. A value is written only when the filter has its key: `CAFilter` keeps unknown keys silently
/// (probed), so a key renamed by the OS would otherwise do nothing without a word. iOS's `CAFilter` has no `-inputKeys`
/// (iOS 27.2 simulator, diary 2026-11-28-01), so the whole core fell back to the material there; it has `-CAMLTypeForKey:`
/// (`@24@0:8@16`), which names the type of each key a filter has and nothing for any other, and is asked instead. Nothing here throws to the caller or crashes:
/// a failure makes no filter, and Abysm reports it once.
@MainActor
enum BlurFilterFactory {
    private struct Entries {
        let make: (String) throws(RuntimeError) -> NSObject?
        /// `+filterTypes`: `+filterWithType:` returns an object for any name, a made-up one included (found by a test), so the
        /// type is checked against this list first.
        let types: Set<String>
        /// Whether a filter has an input key.
        let has: (NSObject, String) -> Bool
    }

    /// Resolved on first use while private API is allowed; nil when that failed (and it is not tried again).
    private static var entries: Entries??

    private static func resolve() -> Entries? {
        guard RuntimeAccess.isEnabled else { return nil }
        if let entries { return entries }
        let resolved: Entries? = {
            guard let filter = try? RuntimeClass(_InternedKeys.caLayerFilterClass, in: .quartzCore),
                let make = try? filter.method(
                    _InternedKeys.filterCreationSelector, kind: .class, as: ((String) -> NSObject?).self),
                let has = keyCheck(filter),
                let typesMethod = try? filter.method(
                    _InternedKeys.filterTypesSelector, kind: .class, as: (() -> NSArray?).self),
                let types = (try? typesMethod()) as? [String]
            else {
                _PrivateAPIDiagnostics.logOnce(
                    key: "blurFilterFactory", "CAFilter unavailable; blur falls back to the material.")
                return nil
            }
            return Entries(
                make: { (type: String) throws(RuntimeError) -> NSObject? in try make(type) },
                types: Set(types),
                has: has
            )
        }()
        entries = .some(resolved)
        return resolved
    }

    /// How a filter is asked whether it has a key: its `-inputKeys` (macOS), else `-CAMLTypeForKey:` (iOS); nil when neither
    /// resolves.
    private static func keyCheck(_ filter: RuntimeClass) -> ((NSObject, String) -> Bool)? {
        if let keys = try? filter.method(_InternedKeys.inputKeysSelector, as: (() -> NSArray?).self) {
            return { object, key in ((try? keys(on: object)) as? [String])?.contains(key) == true }
        }
        if let type = try? filter.method(_InternedKeys.keyTypeSelector, as: ((String) -> NSObject?).self) {
            return { object, key in ((try? type(on: object, key)) ?? nil) != nil }
        }
        return nil
    }

    /// The filter, or nil when private API is off, a name does not resolve, the type is unknown, or a mask has no image.
    static func make(_ spec: BlurFilterSpec) -> NSObject? {
        guard let entries = resolve(), entries.types.contains(spec.type), let filter = try? entries.make(spec.type)
        else {
            return nil
        }
        let object = RuntimeObject(filter)
        for value in spec.values where entries.has(filter, value.key) {
            let written: Any
            switch value {
            case .number(_, let number): written = NSNumber(value: number)
            case .flag(_, let flag): written = NSNumber(value: flag)
            case .mask(_, let mask):
                guard let image = BlurMaskImages.image(for: mask) else { return nil }
                written = image
            }
            guard (try? object.setValue(written, forKey: value.key)) != nil else { return nil }
        }
        return filter
    }

    /// The filters of a recipe, in order; nil when any of them could not be made (the caller then falls back as a whole).
    static func filters(for recipe: BlurRecipe) -> [NSObject]? {
        var made: [NSObject] = []
        for spec in BlurFilterPlan.filters(for: recipe) {
            guard let filter = make(spec) else { return nil }
            made.append(filter)
        }
        return made
    }
}
