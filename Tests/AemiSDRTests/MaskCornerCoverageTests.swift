//
//  MaskCornerCoverageTests.swift
//  AemiSDRTests
//
//  The rounded-shape masks have a hole in the middle and a covered frame around it. The frame must reach all the way
//  into the pointy corners of the rectangle: the wedge between each rounded arc and the square corner is OUTSIDE the
//  shape, so it must be fully masked (and fully clear when the mask is inverted).
//
//  A device's own rounded corners hide those wedges, and a screenshot of a rounded device looks fine either way, so
//  this cannot be checked by eye. These tests render the real Core Image kernels and compare every pixel against an
//  independent CPU signed-distance function.
//

import CoreGraphics
import CoreImage
import Foundation
import Testing

@testable import AemiSDR

@Suite("Rounded masks cover the corner wedges")
struct MaskCornerCoverageTests {
    /// The four masks that take a corner radius.
    static let shapes: [MaskType] = [
        .roundedRectangle, .easedRoundedRectangle, .superellipseSquircle, .easedSuperellipseSquircle,
    ]

    /// Row-major alpha in 0...1; row 0 is the top row of the image.
    struct Mask {
        var width: Int
        var height: Int
        var alpha: [Float]
        func at(_ x: Int, _ y: Int) -> Float { alpha[y * width + x] }
    }

    static func render(
        _ type: MaskType, width: Int, height: Int, radius: CGFloat, fade: CGFloat, inverted: Bool
    ) throws -> Mask {
        let descriptor = type.kernelDescriptor(
            size: CGSize(width: width, height: height), scale: 1, cornerRadius: radius, fadeWidth: fade,
            inverted: inverted)
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        let image = try #require(
            CIKernelCache.generateCGImage(
                kernel: descriptor.kernel, extent: extent, arguments: descriptor.arguments,
                context: CIKernelCache.maskContext),
            "the \(type) kernel produced no image; is the shader library built?")
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer in
            guard
                let context = unsafe CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: extent)
            return true
        }
        try #require(drawn)
        return Mask(
            width: width, height: height, alpha: (0..<(width * height)).map { Float(bytes[$0 * 4 + 3]) / 255 })
    }

    /// The exact signed distance to a rounded rectangle, written independently of the shader.
    static func signedDistance(x: Int, y: Int, width: Int, height: Int, radius: Double) -> Double {
        let halfWidth = Double(width) / 2
        let halfHeight = Double(height) / 2
        let r = min(max(radius, 0), min(halfWidth, halfHeight))
        let px = abs(Double(x) + 0.5 - halfWidth) - (halfWidth - r)
        let py = abs(Double(y) + 0.5 - halfHeight) - (halfHeight - r)
        let outside = (max(px, 0) * max(px, 0) + max(py, 0) * max(py, 0)).squareRoot()
        return outside + min(max(px, py), 0) - r
    }

    // MARK: - Every pixel outside the shape

    @Test(arguments: MaskCornerCoverageTests.shapes)
    func `every pixel outside the rounded shape is fully masked, wedges and pointy corners included`(
        type: MaskType
    ) throws {
        let (width, height, radius, fade) = (200, 300, 60.0, 16.0)
        let mask = try Self.render(type, width: width, height: height, radius: radius, fade: fade, inverted: false)
        var checked = 0
        for y in 0..<height {
            for x in 0..<width {
                // One pixel of margin: the edge itself is anti-aliased.
                guard Self.signedDistance(x: x, y: y, width: width, height: height, radius: radius) >= 1 else {
                    continue
                }
                checked += 1
                #expect(
                    mask.at(x, y) >= 0.99,
                    "\(type) pixel (\(x), \(y)) is outside the shape but only \(mask.at(x, y)) masked")
                if mask.at(x, y) < 0.99 { return }
            }
        }
        #expect(checked > 4 * 400, "the scan must include the corner wedges (checked \(checked) pixels)")
    }

    @Test(arguments: MaskCornerCoverageTests.shapes)
    func `the four extent corners are fully masked`(type: MaskType) throws {
        let (width, height) = (200, 300)
        let mask = try Self.render(type, width: width, height: height, radius: 60, fade: 16, inverted: false)
        for (x, y) in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)] {
            #expect(mask.at(x, y) >= 0.99, "\(type) corner (\(x), \(y)) = \(mask.at(x, y))")
        }
    }

    @Test(arguments: MaskCornerCoverageTests.shapes)
    func `the middle of the shape is a hole`(type: MaskType) throws {
        let mask = try Self.render(type, width: 200, height: 300, radius: 60, fade: 16, inverted: false)
        #expect(mask.at(100, 150) <= 0.01)
    }

    // MARK: - Inverted: the same regions swap

    @Test(arguments: MaskCornerCoverageTests.shapes)
    func `inverted, the corner wedges are clear and the middle is covered`(type: MaskType) throws {
        let (width, height, radius, fade) = (200, 300, 60.0, 16.0)
        let mask = try Self.render(type, width: width, height: height, radius: radius, fade: fade, inverted: true)
        for (x, y) in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)] {
            #expect(mask.at(x, y) <= 0.01, "\(type) inverted corner (\(x), \(y)) = \(mask.at(x, y))")
        }
        #expect(mask.at(100, 150) >= 0.99)
    }

    // MARK: - Radius extremes

    @Test(arguments: MaskCornerCoverageTests.shapes)
    func `a zero radius leaves nothing to fill and still masks the pointy corners`(type: MaskType) throws {
        let (width, height) = (120, 80)
        let mask = try Self.render(type, width: width, height: height, radius: 0, fade: 8, inverted: false)
        for (x, y) in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)] {
            #expect(mask.at(x, y) >= 0.98, "\(type) sharp corner (\(x), \(y)) = \(mask.at(x, y))")
        }
    }

    @Test(arguments: MaskCornerCoverageTests.shapes)
    func `a radius larger than the shape is clamped and the extent corners stay masked`(type: MaskType) throws {
        let (width, height) = (160, 100)
        let mask = try Self.render(type, width: width, height: height, radius: 500, fade: 8, inverted: false)
        for (x, y) in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)] {
            #expect(mask.at(x, y) >= 0.99, "\(type) clamped-radius corner (\(x), \(y)) = \(mask.at(x, y))")
        }
    }

    // MARK: - The outermost pixel row

    @Test(arguments: MaskCornerCoverageTests.shapes, [0.0, 2.0, 8.0, 16.0])
    func `the outermost pixel row is fully masked whatever the fade width`(type: MaskType, fade: Double) throws {
        // A pixel centre sits half a pixel inside the edge. A mask that only reaches full strength AT the edge leaves
        // that row short, and the shortfall grows as the fade shrinks.
        let (width, height) = (120, 80)
        let mask = try Self.render(type, width: width, height: height, radius: 0, fade: fade, inverted: false)
        let samples = [
            (0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1),
            (width / 2, 0), (width / 2, height - 1), (0, height / 2), (width - 1, height / 2),
        ]
        for (x, y) in samples {
            #expect(mask.at(x, y) >= 0.995, "\(type) fade \(fade): edge pixel (\(x), \(y)) = \(mask.at(x, y))")
        }
    }

    @Test(arguments: MaskCornerCoverageTests.shapes, [0.0, 2.0, 16.0])
    func `inverted, the outermost pixel row is fully clear whatever the fade width`(type: MaskType, fade: Double) throws
    {
        let (width, height) = (120, 80)
        let mask = try Self.render(type, width: width, height: height, radius: 0, fade: fade, inverted: true)
        for (x, y) in [(0, 0), (width - 1, height - 1), (width / 2, 0), (0, height / 2)] {
            #expect(mask.at(x, y) <= 0.005, "\(type) inverted fade \(fade): edge pixel (\(x), \(y)) = \(mask.at(x, y))")
        }
    }
}
