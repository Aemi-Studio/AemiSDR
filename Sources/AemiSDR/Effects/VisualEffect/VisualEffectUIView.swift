//
//  VisualEffectUIView.swift
//  AemiSDR
//
//  SwiftUI wrapper for customizable blur effects using platform-specific visual effect systems.
//
//  Based on VisualEffectView by Lasha Efremidze.
//  SwiftUI integration by 朱浩宇.
//

#if os(iOS)
    import OSLog
    import UIKit

    // MARK: - UIKit View

    /**
     * A dynamic background blur view with customizable blur radius, tint color, and scale.
     *
     * This class provides direct access to the private blur effect APIs in UIKit,
     * allowing fine-grained control over visual effect properties that aren't
     * exposed through the standard `UIBlurEffect` API.
     *
     * Key Features:
     * - Customizable blur radius without predefined blur styles
     * - Optional color tint overlay with adjustable alpha
     * - Scale factor control for effect intensity
     * - Seamless integration with UIVisualEffectView hierarchy
     *
     * - Warning: This implementation uses private APIs and may break in future iOS versions.
     */
    @objcMembers
    open class VisualEffectUIView: UIVisualEffectView {
        // MARK: - Logging

        /**
         * Logger instance for VisualEffect-related operations.
         */
        private let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: String(describing: VisualEffectUIView.self)
        )

        // MARK: - Private Properties

        // swiftlint:disable force_cast
        /// The underlying blur effect instance.
        private let blurEffect = (NSClassFromString(PrivateAPIKeys.customBlurEffectClass) as! UIBlurEffect.Type).init()
        // swiftlint:enable force_cast

        // MARK: - Public Properties

        /// The tint color applied over the blur.
        ///
        /// The default value is `nil`.
        open var colorTint: UIColor? {
            get {
                sourceOver?.value(forKeyPath: PrivateAPIKeys.color) as? UIColor
            }
            set {
                prepareForChanges()
                sourceOver?.setValue(newValue, forKeyPath: PrivateAPIKeys.color)
                sourceOver?.perform(Selector(PrivateAPIKeys.applyRequestedEffectToView), with: overlayView)
                applyChanges()
                overlayView?.backgroundColor = newValue
            }
        }

        /// The alpha value for the tint color.
        ///
        /// Only has an effect when `colorTint` is not `nil`.
        /// The default value is `0.0`.
        open var colorTintAlpha: CGFloat {
            get { value(forKey: .colorTintAlpha) ?? 0.0 }
            set { colorTint = colorTint?.withAlphaComponent(newValue) }
        }

        /// The blur radius.
        ///
        /// The default value is `0.0`.
        open var blurRadius: CGFloat {
            get {
                gaussianBlur?.requestedValues?[PrivateAPIKeys.inputRadius] as? CGFloat ?? 0
            }
            set {
                prepareForChanges()
                gaussianBlur?.requestedValues?[PrivateAPIKeys.inputRadius] = newValue
                applyChanges()
            }
        }

        /// The scale factor for the effect.
        ///
        /// Determines how content is mapped from logical coordinates (points)
        /// to device coordinates (pixels).
        /// The default value is `1.0`.
        open var scale: CGFloat {
            get { value(forKey: .scale) ?? 1.0 }
            set { setValue(newValue, forKey: .scale) }
        }

        // MARK: - Initialization

        /**
         * Creates a new visual effect view with default configuration.
         *
         * - Parameter effect: The visual effect to apply (default: nil)
         */
        public override init(effect: UIVisualEffect?) {
            super.init(effect: effect)
            scale = 1
        }

        /**
         * Creates a visual effect view with customizable blur properties.
         *
         * - Parameters:
         *   - colorTint: Optional tint color applied over the blur. Default is `nil`.
         *   - colorTintAlpha: Alpha value for the tint color. Default is `0`.
         *   - blurRadius: The blur radius. Default is `0`.
         *   - scale: Scale factor for the effect. Default is `1`.
         */
        public init(
            colorTint: UIColor? = nil,
            colorTintAlpha: CGFloat = 0,
            blurRadius: CGFloat = 0,
            scale: CGFloat = 1
        ) {
            super.init(effect: nil)
            self.scale = scale
            self.blurRadius = blurRadius
            if let colorTint {
                self.colorTint = colorTint.withAlphaComponent(colorTintAlpha)
            }
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Configuration Updates

        /**
         * Updates the visual effect configuration.
         *
         * This method compares the new configuration against the current one and only
         * applies changes if actual differences are detected.
         *
         * - Parameters:
         *   - colorTint: Optional tint color applied over the blur
         *   - colorTintAlpha: Alpha value for the tint color
         *   - blurRadius: The blur radius
         *   - scale: Scale factor for the effect
         */
        public func updateConfiguration(
            colorTint: UIColor?,
            colorTintAlpha: CGFloat,
            blurRadius: CGFloat,
            scale: CGFloat
        ) {
            if self.blurRadius != blurRadius {
                self.blurRadius = blurRadius
            }
            if self.scale != scale {
                self.scale = scale
            }
            if let colorTint {
                self.colorTint = colorTint.withAlphaComponent(colorTintAlpha)
            } else if self.colorTint != nil {
                self.colorTint = nil
            }
        }
    }

    // MARK: - Private Helpers

    private extension VisualEffectUIView {
        enum Key: String {
            case colorTint, colorTintAlpha, blurRadius, scale
        }

        func value<T>(forKey key: Key) -> T? {
            blurEffect.value(forKeyPath: key.rawValue) as? T
        }

        func setValue(_ value: (some Any)?, forKey key: Key) {
            blurEffect.setValue(value, forKeyPath: key.rawValue)
        }
    }

    // MARK: - UIVisualEffectView Extensions

    private extension UIVisualEffectView {
        var backdropView: UIView? {
            subview(of: NSClassFromString(PrivateAPIKeys.backdropViewClass))
        }

        var overlayView: UIView? {
            subview(of: NSClassFromString(PrivateAPIKeys.overlaySubviewClass))
        }

        var gaussianBlur: NSObject? {
            backdropView?.value(forKey: PrivateAPIKeys.filters, withFilterType: PrivateAPIKeys.gaussianBlur)
        }

        var sourceOver: NSObject? {
            overlayView?.value(forKey: PrivateAPIKeys.viewEffects, withFilterType: PrivateAPIKeys.sourceOver)
        }

        func prepareForChanges() {
            effect = UIBlurEffect(style: .light)
            gaussianBlur?.setValue(1.0, forKeyPath: PrivateAPIKeys.requestedScaleHint)
        }

        func applyChanges() {
            backdropView?.perform(Selector(PrivateAPIKeys.applyRequestedFilterEffects))
        }
    }

    // MARK: - NSObject Extensions

    private extension NSObject {
        var requestedValues: [String: Any]? {
            get { value(forKeyPath: PrivateAPIKeys.requestedValues) as? [String: Any] }
            set { setValue(newValue, forKeyPath: PrivateAPIKeys.requestedValues) }
        }

        func value(forKey key: String, withFilterType filterType: String) -> NSObject? {
            guard let objects = value(forKeyPath: key) as? [NSObject] else {
                return nil
            }
            return objects.first { $0.value(forKeyPath: PrivateAPIKeys.filterType) as? String == filterType }
        }
    }

    // MARK: - UIView Extensions

    private extension UIView {
        func subview(of classType: AnyClass?) -> UIView? {
            subviews.first { type(of: $0) == classType }
        }
    }
#endif
