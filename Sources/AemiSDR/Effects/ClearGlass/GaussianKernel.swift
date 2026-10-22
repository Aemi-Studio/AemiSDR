//
//  GaussianKernel.swift
//  AemiSDR
//
//  The weights of one separable Gaussian pass. Exact, normalised so the whole kernel sums to one (a brightness-neutral
//  blur). Nominal reach is three sigma on each side (tail below 1.2% of the peak), capped at `maximumRadius`.
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
        // Non-finite input is effectively identity. Clamp the radius BEFORE integer conversion: even a finite sigma
        // can overflow when multiplied by three, and converting infinity or NaN to Int traps.
        let safe = sigma.isFinite ? max(sigma, 0.05) : 0.05
        let radius = Int(min(Float(Self.maximumRadius), max(1, (3 * safe).rounded(.up))))
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

    /// The same kernel as fewer texture fetches. Two neighbouring taps `i` and `i + 1` with weights `a` and `b` are the
    /// same as one fetch of a bilinear sample at `(i * a + (i + 1) * b) / (a + b)` with weight `a + b`: the filtering
    /// hardware does the interpolation. Entry 0 is the centre tap (offset 0); the rest are the paired taps, one side of the
    /// kernel (the other side is the mirror image). The zeroth moment (the sum) and the first moment are preserved exactly.
    var pairedTaps: [SIMD2<Float>] {
        var taps = [SIMD2<Float>(0, weights[0])]
        var index = 1
        while index <= radius {
            if index + 1 <= radius {
                let (a, b) = (weights[index], weights[index + 1])
                taps.append(SIMD2((Float(index) * a + Float(index + 1) * b) / (a + b), a + b))
                index += 2
            } else {
                taps.append(SIMD2(Float(index), weights[index]))
                index += 1
            }
        }
        return taps
    }

    /// One fetch per texel, the same layout as `pairedTaps`: the baseline the paired form is measured against.
    var plainTaps: [SIMD2<Float>] {
        [SIMD2<Float>(0, weights[0])] + (1...radius).map { SIMD2(Float($0), weights[$0]) }
    }
}
