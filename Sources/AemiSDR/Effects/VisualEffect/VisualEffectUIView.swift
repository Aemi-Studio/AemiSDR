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
    /// - Saturation and scale factor control
    /// - Seamless integration with UIVisualEffectView hierarchy
    @objcMembers
    open class VisualEffectUIView: UIVisualEffectView {
        // MARK: - Private Properties

        private let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: String(describing: VisualEffectUIView.self)
        )

        /// The `_UICustomBlurEffect` instance used to store KVC property values.
        /// Properties like grayscale/darkening are set here; blur and saturation
        /// are overridden via direct filter manipulation for reliability.
        private let blurEffect: UIBlurEffect? = {
            guard let effectClass = NSClassFromString(_InternedKeys.customBlurEffectClass) as? UIBlurEffect.Type else {
                return nil
            }
            return effectClass.init()
        }()

        /// Last configuration applied via `applyConfiguration(_:)`.
        /// Used to short-circuit no-op repeated calls from `updateUIView` cascades.
        private var lastConfiguration: BackdropBlurConfiguration?

        // MARK: - Public Properties

        /// The tint color applied over the blur.
        ///
        /// The default value is `nil`.
        open var colorTint: UIColor? {
            get {
                sourceOver?.value(forKeyPath: _InternedKeys.colorKey) as? UIColor
            }
            set {
                lastConfiguration = nil
                prepareForChanges()
                sourceOver?.setValue(newValue, forKeyPath: _InternedKeys.colorKey)
                _ = unsafe sourceOver?.perform(Selector(_InternedKeys.applyEffectSelector), with: overlayView)
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
                gaussianBlur?.requestedValues?[_InternedKeys.radiusParam] as? CGFloat ?? 0
            }
            set {
                lastConfiguration = nil
                prepareForChanges()
                gaussianBlur?.requestedValues?[_InternedKeys.radiusParam] = newValue
                applyChanges()
            }
        }

        /// The scale factor for the effect.
        ///
        /// The default value is `1.0`.
        open var scale: CGFloat {
            get { blurEffectValue(forKey: .scale) ?? 1.0 }
            set { setBlurEffectValue(newValue, forKey: .scale) }
        }

        /// Multiplier for the saturation of the backdrop content.
        ///
        /// Values above 1.0 increase saturation, below 1.0 decrease it.
        /// The default value is `1.0`.
        open var saturationDeltaFactor: CGFloat {
            get {
                colorSaturate?.requestedValues?[_InternedKeys.amountParam] as? CGFloat
                    ?? blurEffectValue(forKey: .saturationDeltaFactor) ?? 1.0
            }
            set {
                lastConfiguration = nil
                blurEffect?.setValue(newValue, forKeyPath: BlurEffectKey.saturationDeltaFactor.rawValue)
                prepareForChanges()
                colorSaturate?.requestedValues?[_InternedKeys.amountParam] = newValue
                applyChanges()
            }
        }

        /// Intensity of the grayscale tint layer.
        /// The default value is `0.0`.
        open var grayscaleTintLevel: CGFloat {
            get { blurEffectValue(forKey: .grayscaleTintLevel) ?? 0.0 }
            set { setBlurEffectValue(newValue, forKey: .grayscaleTintLevel) }
        }

        /// Alpha of the grayscale tint layer.
        /// The default value is `0.0`.
        open var grayscaleTintAlpha: CGFloat {
            get { blurEffectValue(forKey: .grayscaleTintAlpha) ?? 0.0 }
            set { setBlurEffectValue(newValue, forKey: .grayscaleTintAlpha) }
        }

        /// Intensity of the color burn tint layer.
        /// The default value is `0.0`.
        open var colorBurnTintLevel: CGFloat {
            get { blurEffectValue(forKey: .colorBurnTintLevel) ?? 0.0 }
            set { setBlurEffectValue(newValue, forKey: .colorBurnTintLevel) }
        }

        /// Alpha of the color burn tint layer.
        /// The default value is `0.0`.
        open var colorBurnTintAlpha: CGFloat {
            get { blurEffectValue(forKey: .colorBurnTintAlpha) ?? 0.0 }
            set { setBlurEffectValue(newValue, forKey: .colorBurnTintAlpha) }
        }

        /// Alpha of the darkening tint.
        /// The default value is `0.0`.
        open var darkeningTintAlpha: CGFloat {
            get { blurEffectValue(forKey: .darkeningTintAlpha) ?? 0.0 }
            set { setBlurEffectValue(newValue, forKey: .darkeningTintAlpha) }
        }

        /// Hue of the darkening tint.
        /// The default value is `0.0`.
        open var darkeningTintHue: CGFloat {
            get { blurEffectValue(forKey: .darkeningTintHue) ?? 0.0 }
            set { setBlurEffectValue(newValue, forKey: .darkeningTintHue) }
        }

        /// Saturation of the darkening tint.
        /// The default value is `0.0`.
        open var darkeningTintSaturation: CGFloat {
            get { blurEffectValue(forKey: .darkeningTintSaturation) ?? 0.0 }
            set { setBlurEffectValue(newValue, forKey: .darkeningTintSaturation) }
        }

        /// Zoom level applied to the backdrop.
        /// The default value is `0.0`.
        open var zoom: CGFloat {
            get { blurEffectValue(forKey: .zoom) ?? 0.0 }
            set { setBlurEffectValue(newValue, forKey: .zoom) }
        }

        /// Whether to lighten using grayscale with source-over compositing.
        /// The default value is `false`.
        open var lightenGrayscaleWithSourceOver: Bool {
            get { blurEffectValue(forKey: .lightenGrayscaleWithSourceOver) ?? false }
            set { setBlurEffectValue(newValue, forKey: .lightenGrayscaleWithSourceOver) }
        }

        /// Whether to darken using source-over compositing.
        /// The default value is `false`.
        open var darkenWithSourceOver: Bool {
            get { blurEffectValue(forKey: .darkenWithSourceOver) ?? false }
            set { setBlurEffectValue(newValue, forKey: .darkenWithSourceOver) }
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

        /// Creates a visual effect view from a full configuration.
        ///
        /// - Parameter configuration: The configuration specifying all effect properties.
        public convenience init(configuration: BackdropBlurConfiguration) {
            self.init(effect: nil)
            applyConfiguration(configuration)
        }

        /// Updates the visual effect with a full configuration.
        ///
        /// This method applies all configuration properties in a single batch
        /// with one `prepareForChanges` / `applyChanges` cycle.
        ///
        /// - Parameter configuration: The configuration specifying all effect properties.
        public func updateConfiguration(_ configuration: BackdropBlurConfiguration) {
            applyConfiguration(configuration)
        }

        // MARK: - Private Helpers

        private func applyConfiguration(_ configuration: BackdropBlurConfiguration) {
            // Short-circuit when nothing changed. SwiftUI state cascades call
            // `updateUIView` on every transient ancestor change; without this
            // guard every cascade ran a full prepare/apply cycle.
            if lastConfiguration == configuration { return }
            lastConfiguration = configuration

            // Use prepareForChanges() to create the system backdrop hierarchy.
            // UIBlurEffect(style: .light) properly initializes the gaussianBlur
            // and colorSaturate filters with writable requestedValues dicts.
            prepareForChanges()

            // Override blur and saturation via direct filter manipulation
            gaussianBlur?.requestedValues?[_InternedKeys.radiusParam] = configuration.blurRadius
            colorSaturate?.requestedValues?[_InternedKeys.amountParam] = configuration.saturationDeltaFactor

            // Resolve effective tint once so we set it on both the sourceOver
            // filter and the overlay's backgroundColor below.
            let resolvedTint: UIColor?
            if let tint = configuration.colorTint {
                resolvedTint = UIColor(tint).withAlphaComponent(configuration.colorTintAlpha)
            } else {
                resolvedTint = nil
            }
            sourceOver?.setValue(resolvedTint, forKeyPath: _InternedKeys.colorKey)
            _ = unsafe sourceOver?.perform(Selector(_InternedKeys.applyEffectSelector), with: overlayView)

            applyChanges()

            // Set `backgroundColor` AFTER `applyChanges()` to match the public
            // `colorTint` property setter's ordering — without this, a
            // configuration that flips tint state between renders could leave
            // a one-frame stale tint while the private effect-tree flush
            // races the layer-side backgroundColor change.
            overlayView?.backgroundColor = resolvedTint
        }
    }

    // MARK: - Blur Effect Value Access

    extension VisualEffectUIView {
        fileprivate enum BlurEffectKey: String {
            case colorTint
            case colorTintAlpha
            case blurRadius
            case scale
            case saturationDeltaFactor
            case grayscaleTintLevel
            case grayscaleTintAlpha
            case colorBurnTintLevel
            case colorBurnTintAlpha
            case darkeningTintAlpha
            case darkeningTintHue
            case darkeningTintSaturation
            case zoom
            case lightenGrayscaleWithSourceOver
            case darkenWithSourceOver
        }

        fileprivate func blurEffectValue<T>(forKey key: BlurEffectKey) -> T? {
            blurEffect?.value(forKeyPath: key.rawValue) as? T
        }

        /// Sets a KVC value on the `_UICustomBlurEffect` and rebuilds.
        fileprivate func setBlurEffectValue(_ value: (some Any)?, forKey key: BlurEffectKey) {
            lastConfiguration = nil
            blurEffect?.setValue(value, forKeyPath: key.rawValue)
            prepareForChanges()
            applyChanges()
        }
    }
#endif
