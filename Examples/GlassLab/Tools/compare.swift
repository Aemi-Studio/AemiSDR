// Bitmap comparison for the Glass Lab: compare.swift A.png B.png [x y w h] [--diff out.png]
//
// Prints, for the chosen region (pixels; default the whole image): mean absolute error per channel (0...1), PSNR, and the
// mean structural similarity (SSIM, 8x8 uniform windows on luma, stride 4). "similarity" is SSIM x 100. Both images must be
// the same size. Region coordinates are in pixels, origin top left.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Bitmap {
    let width: Int, height: Int
    var rgba: [UInt8]

    init(path: String) throws {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw NSError(domain: "compare", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot read \(path)"]) }
        width = image.width
        height = image.height
        rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw NSError(domain: "compare", code: 2, userInfo: [NSLocalizedDescriptionKey: "no sRGB colour space"])
        }
        let (width, height) = (self.width, self.height)
        rgba.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func luma(_ x: Int, _ y: Int) -> Double {
        let i = (y * width + x) * 4
        return (0.2126 * Double(rgba[i]) + 0.7152 * Double(rgba[i + 1]) + 0.0722 * Double(rgba[i + 2])) / 255
    }
}

struct Metrics {
    var mae: (Double, Double, Double) = (0, 0, 0)
    var psnr = 0.0
    var ssim = 0.0
}

func measure(_ a: Bitmap, _ b: Bitmap, region: (x: Int, y: Int, w: Int, h: Int)) -> Metrics {
    var sums = (0.0, 0.0, 0.0)
    var squares = 0.0
    for y in region.y..<(region.y + region.h) {
        for x in region.x..<(region.x + region.w) {
            let i = (y * a.width + x) * 4
            let d = (
                abs(Double(a.rgba[i]) - Double(b.rgba[i])) / 255,
                abs(Double(a.rgba[i + 1]) - Double(b.rgba[i + 1])) / 255,
                abs(Double(a.rgba[i + 2]) - Double(b.rgba[i + 2])) / 255
            )
            sums.0 += d.0
            sums.1 += d.1
            sums.2 += d.2
            squares += d.0 * d.0 + d.1 * d.1 + d.2 * d.2
        }
    }
    let n = Double(region.w * region.h)
    var m = Metrics()
    m.mae = (sums.0 / n, sums.1 / n, sums.2 / n)
    let mse = squares / (3 * n)
    m.psnr = mse == 0 ? .infinity : 10 * log10(1 / mse)

    let win = 8
    let stride = 4
    let c1 = 0.01 * 0.01
    let c2 = 0.03 * 0.03
    var total = 0.0
    var count = 0
    var y = region.y
    while y + win <= region.y + region.h {
        var x = region.x
        while x + win <= region.x + region.w {
            var ma = 0.0
            var mb = 0.0
            for j in 0..<win {
                for i in 0..<win {
                    ma += a.luma(x + i, y + j)
                    mb += b.luma(x + i, y + j)
                }
            }
            ma /= Double(win * win)
            mb /= Double(win * win)
            var va = 0.0
            var vb = 0.0
            var cov = 0.0
            for j in 0..<win {
                for i in 0..<win {
                    let da = a.luma(x + i, y + j) - ma
                    let db = b.luma(x + i, y + j) - mb
                    va += da * da
                    vb += db * db
                    cov += da * db
                }
            }
            let k = Double(win * win - 1)
            va /= k
            vb /= k
            cov /= k
            total += ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma * ma + mb * mb + c1) * (va + vb + c2))
            count += 1
            x += stride
        }
        y += stride
    }
    m.ssim = count == 0 ? 1 : total / Double(count)
    return m
}

func writeDiff(_ a: Bitmap, _ b: Bitmap, to path: String) {
    var out = [UInt8](repeating: 255, count: a.width * a.height * 4)
    for p in 0..<(a.width * a.height) {
        for c in 0..<3 { out[p * 4 + c] = UInt8(min(255, abs(Int(a.rgba[p * 4 + c]) - Int(b.rgba[p * 4 + c])) * 4)) }
    }
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
    let (width, height) = (a.width, a.height)
    out.withUnsafeMutableBytes { buffer in
        guard
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}

var arguments = Array(CommandLine.arguments.dropFirst())
var diffPath: String?
if let index = arguments.firstIndex(of: "--diff"), index + 1 < arguments.count {
    diffPath = arguments[index + 1]
    arguments.removeSubrange(index...(index + 1))
}
guard arguments.count == 2 || arguments.count == 6 else {
    FileHandle.standardError.write(Data("usage: compare A.png B.png [x y w h] [--diff out.png]\n".utf8))
    exit(2)
}
do {
    let a = try Bitmap(path: arguments[0])
    let b = try Bitmap(path: arguments[1])
    guard a.width == b.width, a.height == b.height else {
        FileHandle.standardError.write(Data("size mismatch: \(a.width)x\(a.height) vs \(b.width)x\(b.height)\n".utf8))
        exit(2)
    }
    var region = (x: 0, y: 0, w: a.width, h: a.height)
    if arguments.count == 6 {
        let v = arguments[2...5].map { Int($0) ?? 0 }
        region = (max(0, v[0]), max(0, v[1]), min(v[2], a.width - max(0, v[0])), min(v[3], a.height - max(0, v[1])))
    }
    let m = measure(a, b, region: region)
    print(
        String(
            format: "similarity=%.2f ssim=%.4f psnr=%.2fdB mae=(%.4f %.4f %.4f) region=%d,%d %dx%d",
            m.ssim * 100, m.ssim, m.psnr, m.mae.0, m.mae.1, m.mae.2, region.x, region.y, region.w, region.h))
    if let diffPath { writeDiff(a, b, to: diffPath) }
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
