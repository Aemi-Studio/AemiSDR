// Pixel probe for the Glass Lab: probe A.png x y [x y ...]   or   probe A.png --row y x0 x1 step
// Prints sRGB values (0...255) at the given pixels.
import CoreGraphics
import Foundation
import ImageIO

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 3, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[0]) as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    print("usage: probe A.png x y ...  |  probe A.png --row y x0 x1 step")
    exit(2)
}
let w = image.width
let h = image.height
var rgba = [UInt8](repeating: 0, count: w * h * 4)
rgba.withUnsafeMutableBytes { buffer in
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return }
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
}
func show(_ x: Int, _ y: Int) {
    let i = (y * w + x) * 4
    print("(\(x),\(y)) = \(rgba[i]) \(rgba[i + 1]) \(rgba[i + 2])")
}
let n = args.dropFirst().compactMap { Int($0) }
if args[1] == "--row" {
    let y = n[0]
    for x in stride(from: n[1], through: n[2], by: max(1, n[3])) { show(x, y) }
} else {
    for k in stride(from: 0, to: n.count - 1, by: 2) { show(n[k], n[k + 1]) }
}
