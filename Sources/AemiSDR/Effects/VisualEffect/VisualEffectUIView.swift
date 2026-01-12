//
//  VisualEffectUIView.swift
//  AemiSDR
//
//  Based on VisualEffectView by Lasha Efremidze.
//  SwiftUI integration by 朱浩宇.
//

#if os(iOS)
    import OSLog
    import UIKit

    /// A dynamic background blur view with customizable blur radius, tint color, and scale.
    ///
    /// This class provides fine-grained control over visual effect properties
    /// beyond what the standard `UIBlurEffect` API exposes.
    ///
    /// ## Features
    /// - Customizable blur radius without predefined blur styles
    /// - Optional color tint overlay with adjustable alpha
    /// - Scale factor control for effect intensity
    /// - Seamless integration with UIVisualEffectView hierarchy
    @objcMembers
    open class VisualEffectUIView: UIVisualEffectView {
        // MARK: - Private Properties

        private let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: String(describing: VisualEffectUIView.self)
        )

        private let blurEffect: UIBlurEffect? = {
            guard let effectClass = NSClassFromString(_InternedKeys.customBlurEffectClass) as? UIBlurEffect.Type else {
                return nil
            }
            return effectClass.init()
        }()

        // MARK: - Public Properties

        /// The tint color applied over the blur.
        ///
        /// The default value is `nil`.
        open var colorTint: UIColor? {
            get {
                sourceOver?.value(forKeyPath: _InternedKeys.color) as? UIColor
            }
            set {
                prepareForChanges()
                sourceOver?.setValue(newValue, forKeyPath: _InternedKeys.color)
                sourceOver?.perform(Selector(_InternedKeys.applyRequestedEffectToView), with: overlayView)
                applyChanges()
                overlayView?.backgroundColor = newValue
            }
        }

        /// The alpha value for the tint color.
        ///
        /// Only has an effect when `colorTint` is not `nil`.
        /// The default value is `0.0`.
        open var colorTintAlpha: CGFloat {
            get { blurEffectValue(forKey: .colorTintAlpha) ?? 0.0 }
            set { colorTint = colorTint?.withAlphaComponent(newValue) }
        }

        /// The blur radius in points.
        ///
        /// The default value is `0.0`.
        open var blurRadius: CGFloat {
            get {
                gaussianBlur?.requestedValues?[_InternedKeys.inputRadius] as? CGFloat ?? 0
            }
            set {
                prepareForChanges()
                gaussianBlur?.requestedValues?[_InternedKeys.inputRadius] = newValue
                applyChanges()
            }
        }

        /// The scale factor for the effect.
        ///
        /// Determines how content is mapped from logical coordinates (points)
        /// to device coordinates (pixels).
        /// The default value is `1.0`.
        open var scale: CGFloat {
            get { blurEffectValue(forKey: .scale) ?? 1.0 }
            set { setBlurEffectValue(newValue, forKey: .scale) }
        }

        // MARK: - Initialization

        /// Creates a new visual effect view with default configuration.
        ///
        /// - Parameter effect: The visual effect to apply.
        public override init(effect: UIVisualEffect?) {
            super.init(effect: effect)
            scale = 1
        }

        /// Creates a visual effect view with customizable blur properties.
        ///
        /// - Parameters:
        ///   - colorTint: Optional tint color applied over the blur.
        ///   - colorTintAlpha: Alpha value for the tint color.
        ///   - blurRadius: The blur radius in points.
        ///   - scale: Scale factor for the effect.
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

        // MARK: - Configuration

        /// Updates the visual effect configuration.
        ///
        /// This method compares the new configuration against the current one
        /// and only applies changes if actual differences are detected.
        ///
        /// - Parameters:
        ///   - colorTint: Optional tint color applied over the blur.
        ///   - colorTintAlpha: Alpha value for the tint color.
        ///   - blurRadius: The blur radius in points.
        ///   - scale: Scale factor for the effect.
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

    // MARK: - Blur Effect Value Access

    extension VisualEffectUIView {
        fileprivate enum BlurEffectKey: String {
            case colorTint
            case colorTintAlpha
            case blurRadius
            case scale
        }

        fileprivate func blurEffectValue<T>(forKey key: BlurEffectKey) -> T? {
            blurEffect?.value(forKeyPath: key.rawValue) as? T
        }

        fileprivate func setBlurEffectValue(_ value: (some Any)?, forKey key: BlurEffectKey) {
            blurEffect?.setValue(value, forKeyPath: key.rawValue)
        }
    }
#endif
