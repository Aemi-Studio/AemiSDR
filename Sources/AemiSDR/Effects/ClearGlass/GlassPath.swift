import CoreGraphics

/// An owned, immutable path snapshot. Construct it on the executor that owns a mutable input path.
///
/// No mutable alias to the stored copy escapes. Exporting a path makes another independent copy, so configurations
/// can safely cross render executors and callers can continue editing their original paths.
public struct GlassPath: Equatable, @unchecked Sendable {
    private let storage: CGPath

    /// Copies the input's elements; later edits of the input cannot alter this value.
    /// - Complexity: O(number of path elements).
    public init(_ path: CGPath) {
        let copy = CGMutablePath()
        copy.addPath(path)
        storage = copy
    }

    /// An independent mutable Core Graphics path for use by other drawing APIs.
    /// - Complexity: O(number of path elements).
    public func copyCGPath() -> CGMutablePath {
        let copy = CGMutablePath()
        copy.addPath(storage)
        return copy
    }

    /// Read-only inside the renderer; never cast to a mutable path or expose outside the module.
    var value: CGPath { storage }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.storage == rhs.storage }
}
