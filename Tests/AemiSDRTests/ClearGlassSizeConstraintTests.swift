import CoreGraphics
import Testing

@testable import AemiSDR

struct ClearGlassSizeConstraintTests {
    private static var shapes: [GlassShape] {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 140, y: 0))
        path.addLine(to: CGPoint(x: 280, y: 40))
        path.addLine(to: CGPoint(x: 0, y: 40))
        path.closeSubpath()
        return [
            .roundedRect(radii: .zero),
            .roundedRect(radii: GlassCornerRadii(topLeading: 8, topTrailing: 59, bottomLeading: 8, bottomTrailing: 59)),
            .capsule, .circle, .path(path),
        ]
    }

    @Test(arguments: ClearGlassSizeConstraintTests.shapes)
    func `every shape caps pull height and channel displacement to half its shorter dimension`(shape: GlassShape) {
        for scale in [CGFloat(1), 2, 3] {
            let config = ClearGlassConfiguration(
                shape: shape, rim: .circularArc(depth: 60, height: 80), chromatic: 0.2)
            let uniforms = config.uniforms(
                size: CGSize(width: 280, height: 40), scale: scale, sourceOrigin: .zero,
                sourceSize: CGSize(width: 1200, height: 1200))
            let halfHeight = Float(20 * scale)
            #expect(uniforms.rimEdgeFalloff <= halfHeight)
            #expect(abs(uniforms.rimEdge) * 1.2 <= halfHeight + 1e-5)
            let t = min(halfHeight / max(uniforms.rimEdgeFalloff, 0.001), 1)
            let centrePull = uniforms.rimEdge * (1 - sqrt(t * (2 - t)))
            #expect(abs(centrePull) < 1e-5, "opposing arc pulls must have vanished before meeting")
        }
    }

    @Test func `a large component retains the measured native clear rim`() {
        let config = ClearGlassConfiguration.nativeClear(shape: .capsule)
        let uniforms = config.uniforms(
            size: CGSize(width: 300, height: 200), scale: 3, sourceOrigin: .zero,
            sourceSize: CGSize(width: 1200, height: 1200))
        #expect(uniforms.rimEdge == 180)
        #expect(uniforms.rimEdgeFalloff == 60)
    }
}
