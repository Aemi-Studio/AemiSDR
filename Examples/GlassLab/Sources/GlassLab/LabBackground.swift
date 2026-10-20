import CoreGraphics
import Foundation

/// Pixel-exact test backgrounds. Every pattern is generated into an RGBA8 sRGB buffer at the screen's native pixel size and shown 1:1, so a
/// pixel in the capture is a pixel here and displacement can be measured in pixels.
enum LabBackground {
    static func image(named name: String, width: Int, height: Int) -> CGImage? {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        var generator = SplitMix(seed: 0x9E37_79B9_7F4A_7C15)
        let value = noise(width: width, height: height, generator: &generator)
        for y in 0..<height {
            for x in 0..<width {
                let (r, g, b) = color(name, x: x, y: y, width: width, height: height, noise: value)
                let offset = (y * width + x) * 4
                pixels[offset] = r
                pixels[offset + 1] = g
                pixels[offset + 2] = b
                pixels[offset + 3] = 255
            }
        }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return pixels.withUnsafeMutableBytes { buffer in
            unsafe CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
    }

    private static func color(
        _ name: String, x: Int, y: Int, width: Int, height: Int, noise: (Int, Int) -> Double
    ) -> (UInt8, UInt8, UInt8) {
        func gray(_ v: Double) -> (UInt8, UInt8, UInt8) {
            let c = UInt8(max(0, min(255, (v * 255).rounded())))
            return (c, c, c)
        }
        let u = Double(x) / Double(max(1, width - 1))
        let v = Double(y) / Double(max(1, height - 1))
        switch name {
        case "black": return gray(0)
        case "white": return gray(1)
        case "gray": return gray(0.5)
        case "red": return (255, 0, 0)
        case "green": return (0, 255, 0)
        case "blue": return (0, 0, 255)
        case "hramp": return gray(u)
        case "vramp": return gray(v)
        case "step": return gray(x < width / 2 ? 0 : 1)
        case "checker": return gray(((x / 16) + (y / 16)) % 2 == 0 ? 0.9 : 0.1)
        case "grid": return gray(x % 32 < 2 || y % 32 < 2 ? 1 : 0.08)
        case "dots":
            let inDotX = (x % 24) >= 10 && (x % 24) < 14
            let inDotY = (y % 24) >= 10 && (y % 24) < 14
            return gray(inDotX && inDotY ? 1 : 0)
        case "colorbars":
            let bars: [(UInt8, UInt8, UInt8)] = [
                (255, 255, 255), (255, 255, 0), (0, 255, 255), (0, 255, 0),
                (255, 0, 255), (255, 0, 0), (0, 0, 255), (16, 16, 16),
            ]
            return bars[min(7, Int(u * 8))]
        case "stripes": return gray(((x + y) / 12) % 2 == 0 ? 0.95 : 0.15)
        case "complex":
            // Deterministic photographic-ish content: smooth colour fields, fine texture and hard edges.
            let n = noise(x, y)
            let r = 0.5 + 0.5 * sin(u * 9.0 + v * 3.0)
            let g = 0.5 + 0.5 * sin(v * 11.0 - u * 2.0 + 1.3)
            let b = 0.5 + 0.5 * cos((u - v) * 7.0)
            let edge = (Int(u * 6) + Int(v * 9)) % 2 == 0 ? 0.0 : 0.25
            func q(_ c: Double) -> UInt8 {
                UInt8(max(0, min(255, ((c * 0.75 + n * 0.15 + edge) * 255).rounded())))
            }
            return (q(r), q(g), q(b))
        default: return gray(0.5)
        }
    }

    /// Value noise on a 24-px lattice with bilinear interpolation.
    private static func noise(width: Int, height: Int, generator: inout SplitMix) -> (Int, Int) -> Double {
        let cell = 24
        let columns = width / cell + 2
        let rows = height / cell + 2
        let lattice = (0..<(columns * rows)).map { _ in generator.nextUnit() }
        return { x, y in
            let gx = Double(x) / Double(cell)
            let gy = Double(y) / Double(cell)
            let ix = Int(gx)
            let iy = Int(gy)
            let fx = gx - Double(ix)
            let fy = gy - Double(iy)
            let a = lattice[iy * columns + ix]
            let b = lattice[iy * columns + ix + 1]
            let c = lattice[(iy + 1) * columns + ix]
            let d = lattice[(iy + 1) * columns + ix + 1]
            return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
        }
    }
}

/// A small, fixed-algorithm generator so scenes never depend on the system's randomness.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
