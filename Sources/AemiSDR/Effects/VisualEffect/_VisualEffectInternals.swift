//
//  _VisualEffectInternals.swift
//  AemiSDR
//

import Foundation
import OSLog

// MARK: - Private-API Diagnostics

/// Emits a `.fault`-level OSLog message exactly once per process per `key`.
///
/// Used to surface private-API drift (missing selectors, classes, KVC keys)
/// without spamming the log every frame. The cost on the hot path is one
/// `Set.contains` under a short-held lock.
internal enum _PrivateAPIDiagnostics {
    nonisolated(unsafe) private static var loggedKeys: Set<String> = []
    nonisolated private static let lock = NSLock()
    nonisolated private static let logger = Logger(
        subsystem: "studio.aemi.AemiSDR",
        category: "PrivateAPI"
    )

    /// Fires exactly once per process per `key`. Subsequent calls with the same
    /// `key` are no-ops.
    static func logOnce(key: String, _ message: String) {
        lock.lock()
        defer { lock.unlock() }
        // Access guarded by `lock`; the `nonisolated(unsafe)` is documented at
        // the storage declaration.
        guard unsafe !loggedKeys.contains(key) else { return }
        unsafe loggedKeys.insert(key)
        logger.fault("\(message, privacy: .public)")
    }
}

// MARK: - Shared Filter Value Access

extension NSObject {
    /// Finds a filter object by its type within a KVC-accessible array.
    ///
    /// Used on both platforms to traverse private `CAFilter` / view-effect arrays.
    /// Checks `filterType` (iOS / older macOS), then `type` and `name` (macOS 26+)
    /// where CAFilter changed its key layout.
    func _filterValue(forKey key: String, filterType: String) -> NSObject? {
        guard let objects = value(forKeyPath: key) as? [NSObject] else {
            return nil
        }
        return objects.first { filter in
            for lookupKey in [_InternedKeys.kindKey, _InternedKeys.kindFallbackA, _InternedKeys.kindFallbackB] {
                if filter.responds(to: NSSelectorFromString(lookupKey)),
                   let value = filter.value(forKeyPath: lookupKey) as? String,
                   value == filterType
                {
                    return true
                }
            }
            return false
        }
    }
}

#if os(iOS)
    import UIKit

    // MARK: - UIVisualEffectView Internal Access

    extension UIVisualEffectView {
        var backdropView: UIView? {
            _subview(of: NSClassFromString(_InternedKeys.backdropViewClass))
        }

        var overlayView: UIView? {
            _subview(of: NSClassFromString(_InternedKeys.overlaySubviewClass))
        }

        var gaussianBlur: NSObject? {
            backdropView?._filterValue(forKey: _InternedKeys.filterListKey, filterType: _InternedKeys.blurFilterID)
        }

        var colorSaturate: NSObject? {
            backdropView?._filterValue(forKey: _InternedKeys.filterListKey, filterType: _InternedKeys.saturateFilterID)
        }

        var sourceOver: NSObject? {
            overlayView?._filterValue(forKey: _InternedKeys.effectsListKey, filterType: _InternedKeys.compositeFilterID)
        }

        func prepareForChanges() {
            effect = UIBlurEffect(style: .light)
            gaussianBlur?.setValue(1.0, forKeyPath: _InternedKeys.scaleHintKey)
        }

        func applyChanges() {
            guard let backdropView else { return }
            let sel = Selector(_InternedKeys.commitFiltersSelector)
            guard backdropView.responds(to: sel) else {
                _PrivateAPIDiagnostics.logOnce(
                    key: "commitFiltersSelector",
                    "Private selector `\(_InternedKeys.commitFiltersSelector)` is not implemented by \(type(of: backdropView)); backdrop filter changes will not commit. The host iOS version may have removed this API."
                )
                return
            }
            _ = unsafe backdropView.perform(sel)
        }
    }

    // MARK: - NSObject Requested Values (iOS)

    extension NSObject {
        var requestedValues: [String: Any]? {
            get { value(forKeyPath: _InternedKeys.pendingValuesKey) as? [String: Any] }
            set { setValue(newValue, forKeyPath: _InternedKeys.pendingValuesKey) }
        }
    }

    // MARK: - UIView Subview Access

    extension UIView {
        func _subview(of classType: AnyClass?) -> UIView? {
            subviews.first { type(of: $0) == classType }
        }
    }

#elseif os(macOS)
    import AppKit

    // MARK: - NSVisualEffectView Internal Access

    extension NSVisualEffectView {
        /// Access the internal `CABackdropLayer` from the layer tree.
        ///
        /// On macOS < 26 this tries the `_backdropLayer` KVC property first.
        /// On macOS 26+ that property was removed, so we fall back to
        /// traversing the layer hierarchy to find the `CABackdropLayer`.
        var backdropLayer: CALayer? {
            if responds(to: NSSelectorFromString(_InternedKeys.backdropLayerRef)),
               let layer = value(forKey: _InternedKeys.backdropLayerRef) as? CALayer
            {
                return layer
            }
            func find(in layer: CALayer) -> CALayer? {
                if NSStringFromClass(type(of: layer)) == _InternedKeys.backdropLayerClassName { return layer }
                return layer.sublayers?.lazy.compactMap { find(in: $0) }.first
            }
            return layer.flatMap { find(in: $0) }
        }

        /// The `gaussianBlur` CAFilter from the backdrop layer's filters array.
        var gaussianBlurFilter: NSObject? {
            backdropLayer?._filterValue(forKey: _InternedKeys.filterListKey, filterType: _InternedKeys.blurFilterID)
        }

        /// The `colorSaturate` CAFilter from the backdrop layer's filters array.
        var colorSaturateFilter: NSObject? {
            backdropLayer?._filterValue(forKey: _InternedKeys.filterListKey, filterType: _InternedKeys.saturateFilterID)
        }

        /// The `colorBrightness` CAFilter from the backdrop layer's filters array.
        var colorBrightnessFilter: NSObject? {
            backdropLayer?._filterValue(forKey: _InternedKeys.filterListKey, filterType: _InternedKeys.brightnessFilterID)
        }
    }
#endif
