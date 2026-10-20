//
//  ClearGlassGeometryTests.swift
//  AemiSDRTests
//
//  The parts of clear glass that need no GPU: the Gaussian kernel, the signed distance field of any shape, the pixel
//  radii handed to the shader, and the layout of the uniform block. Roadmap 0019.
//

import CoreGraphics
import Foundation
import Testing
import simd

@testable import AemiSDR

@Suite("Clear glass geometry")
struct ClearGlassGeometryTests {
    // MARK: Gaussian kernel

    @Test(arguments: [Float(0.3), 1, 2.8, 5, 11])
    func `the kernel sums to one, so blurring never changes brightness`(sigma: Float) {
        let kernel = GaussianKernel(sigma: sigma)
        let total = kernel.weights[0] + 2 * kernel.weights.dropFirst().reduce(0, +)
        #expect(abs(total - 1) < 1e-6, "sigma \(sigma): the kernel sums to \(total)")
    }

    @Test func `the kernel falls off monotonically and follows the Gaussian`() {
        let sigma: Float = 2.8
        let kernel = GaussianKernel(sigma: sigma)
        for index in 1..<kernel.weights.count {
            #expect(kernel.weights[index] < kernel.weights[index - 1])
            let expected = exp(-Float(index * index) / (2 * sigma * sigma))
            #expect(abs(kernel.weights[index] / kernel.weights[0] - expected) < 1e-5)
        }
    }

    @Test(arguments: [Float(0.3), 1, 2.8, 4.2, 11])
    func `paired taps keep the kernel's sum and first moment and need about half the fetches`(sigma: Float) {
        let kernel = GaussianKernel(sigma: sigma)
        let taps = kernel.pairedTaps
        // Sum over one side plus the mirror, plus the centre: the zeroth moment is one.
        let sum = taps[0].y + 2 * taps.dropFirst().reduce(0) { $0 + $1.y }
        #expect(abs(sum - 1) < 1e-5, "sigma \(sigma): the paired kernel sums to \(sum)")
        // The first moment on one side: sum of offset * weight, identical to the unpaired kernel.
        let paired = taps.dropFirst().reduce(0) { $0 + $1.x * $1.y }
        let direct = (1...kernel.radius).reduce(Float(0)) { $0 + Float($1) * kernel.weights[$1] }
        #expect(abs(paired - direct) < 1e-5, "sigma \(sigma): first moment \(paired) against \(direct)")
        #expect(
            taps.count - 1 == (kernel.radius + 1) / 2,
            "sigma \(sigma): \(taps.count - 1) fetches for radius \(kernel.radius)")
        #expect(
            taps.dropFirst().allSatisfy { $0.x >= 1 && $0.x <= Float(kernel.radius) },
            "every fetch lies within the kernel")
    }

    @Test func `the kernel reaches three sigma and no further than the cap`() {
        #expect(GaussianKernel(sigma: 2.8).radius == 9)
        #expect(GaussianKernel(sigma: 500).radius == GaussianKernel.maximumRadius)
        #expect(GaussianKernel(sigma: 0).radius >= 1, "a zero sigma still yields a usable kernel")
    }

    // MARK: Distance transform

    /// The exhaustive answer. Beyond the raster there is nothing, which counts as outside, so the search runs over the
    /// raster with one ring of outside pixels around it.
    private func bruteForce(_ coverage: [UInt8], width: Int, height: Int) -> [Float] {
        let (paddedWidth, paddedHeight) = (width + 2, height + 2)
        var padded = [UInt8](repeating: 0, count: paddedWidth * paddedHeight)
        for y in 0..<height {
            for x in 0..<width { padded[(y + 1) * paddedWidth + x + 1] = coverage[y * width + x] }
        }
        var field = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let inside = coverage[y * width + x] >= 128
                var nearest = Float.greatestFiniteMagnitude
                for oy in 0..<paddedHeight {
                    for ox in 0..<paddedWidth where (padded[oy * paddedWidth + ox] >= 128) != inside {
                        let dx = Float(x + 1 - ox)
                        let dy = Float(y + 1 - oy)
                        nearest = min(nearest, (dx * dx + dy * dy).squareRoot())
                    }
                }
                field[y * width + x] = inside ? -(nearest - 0.5) : nearest - 0.5
            }
        }
        return field
    }

    @Test(arguments: [UInt64(1), 2, 3, 4, 5])
    func `the distance transform equals the exhaustive distance to the nearest opposite pixel`(seed: UInt64) {
        var state = seed &* 0x9E37_79B9_7F4A_7C15
        let (width, height) = (23, 17)
        var coverage = [UInt8](repeating: 0, count: width * height)
        for index in coverage.indices {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            coverage[index] = (state >> 60) < 5 ? 255 : 0
        }
        // Guarantee both classes exist, or there is no edge to measure.
        coverage[0] = 255
        coverage[width * height - 1] = 0
        let fast = SignedDistanceField.make(coverage: coverage, width: width, height: height)
        let slow = bruteForce(coverage, width: width, height: height)
        var worst: Float = 0
        for index in fast.indices { worst = max(worst, abs(fast[index] - slow[index])) }
        #expect(worst < 1e-3, "seed \(seed): the largest difference from the exhaustive distance is \(worst)")
    }

    @Test func `a shape that fills the whole raster still has an edge at the raster's border`() {
        // Everything inside: the nearest outside is just beyond the border, so the border pixels are 0.5 from the edge.
        let (width, height) = (10, 10)
        let field = SignedDistanceField.make(
            coverage: [UInt8](repeating: 255, count: width * height), width: width, height: height)
        #expect(
            abs(field[5 * width + 0] - -0.5) < 1e-4,
            "a border pixel is half a pixel inside the edge, got \(field[5 * width])")
        #expect(
            abs(field[5 * width + 5] - -4.5) < 1e-4,
            "the centre is five pixels from the nearest border: the right edge of column 9 is 5 away from column 5")
        #expect(abs(field[0] - -0.5) < 1e-4)
    }

    @Test func `a rounded rectangle path has the right distance at its centre and outside`() {
        let size = CGSize(width: 120, height: 80)
        let path = CGPath(
            roundedRect: CGRect(x: 20, y: 20, width: 80, height: 40), cornerWidth: 12, cornerHeight: 12, transform: nil)
        let field = SignedDistanceField.make(path: path, width: Int(size.width), height: Int(size.height), scale: 1)
        let width = Int(size.width)
        // Centre: 20 from the nearest long edge. Five pixels left of the left edge: +5.
        #expect(abs(field[40 * width + 60] - -20) < 1.0)
        #expect(abs(field[40 * width + 15] - 5) < 1.0)
        #expect(field[40 * width + 60] < 0 && field[5 * width + 5] > 0)
    }

    @Test func `the field reads the path at the scale it is drawn`() {
        let path = CGPath(rect: CGRect(x: 10, y: 10, width: 20, height: 20), transform: nil)
        let field = SignedDistanceField.make(path: path, width: 80, height: 80, scale: 2)
        // At 2x the square spans pixels 20...60: its centre (40, 40) is 20 px from every edge.
        #expect(abs(field[40 * 80 + 40] - -20) < 1.0)
    }

    // MARK: Pixel radii

    @Test func `a continuous corner is negative and a circular one positive`() {
        let size = CGSize(width: 100, height: 100)
        #expect(
            GlassShape.roundedRect(radii: GlassCornerRadii(10), curve: .continuous).shaderRadii(size: size, scale: 3)
                == SIMD4(repeating: -30))
        #expect(
            GlassShape.roundedRect(radii: GlassCornerRadii(10), curve: .circular).shaderRadii(size: size, scale: 3)
                == SIMD4(repeating: 30))
    }

    @Test func `a radius is clamped to half the shorter side and a zero stays zero`() {
        let size = CGSize(width: 100, height: 40)
        let radii = GlassShape.roundedRect(
            radii: GlassCornerRadii(topLeading: 500, topTrailing: 0, bottomLeading: 10, bottomTrailing: -5)
        )
        .shaderRadii(size: size, scale: 1)
        #expect(radii.x == -20, "clamped to 20, half the shorter side, and continuous")
        #expect(radii.y == 0)
        #expect(radii.z == -10)
        #expect(radii.w == 0, "a negative radius is a zero radius")
        #expect(
            radii.y.sign == .plus && radii.w.sign == .plus,
            "a zero radius is a positive zero, never the bit pattern of -0.0")
    }

    @Test func `a capsule and a circle round their ends fully`() {
        let size = CGSize(width: 200, height: 60)
        #expect(GlassShape.capsule.shaderRadii(size: size, scale: 2) == SIMD4(repeating: 60))
        #expect(GlassShape.circle.shaderRadii(size: CGSize(width: 80, height: 80), scale: 1) == SIMD4(repeating: 40))
    }

    // MARK: Uniform layout

    @Test func `the uniform block has the layout the shader declares`() {
        #expect(MemoryLayout<ClearGlassUniforms>.size == 128)
        #expect(MemoryLayout<ClearGlassUniforms>.stride == 128)
        #expect(MemoryLayout<ClearGlassUniforms>.offset(of: \.radii) == 32)
        #expect(MemoryLayout<ClearGlassUniforms>.offset(of: \.sdfRect) == 48)
        #expect(MemoryLayout<ClearGlassUniforms>.offset(of: \.rimEdge) == 64)
        #expect(MemoryLayout<ClearGlassUniforms>.offset(of: \.outline) == 88)
        #expect(MemoryLayout<ClearGlassUniforms>.offset(of: \.outlineDirection) == 96)
        #expect(MemoryLayout<ClearGlassUniforms>.offset(of: \.lightGain) == 124)
    }

    @Test func `the configuration converts points to pixels`() {
        let uniforms = ClearGlassConfiguration(rim: .gaussian(depth: 10, width: 4), outline: 0).uniforms(
            size: CGSize(width: 100, height: 50), scale: 3, sourceOrigin: .zero,
            sourceSize: CGSize(width: 300, height: 150))
        #expect(uniforms.viewSize == SIMD2(300, 150))
        #expect(uniforms.halfSize == SIMD2(150, 75))
        #expect(uniforms.rimBody == 30 && uniforms.rimBodyWidth == 12 && uniforms.rimEdge == 0)
    }

    @Test func `the view reaches beyond the shape by the margin the ring needs`() {
        let uniforms = ClearGlassConfiguration(outline: 0.3785, outlineReach: 0.82).uniforms(
            size: CGSize(width: 100, height: 50), scale: 3, sourceOrigin: .zero,
            sourceSize: CGSize(width: 300, height: 150))
        // A margin of 2 pt on each side of a 100 x 50 pt shape, at 3x.
        #expect(uniforms.viewSize == SIMD2(312, 162))
        #expect(uniforms.halfSize == SIMD2(150, 75), "the shape itself is unchanged")
        #expect(uniforms.outlineReach == 0.82 * 3)
    }

    // MARK: Exact path field

    @Test func `a rectangle path has the exact box distance and axis gradients`() {
        let path = CGPath(rect: CGRect(x: 20, y: 20, width: 60, height: 40), transform: nil)
        let field = SignedDistanceField.exact(path: path, width: 100, height: 80, scale: 1)
        var worst: Float = 0
        for y in 0..<80 {
            for x in 0..<100 {
                let p = SIMD2(Float(x) + 0.5, Float(y) + 0.5)
                let q = SIMD2(abs(p.x - 50) - 30, abs(p.y - 40) - 20)
                let expected =
                    (max(q.x, 0) * max(q.x, 0) + max(q.y, 0) * max(q.y, 0)).squareRoot() + min(max(q.x, q.y), 0)
                if abs(expected) < 100 { worst = max(worst, abs(field.distance[y * 100 + x] - expected)) }
            }
        }
        #expect(worst < 1e-3, "the largest difference from the exact box distance is \(worst) px")
        // Just left of the left edge the outward direction is -x; just inside the top edge it is -y.
        #expect(abs(field.gradient[40 * 100 + 15].x - -1) < 1e-4 && abs(field.gradient[40 * 100 + 15].y) < 1e-4)
        #expect(abs(field.gradient[22 * 100 + 50].y - -1) < 1e-4)
    }

    @Test func `a circle path has the right distance to within its flattening`() {
        let path = CGPath(ellipseIn: CGRect(x: 10, y: 10, width: 80, height: 80), transform: nil)
        let field = SignedDistanceField.exact(path: path, width: 100, height: 100, scale: 1)
        var worst: Float = 0
        for y in 0..<100 {
            for x in 0..<100 {
                let p = SIMD2(Float(x) + 0.5, Float(y) + 0.5)
                let expected = simd_length(p - SIMD2(50, 50)) - 40
                worst = max(worst, abs(field.distance[y * 100 + x] - expected))
            }
        }
        #expect(worst < 0.1, "the largest difference from the true circle is \(worst) px")
    }

    @Test func `a concave shape and a hole take their sign from the winding number`() {
        // An L, and a rectangle with a reversed rectangle cut out of it.
        let l = CGMutablePath()
        l.addLines(between: [
            CGPoint(x: 10, y: 10), CGPoint(x: 70, y: 10), CGPoint(x: 70, y: 40), CGPoint(x: 40, y: 40),
            CGPoint(x: 40, y: 70), CGPoint(x: 10, y: 70),
        ])
        l.closeSubpath()
        let fieldL = SignedDistanceField.exact(path: l, width: 80, height: 80, scale: 1)
        #expect(fieldL.distance[20 * 80 + 20] < 0, "inside the L")
        #expect(fieldL.distance[55 * 80 + 55] > 0, "in the notch of the L")
        let holed = CGMutablePath()
        holed.addRect(CGRect(x: 10, y: 10, width: 60, height: 60))
        holed.addLines(between: [
            CGPoint(x: 30, y: 30), CGPoint(x: 30, y: 50), CGPoint(x: 50, y: 50), CGPoint(x: 50, y: 30),
        ])
        holed.closeSubpath()
        let fieldHole = SignedDistanceField.exact(path: holed, width: 80, height: 80, scale: 1)
        #expect(fieldHole.distance[20 * 80 + 20] < 0, "in the ring")
        #expect(fieldHole.distance[40 * 80 + 40] > 0, "in the hole")
    }

    @Test func `a nested shape wound the same way stays filled, as a nonzero fill does`() {
        let nested = CGMutablePath()
        nested.addRect(CGRect(x: 10, y: 10, width: 60, height: 60))
        nested.addRect(CGRect(x: 30, y: 30, width: 20, height: 20))
        let field = SignedDistanceField.exact(path: nested, width: 80, height: 80, scale: 1)
        #expect(field.distance[40 * 80 + 40] < 0, "the inner rectangle has winding 2: filled under the nonzero rule")
    }

    @Test func `far from every edge the field is clamped to the reach with no gradient`() {
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10), transform: nil)
        let field = SignedDistanceField.exact(path: path, width: 400, height: 400, scale: 1)
        #expect(field.distance[399 * 400 + 399] == SignedDistanceField.reach)
        #expect(field.gradient[399 * 400 + 399] == .zero)
    }

    /// The banding: along a slanted straight edge the raster-based gradient steps, the exact one does not.
    @Test func `a slanted edge has one gradient direction, where the raster field's gradient steps`() {
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: 60, y: 10), CGPoint(x: 110, y: 110), CGPoint(x: 10, y: 110)])
        path.closeSubpath()
        let size = 120
        let exact = SignedDistanceField.exact(path: path, width: size, height: size, scale: 1)
        let raster = SignedDistanceField.make(path: path, width: size, height: size, scale: 1)
        // The right edge runs from (60, 10) to (110, 110); its outward normal is (200, -100) / |.| = (0.894, -0.447).
        let normal = SIMD2<Float>(100, -50) / (100 * 100 + 50 * 50 as Float).squareRoot()
        var exactSpread: Float = 0
        var rasterSpread: Float = 0
        for y in 30..<90 {
            // The pixels a few pixels inside that edge: x = 60 + (y - 10) / 2 - 4.
            let x = Int((60 + Float(y - 10) / 2 - 4).rounded())
            let a = exact.gradient[y * size + x]
            exactSpread = max(exactSpread, simd_length(a - normal))
            // A finite difference of the raster field, as the glass used to take it.
            let gx = raster[y * size + x + 1] - raster[y * size + x - 1]
            let gy = raster[(y + 1) * size + x] - raster[(y - 1) * size + x]
            let g = SIMD2(gx, gy)
            rasterSpread = max(rasterSpread, simd_length(g / max(simd_length(g), 1e-6) - normal))
        }
        #expect(exactSpread < 0.02, "the exact gradient strays from the edge normal by \(exactSpread)")
        #expect(
            rasterSpread > 3 * exactSpread,
            "the raster gradient (\(rasterSpread)) must be visibly worse, or this test proves nothing")
    }

    /// The displacement read off native clear glass with a position-coded background (Glass Lab, Tools/deformation.py),
    /// the same for a square, a capsule, a circle, a rounded rectangle and a triangle, in pixels at 3x.
    private static let nativeProfile: [(depth: Double, pull: Double)] = [
        (1.5, 134.0), (2.5, 127.0), (3.5, 119.0), (4.5, 111.0), (6, 100.0), (8, 89.0), (10, 79.5), (12, 71.5),
        (15, 60.3),
        (20, 45.4), (25, 33.4), (30, 23.9), (40, 10.2), (50, 2.4), (60, 0.0),
    ]

    @Test func `the native rim profile follows the measured displacement to within two pixels`() {
        let rim = ClearGlassRim.nativeClear
        var worst = 0.0
        for (depth, measured) in Self.nativeProfile {
            // The table is in pixels at 3x; the rim is in points.
            let modelled = Double(rim.pull(atDepth: CGFloat(depth / 3))) * 3
            worst = max(worst, abs(modelled - measured))
        }
        #expect(worst < 2.0, "the rim differs from the measured native profile by \(worst) px")
    }

    @Test func `a single Gaussian cannot follow the measured profile, which is why the rim has two terms`() {
        // Best single Gaussian through the measured table (fitted offline): 109 px, width 22 px.
        let gaussian = ClearGlassRim.gaussian(depth: 109.2 / 3, width: 22.3 / 3)
        var worst = 0.0
        for (depth, measured) in Self.nativeProfile {
            worst = max(worst, abs(Double(gaussian.pull(atDepth: CGFloat(depth / 3))) * 3 - measured))
        }
        #expect(worst > 10, "if one Gaussian fitted, the second term would be dead weight: worst \(worst) px")
    }
}
