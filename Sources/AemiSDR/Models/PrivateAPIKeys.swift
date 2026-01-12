//
//  PrivateAPIKeys.swift
//  AemiSDR
//
// Created by Guillaume Coquard on 20.09.25.
//

#if os(iOS)
    import InternedStrings

    // MARK: - Private API Keys

    /**
     * Centralized storage for private API string keys used across the framework.
     *
     * This enum uses the InternedStrings framework to efficiently manage string keys
     * that reference private Apple APIs. By centralizing these keys, we:
     * - Reduce string duplication across the codebase
     * - Make it easier to update if Apple renames internal classes
     * - Provide compile-time safety for key references
     *
     * - Warning: These keys reference private APIs and may break in future iOS versions.
     */
    @InternedStrings
    package enum PrivateAPIKeys {
        // MARK: - Core Animation Filter Keys

        /// Class name for Core Animation filters
        @Interned("CAFilter")
        static var caFilterClass: String

        /// Method selector to create filters by type
        @Interned("filterWithType:")
        static var filterWithType: String

        /// Variable blur filter type identifier
        @Interned("variableBlur")
        static var variableBlur: String

        /// Gaussian blur filter type identifier
        @Interned("gaussianBlur")
        static var gaussianBlur: String

        /// Source-over compositing filter type identifier
        @Interned("sourceOver")
        static var sourceOver: String

        // MARK: - Filter Input Keys

        /// Input radius key for blur filters
        @Interned("inputRadius")
        static var inputRadius: String

        /// Input key to normalize edges in variable blur
        @Interned("inputNormalizeEdges")
        static var inputNormalizeEdges: String

        /// Input key for mask image in variable blur
        @Interned("inputMaskImage")
        static var inputMaskImage: String

        // MARK: - UIVisualEffectView Internal Classes

        /// Private class name for custom blur effect
        @Interned("_UICustomBlurEffect")
        static var customBlurEffectClass: String

        /// Private class name for backdrop view
        @Interned("_UIVisualEffectBackdropView")
        static var backdropViewClass: String

        /// Private class name for overlay subview
        @Interned("_UIVisualEffectSubview")
        static var overlaySubviewClass: String

        // MARK: - Key Paths

        /// Key path to access filters array
        @Interned("filters")
        static var filters: String

        /// Key path to access view effects array
        @Interned("viewEffects")
        static var viewEffects: String

        /// Key path to access filter type identifier
        @Interned("filterType")
        static var filterType: String

        /// Key path to access requested values dictionary
        @Interned("requestedValues")
        static var requestedValues: String

        /// Key path to access scale hint
        @Interned("requestedScaleHint")
        static var requestedScaleHint: String

        /// Key path to access color value
        @Interned("color")
        static var color: String

        /// Key path for scale property
        @Interned("scale")
        static var scale: String

        /// Key path for color tint property
        @Interned("colorTint")
        static var colorTint: String

        /// Key path for color tint alpha property
        @Interned("colorTintAlpha")
        static var colorTintAlpha: String

        /// Key path for blur radius property
        @Interned("blurRadius")
        static var blurRadius: String

        // MARK: - Selector Names

        /// Selector to apply requested effect to a view
        @Interned("applyRequestedEffectToView:")
        static var applyRequestedEffectToView: String

        /// Selector to apply requested filter effects
        @Interned("applyRequestedFilterEffects")
        static var applyRequestedFilterEffects: String
    }
#endif
