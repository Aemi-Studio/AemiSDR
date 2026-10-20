// stack OUT A.png B.png ...: stack images vertically, separated by a magenta line, for side-by-side review.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else { fail("usage: stack OUT A.png B.png ...") }
let output = args[0]
var images: [CGImage] = []
for path in args.dropFirst() {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("cannot read \(path)") }
    images.append(image)
}
let width = images.map(\.width).max() ?? 0
let height = images.map(\.height).reduce(0, +) + 8 * (images.count - 1)
guard let space = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fail("cannot create a context") }
context.setFillColor(CGColor(red: 1, green: 0, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
var top = height
for image in images {
    top -= image.height
    context.draw(image, in: CGRect(x: 0, y: top, width: image.width, height: image.height))
    top -= 8
}
guard let result = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("cannot write \(output)") }
CGImageDestinationAddImage(destination, result, nil)
CGImageDestinationFinalize(destination)
