import Abysm
import QuartzCore

/// A `CABackdropLayer` (QuartzCore, private) that tracks the luma of what is under it, down to the windows and
/// desktop behind its window on macOS (ADR-0010). Probed on macOS 27.2 (diary 2026-11-28-01): the renderer reports
/// luma only for a backdrop it renders, so the layer is enabled, in a group, half scale, with luma taken after its
/// filter, one identity filter, and opacity 0.01 (nearly nothing of a copy of what is already there; at 0.001,
/// hidden or capture-only, no luma comes). Every setter goes through Abysm, typed and checked (ADR-0002);
/// `windowServerAware` is macOS's only (iOS 27.2's layer has no such method) and is applied where it resolves.
@MainActor
final class BackdropLumaLayer {
    let layer: CALayer
    /// The layer's delegate: a layer holds its delegate weakly, so this keeps it.
    private let reporter: LumaDelegate
    private let setTracks: (CALayer, Bool) throws(RuntimeError) -> Void
    private let setInterval: (CALayer, Double) throws(RuntimeError) -> Void
    private let setRegion: (CALayer, CGRect) throws(RuntimeError) -> Void

    /// The opacity that keeps the renderer drawing it (and so reporting) while showing nearly nothing of it.
    static let opacity: Float = 0.01
    /// The scale the system's own luma backdrops capture at.
    static let captureScale = 0.5

    private init(
        layer: CALayer,
        reporter: LumaDelegate,
        setTracks: @escaping (CALayer, Bool) throws(RuntimeError) -> Void,
        setInterval: @escaping (CALayer, Double) throws(RuntimeError) -> Void,
        setRegion: @escaping (CALayer, CGRect) throws(RuntimeError) -> Void
    ) {
        self.layer = layer
        self.reporter = reporter
        self.setTracks = setTracks
        self.setInterval = setInterval
        self.setRegion = setRegion
    }

    /// A tracking layer reporting to `report`, or nil when private API is off or a class, setter or filter does not
    /// resolve. `groupName` names the capture it shares with other backdrops (one is made up when nil).
    static func make(groupName: String? = nil, report: @escaping @MainActor @Sendable (Double) -> Void)
        -> BackdropLumaLayer?
    {
        guard let backdrop = BackdropLayerClass(),
            let tracks = backdrop.flag(_InternedKeys.LumaFlag.tracks),
            let enabled = backdrop.flag(_InternedKeys.LumaFlag.enabled),
            let filtered = backdrop.flag(_InternedKeys.LumaFlag.filtered),
            let interval = try? backdrop.runtime.action(
                _InternedKeys.LumaValue.interval, as: ((Double) -> Void).self),
            let region = try? backdrop.runtime.action(
                _InternedKeys.LumaValue.region, as: ((CGRect) -> Void).self),
            let identity = BlurFilterFactory.make(BlurFilterSpec(type: _InternedKeys.identityFilterID, values: []))
        else {
            _PrivateAPIDiagnostics.logOnce(
                key: "backdropLumaLayer", "CABackdropLayer luma unavailable; no luma reported.")
            return nil
        }
        let layer = backdrop.type.init()
        do {
            try enabled(layer, true)
            try filtered(layer, true)
            try backdrop.setScale(layer, captureScale)
            try backdrop.setGroupName(
                layer, groupName ?? "AemiSDR.luma.\(UInt(bitPattern: ObjectIdentifier(layer).hashValue))")
        } catch {
            return nil
        }
        // macOS only: iOS's layer has no such method.
        try? backdrop.flag(_InternedKeys.LumaFlag.windowServerAware)?(layer, true)
        layer.filters = [identity]
        layer.opacity = opacity
        let reporter = LumaDelegate(report: report)
        layer.delegate = reporter
        return BackdropLumaLayer(
            layer: layer,
            reporter: reporter,
            setTracks: tracks,
            setInterval: { (layer: CALayer, seconds: Double) throws(RuntimeError) in try interval(on: layer, seconds) },
            setRegion: { (layer: CALayer, rect: CGRect) throws(RuntimeError) in try region(on: layer, rect) }
        )
    }

    /// Starts or stops the reports.
    func track(_ tracking: Bool) {
        try? setTracks(layer, tracking)
    }

    /// Seconds between two readings (the system's default is 0.25).
    func setInterval(_ seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        try? setInterval(layer, seconds)
    }

    /// The part of the layer the luma is read over, in its own points; `.zero` is the whole layer.
    func setRegion(_ rect: CGRect) {
        try? setRegion(layer, rect.isNull || rect.isInfinite ? .zero : rect)
    }
}
