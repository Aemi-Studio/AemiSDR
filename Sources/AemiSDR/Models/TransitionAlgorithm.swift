//
//  TransitionAlgorithm.swift
//  AemiSDR
//
// Created by Gigi on 20.09.25.
//

/// Defines the transition algorithm for mask transitions.
/// Used to select between linear and eased transformations.
public enum TransitionAlgorithm: Sendable, Equatable, Hashable, CaseIterable {
    /// Linear transformation.
    case linear

    /// Eased (smooth) transformation.
    case eased
}
