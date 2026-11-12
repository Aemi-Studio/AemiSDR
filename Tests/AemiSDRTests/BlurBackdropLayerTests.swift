#if os(macOS)
    import Abysm
    import QuartzCore
    import Testing

    @testable import AemiSDR

    /// Roadmap 0020 slice 2: filters made through Abysm, keys checked against the filter's own list, a backdrop layer that does no
    /// filter work for an unchanged recipe, and nothing private at all when the host turns private API off.
    @MainActor @Suite("Blur backdrop layer", .serialized) struct BlurBackdropLayerTests {
        private let edge = BlurMask.edge(.top, solid: 38, fade: 38)

        @Test func `a planned filter becomes a CAFilter of its type with exactly its inputs set`() throws {
            let spec = try #require(BlurFilterPlan.filters(for: .variable(radius: 24, mask: edge)).first)
            let filter = try #require(BlurFilterFactory.make(spec))
            let object = RuntimeObject(filter)
            #expect((try object.value(forKey: "inputRadius") as? NSNumber)?.doubleValue == 24)
            #expect((try object.value(forKey: "inputNormalizeEdges") as? NSNumber)?.boolValue == true)
            #expect(try object.value(forKey: "inputMaskImage") != nil)
        }

        @Test func `a key the filter does not list is never written`() throws {
            let spec = BlurFilterSpec(
                type: "gaussianBlur", values: [.number("inputNoSuchKey", 3), .number("inputRadius", 5)])
            let filter = try #require(BlurFilterFactory.make(spec))
            #expect(try RuntimeObject(filter).value(forKey: "inputNoSuchKey") == nil)
            #expect((try RuntimeObject(filter).value(forKey: "inputRadius") as? NSNumber)?.doubleValue == 5)
        }

        @Test func `a filter type the system does not have makes nothing`() {
            #expect(BlurFilterFactory.make(BlurFilterSpec(type: "noSuchFilter", values: [])) == nil)
        }

        @Test func `the backdrop layer takes the recipe's filters in order, and its capture scale`() throws {
            let backdrop = try #require(BlurBackdropLayer.make())
            var recipe = BlurRecipe.variable(radius: 24, mask: edge)
            recipe.saturation = 1.8
            recipe.captureScale = 0.5
            #expect(backdrop.apply(recipe))
            let filters = try #require(backdrop.layer.filters as? [NSObject])
            #expect(filters.count == 2)
            #expect((try RuntimeObject(backdrop.layer).value(forKey: "scale") as? NSNumber)?.doubleValue == 0.5)
        }

        @Test func `applying the same recipe twice writes the filters once`() throws {
            let backdrop = try #require(BlurBackdropLayer.make())
            let recipe = BlurRecipe.uniform(radius: 12)
            #expect(backdrop.apply(recipe) && backdrop.apply(recipe))
            #expect(backdrop.filterAssignmentCount == 1)
            #expect(backdrop.apply(.uniform(radius: 14)) && backdrop.filterAssignmentCount == 2)
        }

        @Test func `a variable blur is assigned again for a new size, a plain one is not`() throws {
            let layer = try #require(BlurBackdropLayer.make())
            layer.apply(.variable(radius: 24, mask: edge))
            layer.refit()
            #expect(layer.filterAssignmentCount == 2, "the mask is fitted to the size the layer has when assigned")
            let plain = try #require(BlurBackdropLayer.make())
            plain.apply(.uniform(radius: 8))
            plain.refit()
            #expect(plain.filterAssignmentCount == 1)
        }

        @Test func `with private API off no filter and no backdrop layer is made`() {
            let was = PrivateAPIPolicy.isEnabled
            defer { PrivateAPIPolicy.isEnabled = was }
            PrivateAPIPolicy.isEnabled = false
            #expect(BlurBackdropLayer.make() == nil)
            #expect(BlurFilterFactory.make(BlurFilterSpec(type: "gaussianBlur", values: [])) == nil)
        }

        @Test func `canary: every private name the blur core uses resolves on this macOS`() throws {
            RuntimeAccess.resetResolutions()
            let backdrop = try #require(BlurBackdropLayer.make(), "CABackdropLayer and its setters resolve")
            #expect(backdrop.apply(.variable(radius: 10, mask: edge)))
            #expect(RuntimeAccess.failures.isEmpty, "unresolved: \(RuntimeAccess.failures)")
        }
    }
#endif
