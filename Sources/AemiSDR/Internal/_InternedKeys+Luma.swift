import InternedStrings

extension _InternedKeys {
    /// iOS's `CAFilter` has no `-inputKeys`; this names a key's type, nil for a key the filter does not have (probed).
    @Interned static var keyTypeSelector = "CAMLTypeForKey:"
    /// The HDR range brought into SDR before a blur, as the system's materials do (diary 2026-11-28-01).
    @Interned static var dynamicRangeFilterID = "sdrNormalize"
    /// The identity filter a luma backdrop needs to be rendered, and so read (ADR-0010).
    @Interned static var identityFilterID = "colorMatrix"
    @Interned static var lumaChangeSelector = "backdropLayer:didChangeLuma:"

    /// The luma backdrop's flags (`(Bool) -> Void` setters); `windowServerAware` is macOS's only (absent on iOS 27.2).
    enum LumaFlag {
        @Interned static var tracks = "setTracksLuma:"
        @Interned static var enabled = "setEnabled:"
        @Interned static var filtered = "setAllowsFilteredLuma:"
        @Interned static var windowServerAware = "setWindowServerAware:"
    }

    /// The luma backdrop's values: seconds between readings (`Double`), the part read (`CGRect`).
    enum LumaValue {
        @Interned static var interval = "setLumaUpdateRate:"
        @Interned static var region = "setLumaSubrect:"
    }
}
