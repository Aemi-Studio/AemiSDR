import Foundation

/// Whether what is behind a view reads as dark or light, from its luma (ADR-0010): the level a sampler reports, with
/// room between the two boundaries so that a luma near the middle does not make text flicker between two inks.
public enum LumaLevel: Sendable, Equatable {
    case dark
    case light

    /// The level for `luma` (0 black to 1 white), given the level before (nil: none yet). Below `boundaries.lower` it
    /// is dark, above `boundaries.upper` light; between them it stays what it was, or, with none before, is taken at
    /// the middle of the two.
    public static func after(
        _ previous: Self?, luma: Double, boundaries: ClosedRange<Double> = defaultBoundaries
    ) -> Self {
        guard luma.isFinite else { return previous ?? .dark }
        if luma < boundaries.lowerBound { return .dark }
        if luma > boundaries.upperBound { return .light }
        if let previous { return previous }
        return luma < (boundaries.lowerBound + boundaries.upperBound) / 2 ? .dark : .light
    }

    /// The default band: luma is reported in 64 steps (diary 2026-11-28-01), so the band spans several of them on
    /// either side of the middle.
    public static let defaultBoundaries: ClosedRange<Double> = 0.4...0.6
}
