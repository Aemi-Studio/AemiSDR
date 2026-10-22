import CoreGraphics

extension ClearGlassRim {
    /// Bounds refraction by the component's geometry, for every shape including paths.
    ///
    /// Height and Gaussian width cannot exceed half the shorter component dimension. The total absolute pull of any
    /// colour channel is bounded by that same half-size, preserving the requested sign and relative component weights.
    /// Circular arcs therefore reach zero no later than the centre of the shorter dimension. This bounding-box rule
    /// does not claim to compute the local thickness of every branch of a concave path.
    public func constrained(to size: CGSize, chromatic: CGFloat = 0) -> ClearGlassRim {
        let half = min(size.width, size.height) / 2
        guard half.isFinite, half > 0, chromatic.isFinite,
            edgeDepth.isFinite, edgeFalloff.isFinite, bodyDepth.isFinite, bodyWidth.isFinite
        else { return .none }
        var result = self
        result.edgeFalloff = min(half, max(edgeFalloff, 0.001))
        result.bodyWidth = min(half, max(abs(bodyWidth), 0.001))
        let edge = abs(edgeDepth)
        let body = profile == .circularArc ? 0 : abs(bodyDepth)
        let largest = max(edge, body)
        if largest > 0 {
            let colourFactor = max(abs(1 - chromatic), abs(1 + chromatic))
            let budget = half / colourFactor
            // Normalize first so the sum cannot overflow for large finite requested amplitudes.
            let factor = min(1, (budget / largest) / (edge / largest + body / largest))
            result.edgeDepth *= factor
            result.bodyDepth *= factor
        }
        return result
    }
}
