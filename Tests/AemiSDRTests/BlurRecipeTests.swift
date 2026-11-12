import CoreGraphics
import Testing

@testable import AemiSDR

/// Roadmap 0020 slice 1: what a blur is, as values, and the filters it asks for, without touching private API.
@Suite("Blur recipe and plan") struct BlurRecipeTests {
    @Test func `an edge mask is the solid part's fraction of the layer, clamped`() {
        #expect(BlurMask.edge(.top, solid: 38, fade: 38).solidFraction == 0.5)
        #expect(BlurMask.edge(.bottom, solid: 0, fade: 24).solidFraction == 0)
        #expect(BlurMask.edge(.top, solid: 10, fade: 0).solidFraction == 1)
        #expect(BlurMask.edge(.top, solid: -5, fade: -5).solidFraction == 1)
    }

    @Test func `a uniform recipe plans a gaussian blur and no colour filter`() {
        let plan = BlurFilterPlan.filters(for: .uniform(radius: 20))
        #expect(plan.map(\.type) == ["gaussianBlur"])
        #expect(plan.first?.values.contains(.number("inputRadius", 20)) == true)
    }

    @Test func `a variable recipe plans a masked blur carrying its mask and normalised edges`() {
        let mask = BlurMask.edge(.top, solid: 38, fade: 38)
        let plan = BlurFilterPlan.filters(for: .variable(radius: 24, mask: mask))
        #expect(plan.map(\.type) == ["variableBlur"])
        let values = plan.first?.values ?? []
        #expect(values.contains(.number("inputRadius", 24)) && values.contains(.mask("inputMaskImage", mask)))
        #expect(values.contains(.flag("inputNormalizeEdges", true)))
    }

    @Test func `saturation and brightness follow the blur, in that order, only when they change something`() {
        var recipe = BlurRecipe.uniform(radius: 12)
        recipe.saturation = 1.8
        recipe.brightness = -0.08
        #expect(
            BlurFilterPlan.filters(for: recipe).map(\.type) == ["gaussianBlur", "colorSaturate", "colorBrightness"])
        recipe.saturation = 1
        #expect(BlurFilterPlan.filters(for: recipe).map(\.type) == ["gaussianBlur", "colorBrightness"])
    }

    @Test func `a radius of zero or less, or not finite, plans no blur`() {
        #expect(BlurFilterPlan.filters(for: .uniform(radius: 0)).isEmpty)
        #expect(BlurFilterPlan.filters(for: .uniform(radius: .nan)).isEmpty)
        #expect(BlurFilterPlan.filters(for: .variable(radius: -1, mask: .edge(.top, solid: 1, fade: 1))).isEmpty)
    }
}
