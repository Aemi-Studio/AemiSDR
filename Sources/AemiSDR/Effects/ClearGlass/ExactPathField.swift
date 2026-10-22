//
//  ExactPathField.swift
//  AemiSDR
//
//  The exact signed distance field of a path, with a true gradient.
//
//  A distance transform of a rasterised mask is exact only to half a pixel, and its gradient (a finite difference of
//  that field) steps along any slanted edge, which shows as banding in the glass. Here the path is flattened to line
//  segments, the distance is measured to the nearest segment and the gradient is the unit direction to the nearest point,
//  so a straight slanted edge has one constant gradient and a distance exact to rounding. The sign comes from the winding
//  number, found by sweeping each row once.
//

import CoreGraphics
import Foundation
import simd

/// A distance field with its gradient. Distances are in pixels, negative inside; the gradient is the unit outward
/// direction (zero where no edge lies within reach).
struct GlassDistanceField: Equatable {
    var width: Int
    var height: Int
    var distance: [Float]
    var gradient: [SIMD2<Float>]
}

extension SignedDistanceField {
    /// One line segment of the flattened path, in pixels.
    struct Segment {
        var a: SIMD2<Float>
        var b: SIMD2<Float>
    }

    /// The path, flattened to segments in the pixel space of a raster: points scaled by `scale`, the path's origin
    /// `origin` points in from the top-left corner. Every subpath is closed, as a fill closes it.
    static func flatten(path: CGPath, scale: CGFloat, origin: CGPoint) -> [Segment] {
        var segments: [Segment] = []
        var start = SIMD2<Float>.zero
        var current = SIMD2<Float>.zero
        var open = false
        func point(_ p: CGPoint) -> SIMD2<Float> {
            SIMD2(Float((p.x + origin.x) * scale), Float((p.y + origin.y) * scale))
        }
        func line(to next: SIMD2<Float>) {
            if next != current { segments.append(Segment(a: current, b: next)) }
            current = next
        }
        func steps(_ points: [SIMD2<Float>]) -> Int {
            var length: Float = 0
            for index in 1..<points.count { length += simd_length(points[index] - points[index - 1]) }
            // One step per two pixels of control polygon, enough that the chord error is far below a pixel.
            return min(96, max(8, Int(length / 2)))
        }
        path.applyWithBlock { element in
            let pointer = unsafe element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                if open, current != start { line(to: start) }
                start = point(unsafe pointer[0])
                current = start
                open = true
            case .addLineToPoint:
                line(to: point(unsafe pointer[0]))
            case .addQuadCurveToPoint:
                let (p0, p1, p2) = (current, point(unsafe pointer[0]), point(unsafe pointer[1]))
                let count = steps([p0, p1, p2])
                for step in 1...count {
                    let t = Float(step) / Float(count)
                    let u = 1 - t
                    line(to: u * u * p0 + 2 * u * t * p1 + t * t * p2)
                }
            case .addCurveToPoint:
                let (p0, p1, p2, p3) = (
                    current, point(unsafe pointer[0]), point(unsafe pointer[1]), point(unsafe pointer[2])
                )
                let count = steps([p0, p1, p2, p3])
                for step in 1...count {
                    let t = Float(step) / Float(count)
                    let u = 1 - t
                    line(to: u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3)
                }
            case .closeSubpath:
                if current != start { line(to: start) }
                current = start
            @unknown default:
                break
            }
        }
        if open, current != start { line(to: start) }
        return segments
    }

    /// The exact field of `path` over a `width` by `height` raster, sampled at pixel centres.
    static func exact(path: CGPath, width: Int, height: Int, scale: CGFloat, origin: CGPoint = .zero)
        -> GlassDistanceField
    {
        exact(segments: flatten(path: path, scale: scale, origin: origin), width: width, height: height)
    }

    static func exact(segments: [Segment], width: Int, height: Int) -> GlassDistanceField {
        let reach = SignedDistanceField.reach
        var distance = [Float](repeating: reach, count: width * height)
        var gradient = [SIMD2<Float>](repeating: .zero, count: width * height)
        guard !segments.isEmpty, width > 0, height > 0 else {
            return GlassDistanceField(width: width, height: height, distance: distance, gradient: gradient)
        }

        // Rows are independent: each is computed by one task.
        let box = segments.map { (low: simd_min($0.a, $0.b), high: simd_max($0.a, $0.b)) }
        distance.withUnsafeMutableBufferPointer { distances in
            gradient.withUnsafeMutableBufferPointer { gradients in
                let distancePointer = unsafe distances.baseAddress
                let gradientPointer = unsafe gradients.baseAddress
                // Each iteration writes only its own row, so the tasks never touch the same element.
                nonisolated(unsafe) let out = (unsafe distancePointer, unsafe gradientPointer)
                DispatchQueue.concurrentPerform(iterations: height) { row in
                    let yc = Float(row) + 0.5
                    // Inside intervals by the winding number of every segment crossing this row.
                    var crossings: [(x: Float, winding: Int)] = []
                    for segment in segments {
                        let (a, b) = (segment.a, segment.b)
                        if (a.y <= yc && b.y > yc) || (b.y <= yc && a.y > yc) {
                            let t = (yc - a.y) / (b.y - a.y)
                            crossings.append((a.x + t * (b.x - a.x), b.y > a.y ? 1 : -1))
                        }
                    }
                    crossings.sort { $0.x < $1.x }
                    var nearby: [Int] = []
                    for index in segments.indices
                    where box[index].low.y - reach <= yc && yc <= box[index].high.y + reach {
                        nearby.append(index)
                    }
                    var crossing = 0
                    var winding = 0
                    for column in 0..<width {
                        let xc = Float(column) + 0.5
                        while crossing < crossings.count, crossings[crossing].x <= xc {
                            winding += crossings[crossing].winding
                            crossing += 1
                        }
                        let p = SIMD2<Float>(xc, yc)
                        var best = reach * reach
                        var nearest = SIMD2<Float>.zero
                        for index in nearby {
                            let low = box[index].low
                            let high = box[index].high
                            let limit = best.squareRoot()
                            if xc < low.x - limit || xc > high.x + limit || yc < low.y - limit || yc > high.y + limit {
                                continue
                            }
                            let (a, b) = (segments[index].a, segments[index].b)
                            let ab = b - a
                            let t = min(max(simd_dot(p - a, ab) / max(simd_dot(ab, ab), 1e-12), 0), 1)
                            let closest = a + t * ab
                            let d2 = simd_length_squared(p - closest)
                            if d2 < best {
                                best = d2
                                nearest = closest
                            }
                        }
                        let inside = winding != 0
                        let magnitude = best.squareRoot()
                        let offset = row * width + column
                        if best >= reach * reach {
                            unsafe out.0?[offset] = inside ? -reach : reach
                            unsafe out.1?[offset] = .zero
                        } else {
                            let away = magnitude > 1e-6 ? (p - nearest) / magnitude : SIMD2<Float>.zero
                            unsafe out.0?[offset] = inside ? -magnitude : magnitude
                            // The outward direction: away from the edge outside, toward it inside.
                            unsafe out.1?[offset] = inside ? -away : away
                        }
                    }
                }
            }
        }
        return GlassDistanceField(width: width, height: height, distance: distance, gradient: gradient)
    }
}

extension GlassDistanceField {
    /// How far beyond the raster the glass can look: the largest distance, in pixels, by which a sample position
    /// `pixel - gradient * pull(depth)` falls outside the raster, over every pixel inside the shape. `pull` gives the
    /// displacement in pixels at a depth in pixels.
    func lookReach(chromatic: Float = 0, pull: (Float) -> Float) -> Float {
        var reach: Float = 0
        let (maxX, maxY) = (Float(width), Float(height))
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let depth = -distance[index]
                guard depth > 0 else { continue }
                let amount = pull(depth)
                let pixel = SIMD2(Float(x) + 0.5, Float(y) + 0.5)
                // The green sample lies between red and blue. Include both extremes, even when fringing reverses a pull.
                let red = pixel - gradient[index] * (amount * (1 + chromatic))
                let blue = pixel - gradient[index] * (amount * (1 - chromatic))
                reach = max(
                    reach, -red.x, red.x - maxX, -red.y, red.y - maxY,
                    -blue.x, blue.x - maxX, -blue.y, blue.y - maxY)
            }
        }
        return reach
    }
}
