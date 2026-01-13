//
//  _InternedKeys.swift
//  AemiSDR
//

#if os(iOS)
    import InternedStrings

    /// Centralized storage for interned string keys used across the framework.
    ///
    /// This enum uses the InternedStrings framework to efficiently manage string keys
    /// for runtime operations. By centralizing these keys, we:
    /// - Reduce string duplication across the codebase
    /// - Provide compile-time safety for key references
    /// - Enable efficient string comparison via pointer equality
    package enum _InternedKeys {
        // MARK: - Filter Keys

        @Interned static var caFilterClass = "CAFilter"
        @Interned static var filterWithType = "filterWithType:"
        @Interned static var variableBlur = "variableBlur"
        @Interned static var gaussianBlur = "gaussianBlur"
        @Interned static var sourceOver = "sourceOver"

        // MARK: - Input Keys

        @Interned static var inputRadius = "inputRadius"
        @Interned static var inputNormalizeEdges = "inputNormalizeEdges"
        @Interned static var inputMaskImage = "inputMaskImage"

        // MARK: - Effect View Classes

        @Interned static var customBlurEffectClass = "_UICustomBlurEffect"
        @Interned static var backdropViewClass = "_UIVisualEffectBackdropView"
        @Interned static var overlaySubviewClass = "_UIVisualEffectSubview"

        // MARK: - Key Paths

        @Interned static var filters = "filters"
        @Interned static var viewEffects = "viewEffects"
        @Interned static var filterType = "filterType"
        @Interned static var requestedValues = "requestedValues"
        @Interned static var requestedScaleHint = "requestedScaleHint"
        @Interned static var color = "color"
        @Interned static var scale = "scale"
        @Interned static var colorTint = "colorTint"
        @Interned static var colorTintAlpha = "colorTintAlpha"
        @Interned static var blurRadius = "blurRadius"

        // MARK: - Selectors

        @Interned static var applyRequestedEffectToView = "applyRequestedEffectToView:"
        @Interned static var applyRequestedFilterEffects = "applyRequestedFilterEffects"
    }
#endif
