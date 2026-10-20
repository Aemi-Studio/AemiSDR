//
//  DisplayCornerSources+UIKit.swift
//  AemiSDR
//

#if os(iOS)
    import UIKit

    extension DisplayCornerSources {
        /// Reads every source the system offers for a display's corners. Each read is a private-API call checked
        /// against the runtime's signature (Abysm); a source that is gone reads as `nil` and the next is used.
        ///
        /// - Parameters:
        ///   - scene: The window scene showing the content, when known. Without one, only the scalar sources exist.
        ///   - screen: The screen, for the scalar source.
        @MainActor
        static func read(scene: UIWindowScene?, screen: UIScreen) -> DisplayCornerSources {
            var sources = DisplayCornerSources()
            sources.screenScalar = scalar(of: screen, getter: _InternedKeys.screenCornerRadiusKey)
            let traits = scene?.traitCollection ?? screen.traitCollection
            sources.traitScalar = scalar(of: traits, getter: _InternedKeys.traitCornerRadiusKey)

            if let scene,
                let backing = object(of: scene, getter: _InternedKeys.sceneBackingKey),
                let settings = object(of: backing, getter: _InternedKeys.sceneSettingsKey),
                let configuration = object(of: settings, getter: _InternedKeys.cornerConfigurationKey)
            {
                sources.perCorner = corners(
                    of: configuration,
                    names: (
                        _InternedKeys.cornerTopLeftKey, _InternedKeys.cornerTopRightKey,
                        _InternedKeys.cornerBottomLeftKey, _InternedKeys.cornerBottomRightKey
                    )
                )
            }
            return sources
        }
    }
#endif
