#if os(macOS)
    import AppKit

    /// The platform's view, for the one luma view both platforms share.
    public typealias BackdropLumaPlatformView = NSView
    /// The luma view by the name AppKit code expects.
    public typealias BackdropLumaNSView = BackdropLumaView
#else
    import UIKit

    public typealias BackdropLumaPlatformView = UIView
    /// The luma view by the name UIKit code expects.
    public typealias BackdropLumaUIView = BackdropLumaView
#endif

/// A view that reads the luma of what is under it: its window's own layers and, on macOS, the windows and desktop
/// behind a translucent window (ADR-0010). Put it behind a block of text, the size of the block; it draws nothing a
/// person sees and takes no clicks or touches. Readings come every `interval` seconds while it is in a window that is
/// drawn (an occluded one gives none); `onLevel` says when the text should change ink.
public final class BackdropLumaView: BackdropLumaPlatformView {
    private let sampler: LumaSampler

    /// Every reading, 0 (black) to 1 (white): Rec. 709 weights on the display's gamma-encoded values, in 64 steps.
    public var onLuma: ((Double) -> Void)? {
        get { sampler.onLuma }
        set { sampler.onLuma = newValue }
    }
    /// Each change between dark and light, past `boundaries`.
    public var onLevel: ((LumaLevel) -> Void)? {
        get { sampler.onLevel }
        set { sampler.onLevel = newValue }
    }
    public var boundaries: ClosedRange<Double> {
        get { sampler.boundaries }
        set { sampler.boundaries = newValue }
    }
    /// Seconds between readings.
    public var interval: Double {
        get { sampler.interval }
        set { sampler.interval = newValue }
    }
    /// The part of the view read, in its own points; `.zero` is all of it.
    public var region: CGRect {
        get { sampler.region }
        set { sampler.region = newValue }
    }
    public var luma: Double? { sampler.luma }
    public var level: LumaLevel? { sampler.level }
    /// False without private API: no reading will come.
    public var isAvailable: Bool { sampler.isAvailable }

    /// `groupName`: backdrops with the same one share a capture.
    public init(frame: CGRect = .zero, groupName: String? = nil) {
        sampler = LumaSampler(groupName: groupName)
        super.init(frame: frame)
        #if os(macOS)
            wantsLayer = true
        #else
            isUserInteractionEnabled = false
        #endif
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }

    #if os(macOS)
        override public func hitTest(_ point: NSPoint) -> NSView? { nil }

        override public func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            windowChanged()
        }

        override public func layout() {
            super.layout()
            sampler.resize(to: bounds)
        }
    #else
        override public func didMoveToWindow() {
            super.didMoveToWindow()
            windowChanged()
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            sampler.resize(to: bounds)
        }
    #endif

    private func windowChanged() {
        sampler.attach(to: window == nil ? nil : layer, bounds: bounds)
    }

    /// Test seam: how many times in a row a silent layer was put in again.
    var kicks: Int { sampler.kicks }

    /// Test seam: a reading as the renderer would give it.
    func receive(_ luma: Double) { sampler.receive(luma) }
}
