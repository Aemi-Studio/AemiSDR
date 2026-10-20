//
//  GaussianKernel.swift
//  AemiSDR
//
//  The weights of one separable Gaussian pass. Exact, normalised so the whole kernel sums to one (a brightness-neutral
//  blur), and wide enough (three sigma on each side) that the truncated tail is below 1.2% of the peak.
//

import Foundation

struct GaussianKernel: Equatable {
    /// Taps on each side of the centre.
    let radius: Int
    /// `weights[0]` is the centre tap; `weights[i]` is the tap at distance `i` on either side.
    let weights: [Float]

    /// The most taps a pass will take on each side: a larger sigma is clamped rather than made unboundedly expensive.
    static let maximumRadius = 32

    init(sigma: Float) {
        let safe = max(sigma, 0.05)
        let radius = min(Self.maximumRadius, max(1, Int((3 * safe).rounded(.up))))
        var raw = (0...radius).map { index -> Double in
            let x = Double(index)
            return exp(-x * x / (2 * Double(safe) * Double(safe)))
        }
        // Normalise over the whole symmetric kernel: the centre once, every other tap twice.
        let total = raw[0] + 2 * raw.dropFirst().reduce(0, +)
        raw = raw.map { $0 / total }
        self.radius = radius
        weights = raw.map { Float($0) }
    }
}
