import Foundation
import QuartzCore

/// What a luma view does on both platforms (ADR-0010): it holds a tracking backdrop while it is in a window, reports
/// each luma and each change of level, and keeps the last of both. Without private API (policy off, a class missing) it
/// reports nothing and `isAvailable` is false; the host then picks its ink from the colour scheme.
@MainActor
final class LumaSampler {
    private(set) var tracker: BackdropLumaLayer?
    private(set) var luma: Double?
    private(set) var level: LumaLevel?
    var boundaries = LumaLevel.defaultBoundaries
    var onLuma: ((Double) -> Void)?
    var onLevel: ((LumaLevel) -> Void)?
    var interval = 0.25 {
        didSet { tracker?.setInterval(interval) }
    }
    var region = CGRect.zero {
        didSet { tracker?.setRegion(region) }
    }
    let groupName: String?
    /// Readings since the last kick, and the kicks given in a row to a layer that went silent.
    private var readings = 0
    private(set) var kicks = 0
    private var watchdog: Task<Void, Never>?
    /// A tracking layer reports every interval while the renderer draws it, a constant backdrop too (probed); sometimes
    /// it stops, at its start or later (one run in about eight in the tests). Put in again, it reports again. After
    /// this many kicks in a row with nothing back, it is left as it is.
    static let maximumKicks = 5

    init(groupName: String?) {
        self.groupName = groupName
    }

    var isAvailable: Bool { tracker != nil }

    /// Makes the backdrop (once) and puts it in `host` under everything else, tracking; or takes it out.
    func attach(to host: CALayer?, bounds: CGRect) {
        guard let host else {
            watchdog?.cancel()
            tracker?.track(false)
            tracker?.layer.removeFromSuperlayer()
            return
        }
        attachLayer(to: host, bounds: bounds)
        readings = 0
        kicks = 0
        watch()
    }

    private func attachLayer(to host: CALayer, bounds: CGRect) {
        if tracker == nil {
            tracker = BackdropLumaLayer.make(groupName: groupName) { [weak self] luma in self?.receive(luma) }
            tracker?.setInterval(interval)
            tracker?.setRegion(region)
        }
        guard let tracker else { return }
        if tracker.layer.superlayer !== host { host.insertSublayer(tracker.layer, at: 0) }
        resize(to: bounds)
        tracker.track(true)
        CATransaction.flush()
    }

    /// Every few intervals: a layer that sent nothing since the last look is put in again.
    private func watch() {
        watchdog?.cancel()
        let wait = max(0.5, interval * 4)
        watchdog = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(wait))
                guard let self, !Task.isCancelled else { return }
                if readings == 0 { kick() } else { kicks = 0 }
                readings = 0
            }
        }
    }

    /// The silent layer put in again.
    private func kick() {
        guard kicks < Self.maximumKicks, let tracker, let host = tracker.layer.superlayer else { return }
        kicks += 1
        tracker.track(false)
        tracker.layer.removeFromSuperlayer()
        CATransaction.flush()
        attachLayer(to: host, bounds: tracker.layer.frame)
    }

    func resize(to bounds: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tracker?.layer.frame = bounds
        CATransaction.commit()
    }

    /// A reading: kept, reported, and the level moved when it crosses its band.
    func receive(_ value: Double) {
        guard value.isFinite else { return }
        readings += 1
        luma = value
        onLuma?(value)
        let next = LumaLevel.after(level, luma: value, boundaries: boundaries)
        if next != level {
            level = next
            onLevel?(next)
        }
    }
}
