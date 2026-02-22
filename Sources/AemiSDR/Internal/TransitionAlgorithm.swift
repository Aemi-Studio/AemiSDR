//
//  TransitionAlgorithm.swift
//  AemiSDR
//

/// Defines the transition algorithm for mask transitions.
/// Used to select between linear and eased transformations.
public enum TransitionAlgorithm: Sendable, Equatable, Hashable, CaseIterable {
    /// Linear transformation.
    case linear

    /// Eased (smooth) transformation.
    case eased
}
