//
//  _VisualEffectInternals.swift
//  AemiSDR
//

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
            backdropView?._filterValue(forKey: _InternedKeys.filters, filterType: _InternedKeys.gaussianBlur)
        }

        var sourceOver: NSObject? {
            overlayView?._filterValue(forKey: _InternedKeys.viewEffects, filterType: _InternedKeys.sourceOver)
        }

        func prepareForChanges() {
            effect = UIBlurEffect(style: .light)
            gaussianBlur?.setValue(1.0, forKeyPath: _InternedKeys.requestedScaleHint)
        }

        func applyChanges() {
            backdropView?.perform(Selector(_InternedKeys.applyRequestedFilterEffects))
        }
    }

    // MARK: - NSObject Filter Value Access

    extension NSObject {
        var requestedValues: [String: Any]? {
            get { value(forKeyPath: _InternedKeys.requestedValues) as? [String: Any] }
            set { setValue(newValue, forKeyPath: _InternedKeys.requestedValues) }
        }

        func _filterValue(forKey key: String, filterType: String) -> NSObject? {
            guard let objects = value(forKeyPath: key) as? [NSObject] else {
                return nil
            }
            return objects.first { $0.value(forKeyPath: _InternedKeys.filterType) as? String == filterType }
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
        /// Access the internal CABackdropLayer via KVC.
        var backdropLayer: CALayer? {
            value(forKey: _InternedKeys._backdropLayer) as? CALayer
        }

        /// Read the gaussianBlur CAFilter from the backdrop layer's filters array.
        var gaussianBlurFilter: NSObject? {
            backdropLayer?._filterValue(forKey: _InternedKeys.filters, filterType: _InternedKeys.gaussianBlur)
        }

        /// Read the colorSaturate CAFilter from the backdrop layer's filters array.
        var colorSaturateFilter: NSObject? {
            backdropLayer?._filterValue(forKey: _InternedKeys.filters, filterType: _InternedKeys.colorSaturate)
        }

        /// Read the colorBrightness CAFilter from the backdrop layer's filters array.
        var colorBrightnessFilter: NSObject? {
            backdropLayer?._filterValue(forKey: _InternedKeys.filters, filterType: _InternedKeys.colorBrightness)
        }
    }

    // MARK: - NSObject Filter Value Access

    extension NSObject {
        func _filterValue(forKey key: String, filterType: String) -> NSObject? {
            guard let objects = value(forKeyPath: key) as? [NSObject] else {
                return nil
            }
            return objects.first { $0.value(forKeyPath: _InternedKeys.filterType) as? String == filterType }
        }
    }
#endif
