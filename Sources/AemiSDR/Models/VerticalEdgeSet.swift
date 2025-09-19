//
//  VerticalEdgeSet.swift
//  AemiSDR
//
// Created by Gigi on 20.09.25.
//

// MARK: - Vertical Edge Set

/**
 * An option set that represents vertical edges of a view.
 *
 * `VerticalEdgeSet` provides a way to specify which vertical edges
 * (top and bottom) should be affected by view modifiers such as
 * masking or blurring effects.
 *
 * Example usage:
 * ```swift
 * view.verticalEdgeMask(edges: [.top, .bottom])
 * view.verticalEdgeMask(edges: .top)
 * view.verticalEdgeMask(edges: .all)
 * ```
 */
public struct VerticalEdgeSet: OptionSet, Sendable, Equatable, Hashable {
    public let rawValue: Int

    /**
     * Creates a new vertical edge set with the given raw value.
     *
     * - Parameter rawValue: The raw value for the edge set
     */
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Represents the top edge
    public static let top = VerticalEdgeSet(rawValue: 1 << 0)

    /// Represents the bottom edge
    public static let bottom = VerticalEdgeSet(rawValue: 1 << 1)

    /// Represents both top and bottom edges
    public static let all: VerticalEdgeSet = [.top, .bottom]
}
