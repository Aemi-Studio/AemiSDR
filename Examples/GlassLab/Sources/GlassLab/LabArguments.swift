import CoreGraphics
import Foundation

/// A fully deterministic description of one lab scene, read from launch arguments (`--key value`).
///
/// The same arguments always produce the same pixels, so a capture of native glass and a capture of the AemiSDR
/// lens differ only in the effect under test.
struct LabArguments {
    /// `none`, `native` (UIGlassEffect) or `aemi` (LiquidLensUIView).
    var mode = "native"
    /// Background pattern name; see `LabBackground`.
    var background = "dots"
    /// `capsule`, `circle`, `rrect` (uses `radius`).
    var shape = "capsule"
    var width: CGFloat = 300
    var height: CGFloat = 120
    /// Shape centre in points; nil means the screen centre.
    var centerX: CGFloat?
    var centerY: CGFloat?
    var radius: CGFloat = 32
    /// `regular` or `clear` (native only).
    var style = "regular"
    var dark = false
    /// Tunables for the AemiSDR lens, so a search can drive them from outside.
    var parameters: [String: Double] = [:]

    init(_ arguments: [String]) {
        var index = 1
        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--"), index + 1 < arguments.count else {
                index += 1
                continue
            }
            let value = arguments[index + 1]
            switch key {
            case "--mode": mode = value
            case "--bg": background = value
            case "--shape": shape = value
            case "--w": width = CGFloat(Double(value) ?? 300)
            case "--h": height = CGFloat(Double(value) ?? 120)
            case "--cx": centerX = Double(value).map { CGFloat($0) }
            case "--cy": centerY = Double(value).map { CGFloat($0) }
            case "--radius": radius = CGFloat(Double(value) ?? 32)
            case "--style": style = value
            case "--dark": dark = value == "1"
            default:
                if key.hasPrefix("--p-"), let number = Double(value) {
                    parameters[String(key.dropFirst(4))] = number
                }
            }
            index += 2
        }
    }
}
