//
//  _InternedKeys.swift
//  AemiSDR
//

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
    @Interned static var gaussianBlur = "gaussianBlur"
    @Interned static var sourceOver = "sourceOver"
    @Interned static var colorSaturate = "colorSaturate"
    @Interned static var colorBrightness = "colorBrightness"

    // MARK: - Input Keys

    @Interned static var inputRadius = "inputRadius"
    @Interned static var inputNormalizeEdges = "inputNormalizeEdges"
    @Interned static var inputMaskImage = "inputMaskImage"
    @Interned static var inputAmount = "inputAmount"

    // MARK: - Key Paths

    @Interned static var filters = "filters"
    @Interned static var filterType = "filterType"
    @Interned static var scale = "scale"
    @Interned static var colorTint = "colorTint"
    @Interned static var colorTintAlpha = "colorTintAlpha"
    @Interned static var blurRadius = "blurRadius"
    @Interned static var saturationDeltaFactor = "saturationDeltaFactor"
    @Interned static var grayscaleTintLevel = "grayscaleTintLevel"
    @Interned static var grayscaleTintAlpha = "grayscaleTintAlpha"
    @Interned static var colorBurnTintLevel = "colorBurnTintLevel"
    @Interned static var colorBurnTintAlpha = "colorBurnTintAlpha"
    @Interned static var darkeningTintAlpha = "darkeningTintAlpha"
    @Interned static var darkeningTintHue = "darkeningTintHue"
    @Interned static var darkeningTintSaturation = "darkeningTintSaturation"
    @Interned static var zoom = "zoom"
    @Interned static var lightenGrayscaleWithSourceOver = "lightenGrayscaleWithSourceOver"
    @Interned static var darkenWithSourceOver = "darkenWithSourceOver"

    // MARK: - iOS-Only Keys

    #if os(iOS)
        @Interned static var variableBlur = "variableBlur"

        // Effect View Classes
        @Interned static var customBlurEffectClass = "_UICustomBlurEffect"
        @Interned static var backdropViewClass = "_UIVisualEffectBackdropView"
        @Interned static var overlaySubviewClass = "_UIVisualEffectSubview"

        // Key Paths
        @Interned static var viewEffects = "viewEffects"
        @Interned static var requestedValues = "requestedValues"
        @Interned static var requestedScaleHint = "requestedScaleHint"
        @Interned static var color = "color"

        // Backdrop Settings
        @Interned static var backdropViewSettingsClass = "_UIBackdropViewSettings"
        @Interned static var settingsForStyle = "settingsForStyle:"
        @Interned static var usesGrayscaleTintView = "usesGrayscaleTintView"
        @Interned static var usesColorTintView = "usesColorTintView"
        @Interned static var usesColorBurnTintView = "usesColorBurnTintView"

        // Selectors
        @Interned static var applyRequestedEffectToView = "applyRequestedEffectToView:"
        @Interned static var applyRequestedFilterEffects = "applyRequestedFilterEffects"
    #endif

    // MARK: - macOS-Only Keys

    #if os(macOS)
        @Interned static var _backdropLayer = "_backdropLayer"
        @Interned static var backgroundFilters = "backgroundFilters"
    #endif
}
