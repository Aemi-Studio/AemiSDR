#if os(iOS)
    import Abysm
    import SwiftUI
    import UIKit

    /// A live effect's scalar recipe. Deliberately not the entire material: its additional tonal-map filters
    /// cannot be represented by BackdropBlurConfiguration. Private getters are checked and exceptions contained.
    @MainActor
    enum SystemBlurStyleReader {
        private struct Key: Hashable {
            let style: Int
            let appearance: Int
        }
        private static var cache: [Key: BackdropBlurConfiguration] = [:]

        static func configuration(
            for style: UIBlurEffect.Style,
            appearance: UIUserInterfaceStyle
        ) -> BackdropBlurConfiguration {
            guard PrivateAPI.isEnabled else { return .clear }
            let appearance: UIUserInterfaceStyle = appearance == .unspecified ? .light : appearance
            let key = Key(style: style.rawValue, appearance: appearance.rawValue)
            if let cached = cache[key] { return cached }
            let traits = UITraitCollection(userInterfaceStyle: appearance)
            var result: BackdropBlurConfiguration?
            traits.performAsCurrent {
                result = read(style, appearance: appearance)
            }
            guard let result else {
                _PrivateAPIDiagnostics.logOnce(
                    key: "systemStyle-\(key.style)-\(key.appearance)",
                    "System blur recipe unavailable; preset degrades to clear."
                )
                return .clear
            }
            cache[key] = result
            return result
        }

        private static func read(
            _ style: UIBlurEffect.Style,
            appearance: UIUserInterfaceStyle
        ) -> BackdropBlurConfiguration? {
            let unresolved = UIBlurEffect(style: style)
            // An unattached view does not necessarily resolve adaptive styles from its override traits.
            // Resolve the effect explicitly before asking the live view for its filter recipe.
            let resolved: UIBlurEffect? = try? PrivateObject(unresolved).call(
                _InternedKeys.resolveEffectSelector, Int(appearance.rawValue))
            guard let effect = resolved else { return nil }
            let view = UIVisualEffectView(effect: effect)
            view.overrideUserInterfaceStyle = appearance
            view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            view.layoutIfNeeded()
            guard let backdrop = view.backdropView,
                let filters: NSArray = object(backdrop, _InternedKeys.filterListKey),
                let radius = parameter(in: filters, type: _InternedKeys.blurFilterID, key: _InternedKeys.radiusParam),
                let saturation = parameter(
                    in: filters, type: _InternedKeys.saturateFilterID, key: _InternedKeys.amountParam),
                radius.isFinite, radius >= 0, saturation.isFinite, saturation >= 0
            else { return nil }

            var config = BackdropBlurConfiguration(blurRadius: radius, saturationDeltaFactor: saturation)
            // effectSettings yields a None recipe for modern styles. Do not mistake that for their real recipe.
            if [.extraLight, .light, .dark].contains(style),
                let settings: NSObject = object(effect, _InternedKeys.effectSettingsGetter)
            {
                readClassicSettings(settings, into: &config)
            }
            return config
        }

        private static func parameter(in filters: NSArray, type: String, key: String) -> CGFloat? {
            for case let filter as NSObject in filters {
                guard let kind: NSString = object(filter, _InternedKeys.kindKey), kind as String == type,
                    let values: NSDictionary = object(filter, _InternedKeys.pendingValuesKey),
                    let number = values[key] as? NSNumber
                else { continue }
                return CGFloat(number.doubleValue)
            }
            return nil
        }

        private static func object<Value: NSObject>(_ base: AnyObject, _ getter: String) -> Value? {
            try? PrivateObject(base).read(getter, as: Value?.self)
        }

        private static func readClassicSettings(_ settings: NSObject, into config: inout BackdropBlurConfiguration) {
            let object = PrivateObject(settings)
            let fields: [(WritableKeyPath<BackdropBlurConfiguration, CGFloat>, String)] = [
                (\.scale, _InternedKeys.scaleFactorKey),
                (\.grayscaleTintLevel, _InternedKeys.grayLevelKey),
                (\.grayscaleTintAlpha, _InternedKeys.grayAlphaKey),
                (\.colorBurnTintLevel, _InternedKeys.burnLevelKey),
                (\.colorBurnTintAlpha, _InternedKeys.burnAlphaKey),
                (\.darkeningTintAlpha, _InternedKeys.darkAlphaKey),
                (\.darkeningTintHue, _InternedKeys.darkHueKey),
                (\.darkeningTintSaturation, _InternedKeys.darkSatKey),
                (\.zoom, _InternedKeys.zoomKey),
            ]
            for (field, name) in fields {
                if let value = try? object.read(name, as: Double.self), value.isFinite {
                    config[keyPath: field] = CGFloat(value)
                }
            }
            config.lightenGrayscaleWithSourceOver =
                (try? object.read(_InternedKeys.grayTintEnabledKey, as: Bool.self)) ?? false
            config.darkenWithSourceOver = (try? object.read(_InternedKeys.burnTintEnabledKey, as: Bool.self)) ?? false
            if (try? object.read(_InternedKeys.tintEnabledKey, as: Bool.self)) == true,
                let color: UIColor = self.object(settings, _InternedKeys.tintColorKey)
            {
                config.colorTint = Color(color)
                config.colorTintAlpha = CGFloat((try? object.read(_InternedKeys.tintAlphaKey, as: Double.self)) ?? 0)
            }
        }
    }
#endif
