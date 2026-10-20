//
//  SignedDistanceField.swift
//  AemiSDR
//
//  Turns any shape into a distance field. A path is rasterised to coverage, and an exact Euclidean distance transform
//  (Felzenszwalb and Huttenlocher, linear time) gives the distance to the edge at every pixel, negative inside.
//  Apple's glass builds its field from a mask the same way (jump flooding on the GPU); on the CPU the exact transform is
//  simple, deterministic and testable, and it runs once per shape and size, not per frame.
//

import CoreGraphics
import Foundation

enum SignedDistanceField {
    /// Distances beyond this are not stored: the rim effect is gone long before it.
    static let reach: Float = 128

    /// Signed distance in pixels from every pixel centre to the nearest edge, negative inside. `coverage` is 0...255
    /// per pixel, row by row; 128 and above is inside. The half-pixel offset places the edge between pixel centres.
    static func make(coverage: [UInt8], width: Int, height: Int) -> [Float] {
        precondition(coverage.count == width * height, "coverage must hold width * height values")
        // Beyond the raster there is nothing, which is outside. One ring of outside pixels is enough: any farther
        // outside pixel is farther than the ring. Without it a shape that fills the raster has no edge at the border.
        let (paddedWidth, paddedHeight) = (width + 2, height + 2)
        var padded = [UInt8](repeating: 0, count: paddedWidth * paddedHeight)
        for y in 0..<height {
            for x in 0..<width { padded[(y + 1) * paddedWidth + x + 1] = coverage[y * width + x] }
        }
        let infinity: Float = 1.0e20
        var toInside = [Float](repeating: infinity, count: padded.count)
        var toOutside = [Float](repeating: infinity, count: padded.count)
        for index in padded.indices {
            if padded[index] >= 128 { toInside[index] = 0 } else { toOutside[index] = 0 }
        }
        transform(&toInside, width: paddedWidth, height: paddedHeight)
        transform(&toOutside, width: paddedWidth, height: paddedHeight)
        var field = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y + 1) * paddedWidth + x + 1
                field[y * width + x] =
                    padded[index] >= 128 ? -(toOutside[index].squareRoot() - 0.5) : toInside[index].squareRoot() - 0.5
            }
        }
        return field
    }

    /// Rasterise `path` (in points, origin top left) at `scale` pixels per point into a `width` by `height` field,
    /// with the path's origin placed `origin` points in from the raster's top-left corner.
    static func make(path: CGPath, width: Int, height: Int, scale: CGFloat, origin: CGPoint = .zero) -> [Float] {
        var coverage = [UInt8](repeating: 0, count: width * height)
        coverage.withUnsafeMutableBytes { buffer in
            guard
                let context = unsafe CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return }
            context.setAllowsAntialiasing(true)
            // Core Graphics has y up; flip so row 0 is the top, then draw the path in points.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: scale, y: -scale)
            context.translateBy(x: origin.x, y: origin.y)
            context.setFillColor(gray: 1, alpha: 1)
            context.addPath(path)
            context.fillPath()
        }
        return make(coverage: coverage, width: width, height: height)
    }

    // MARK: Felzenszwalb squared distance transform

    /// Replaces each entry with the squared distance to the nearest zero entry, in place.
    private static func transform(_ values: inout [Float], width: Int, height: Int) {
        var column = [Float](repeating: 0, count: max(width, height))
        var output = [Float](repeating: 0, count: max(width, height))
        for x in 0..<width {
            for y in 0..<height { column[y] = values[y * width + x] }
            transform1D(column, count: height, into: &output)
            for y in 0..<height { values[y * width + x] = output[y] }
        }
        for y in 0..<height {
            for x in 0..<width { column[x] = values[y * width + x] }
            transform1D(column, count: width, into: &output)
            for x in 0..<width { values[y * width + x] = output[x] }
        }
    }

    private static func transform1D(_ f: [Float], count n: Int, into d: inout [Float]) {
        var v = [Int](repeating: 0, count: n)
        var z = [Float](repeating: 0, count: n + 1)
        var k = 0
        z[0] = -.greatestFiniteMagnitude
        z[1] = .greatestFiniteMagnitude
        if n > 1 {
            for q in 1..<n {
                // Intersection of the parabola rooted at q with the rightmost one kept so far; while it falls before
                // that parabola's own start, the kept one is hidden and is dropped.
                var s = ((f[q] + Float(q * q)) - (f[v[k]] + Float(v[k] * v[k]))) / Float(2 * q - 2 * v[k])
                while s <= z[k] {
                    k -= 1
                    s = ((f[q] + Float(q * q)) - (f[v[k]] + Float(v[k] * v[k]))) / Float(2 * q - 2 * v[k])
                }
                k += 1
                v[k] = q
                z[k] = s
                z[k + 1] = .greatestFiniteMagnitude
            }
        }
        k = 0
        for q in 0..<n {
            while z[k + 1] < Float(q) { k += 1 }
            let p = v[k]
            d[q] = Float((q - p) * (q - p)) + f[p]
        }
    }
}
