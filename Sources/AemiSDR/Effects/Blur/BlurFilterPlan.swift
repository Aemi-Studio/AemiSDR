import Foundation

/// The filters a recipe asks for, in order: the blur (none when its radius blurs nothing), then saturation and brightness when they
/// change anything. Pure: no private API is touched here (ADR-0009).
enum BlurFilterPlan {
    static func filters(for recipe: BlurRecipe) -> [BlurFilterSpec] {
        guard recipe.radius.isFinite, recipe.radius > 0 else { return [] }
        var filters: [BlurFilterSpec] = []
        let radius = BlurFilterSpec.Value.number(_InternedKeys.radiusParam, recipe.radius)
        let edges = BlurFilterSpec.Value.flag(_InternedKeys.normalizeParam, recipe.normalizesEdges)
        switch recipe.shape {
        case .uniform:
            filters.append(BlurFilterSpec(type: _InternedKeys.blurFilterID, values: [radius, edges]))
        case .variable(let mask):
            filters.append(
                BlurFilterSpec(
                    type: _InternedKeys.maskedBlurFilterID,
                    values: [radius, edges, .mask(_InternedKeys.maskParam, mask)]
                )
            )
        }
        if recipe.saturation.isFinite, recipe.saturation != 1 {
            filters.append(
                BlurFilterSpec(
                    type: _InternedKeys.saturateFilterID,
                    values: [.number(_InternedKeys.amountParam, recipe.saturation)]
                )
            )
        }
        if recipe.brightness.isFinite, recipe.brightness != 0 {
            filters.append(
                BlurFilterSpec(
                    type: _InternedKeys.brightnessFilterID,
                    values: [.number(_InternedKeys.amountParam, recipe.brightness)]
                )
            )
        }
        return filters
    }
}
