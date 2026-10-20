// crop IN OUT x y w h scale: crop a region and enlarge it with nearest-neighbour sampling.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 8 else { fail("usage: crop IN OUT x y w h scale") }
let numbers = args[3...7].compactMap { Int($0) }
guard numbers.count == 5 else { fail("x y w h scale must be integers") }
let (x, y, w, h, scale) = (numbers[0], numbers[1], numbers[2], numbers[3], numbers[4])
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
    let cropped = image.cropping(to: CGRect(x: x, y: y, width: w, height: h)),
    let space = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
        data: nil, width: w * scale, height: h * scale, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fail("cannot read or crop \(args[1])") }
context.interpolationQuality = .none
context.draw(cropped, in: CGRect(x: 0, y: 0, width: w * scale, height: h * scale))
guard let result = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("cannot write \(args[2])") }
CGImageDestinationAddImage(destination, result, nil)
CGImageDestinationFinalize(destination)
