//
//  HorizontalEdgeSet.swift
//  AemiSDR
//
// Created by Gigi on 20.09.25.
//

// MARK: - Horizontal Edge Set

/**
 * An option set that represents horizontal edges of a view.
 *
 * `HorizontalEdgeSet` provides a way to specify which horizontal edges
 * (leading and trailing) should be affected by view modifiers such as
 * masking or blurring effects.
 *
 * Example usage:
 * ```swift
 * view.horizontalEdgeMask(edges: [.leading, .trailing])
 * view.horizontalEdgeMask(edges: .leading)
 * view.horizontalEdgeMask(edges: .all)
 * ```
 */
public struct HorizontalEdgeSet: OptionSet, Sendable, Equatable, Hashable {
    public let rawValue: Int

    /**
     * Creates a new horizontal edge set with the given raw value.
     *
     * - Parameter rawValue: The raw value for the edge set
     */
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Represents the leading (left in LTR, right in RTL) edge
    public static let leading = HorizontalEdgeSet(rawValue: 1 << 0)

    /// Represents the trailing (right in LTR, left in RTL) edge
    public static let trailing = HorizontalEdgeSet(rawValue: 1 << 1)

    /// Represents both leading and trailing edges
    public static let all: HorizontalEdgeSet = [.leading, .trailing]
}
