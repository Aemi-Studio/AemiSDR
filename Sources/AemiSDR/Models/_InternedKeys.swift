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
@InternedStrings
package enum _InternedKeys {
  // MARK: - Filter Keys

  @Interned("CAFilter")
  static var caFilterClass: String

  @Interned("filterWithType:")
  static var filterWithType: String

  @Interned("variableBlur")
  static var variableBlur: String

  @Interned("gaussianBlur")
  static var gaussianBlur: String

  @Interned("sourceOver")
  static var sourceOver: String

  // MARK: - Input Keys

  @Interned("inputRadius")
  static var inputRadius: String

  @Interned("inputNormalizeEdges")
  static var inputNormalizeEdges: String

  @Interned("inputMaskImage")
  static var inputMaskImage: String

  // MARK: - Effect View Classes

  @Interned("_UICustomBlurEffect")
  static var customBlurEffectClass: String

  @Interned("_UIVisualEffectBackdropView")
  static var backdropViewClass: String

  @Interned("_UIVisualEffectSubview")
  static var overlaySubviewClass: String

  // MARK: - Key Paths

  @Interned("filters")
  static var filters: String

  @Interned("viewEffects")
  static var viewEffects: String

  @Interned("filterType")
  static var filterType: String

  @Interned("requestedValues")
  static var requestedValues: String

  @Interned("requestedScaleHint")
  static var requestedScaleHint: String

  @Interned("color")
  static var color: String

  @Interned("scale")
  static var scale: String

  @Interned("colorTint")
  static var colorTint: String

  @Interned("colorTintAlpha")
  static var colorTintAlpha: String

  @Interned("blurRadius")
  static var blurRadius: String

  // MARK: - Selectors

  @Interned("applyRequestedEffectToView:")
  static var applyRequestedEffectToView: String

  @Interned("applyRequestedFilterEffects")
  static var applyRequestedFilterEffects: String
}
#endif
