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
    // MARK: - Filter Identifiers

    @Interned static var caLayerFilterClass = "CAFilter"
    @Interned static var filterCreationSelector = "filterWithType:"
    @Interned static var blurFilterID = "gaussianBlur"
    @Interned static var compositeFilterID = "sourceOver"
    @Interned static var saturateFilterID = "colorSaturate"
    @Interned static var brightnessFilterID = "colorBrightness"

    // MARK: - Filter Parameters

    @Interned static var radiusParam = "inputRadius"
    @Interned static var normalizeParam = "inputNormalizeEdges"
    @Interned static var maskParam = "inputMaskImage"
    @Interned static var amountParam = "inputAmount"

    // MARK: - Key Paths

    @Interned static var filterListKey = "filters"
    @Interned static var kindKey = "filterType"
    @Interned static var kindFallbackA = "type"
    @Interned static var kindFallbackB = "name"
    @Interned static var scaleFactorKey = "scale"
    @Interned static var tintColorKey = "colorTint"
    @Interned static var tintAlphaKey = "colorTintAlpha"
    @Interned static var radiusValueKey = "blurRadius"
    @Interned static var saturationKey = "saturationDeltaFactor"
    @Interned static var grayLevelKey = "grayscaleTintLevel"
    @Interned static var grayAlphaKey = "grayscaleTintAlpha"
    @Interned static var burnLevelKey = "colorBurnTintLevel"
    @Interned static var burnAlphaKey = "colorBurnTintAlpha"
    @Interned static var darkAlphaKey = "darkeningTintAlpha"
    @Interned static var darkHueKey = "darkeningTintHue"
    @Interned static var darkSatKey = "darkeningTintSaturation"
    @Interned static var zoomKey = "zoom"
    @Interned static var lightenGrayFlag = "lightenGrayscaleWithSourceOver"
    @Interned static var darkenCompFlag = "darkenWithSourceOver"

    // MARK: - iOS-Only Keys

    #if os(iOS)
        @Interned static var maskedBlurFilterID = "variableBlur"

        // Effect View Classes
        @Interned static var customBlurEffectClass = "_UICustomBlurEffect"
        @Interned static var backdropViewClass = "_UIVisualEffectBackdropView"
        @Interned static var overlaySubviewClass = "_UIVisualEffectSubview"

        // Key Paths
        @Interned static var effectsListKey = "viewEffects"
        @Interned static var pendingValuesKey = "requestedValues"
        @Interned static var scaleHintKey = "requestedScaleHint"
        @Interned static var colorKey = "color"

        // Backdrop Settings
        @Interned static var backdropViewSettingsClass = "_UIBackdropViewSettings"
        @Interned static var settingsCreationSelector = "settingsForStyle:"
        @Interned static var grayTintEnabledKey = "usesGrayscaleTintView"
        @Interned static var tintEnabledKey = "usesColorTintView"
        @Interned static var burnTintEnabledKey = "usesColorBurnTintView"

        // Selectors
        @Interned static var applyEffectSelector = "applyRequestedEffectToView:"
        @Interned static var commitFiltersSelector = "applyRequestedFilterEffects"

        // Private UIKit Properties
        @Interned static var screenCornerRadiusKey = "_displayCornerRadius"

        // CABackdropLayer (private API — capture composited content behind a view)
        @Interned static var backdropLayerClass = "CABackdropLayer"
        @Interned static var backdropGroupNameKey = "groupName"

        // Legacy keys (removed in iOS 26)
        @Interned static var coreImageFiltersKey = "layerUsesCoreImageFilters"
        @Interned static var windowServerAwareKey = "windowServerAware"

        // iOS 26+ CABackdropLayer keys
        @Interned static var backdropEnabledKey = "enabled"
        @Interned static var backdropCaptureOnlyKey = "captureOnly"
        @Interned static var backdropDisablesOccludedKey = "disablesOccludedBackdropBlurs"
        @Interned static var backdropReducesBitDepthKey = "reducesCaptureBitDepth"
        @Interned static var backdropAllowsInPlaceKey = "allowsInPlaceFiltering"
        @Interned static var backdropRectKey = "backdropRect"
        @Interned static var backdropUpdateRateKey = "updateRate"
    #endif

    // MARK: - macOS-Only Keys

    #if os(macOS)
        @Interned static var backdropLayerRef = "_backdropLayer"
        @Interned static var backdropLayerClassName = "CABackdropLayer"
    #endif
}
