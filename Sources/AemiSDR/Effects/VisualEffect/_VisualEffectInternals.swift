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
#endif
