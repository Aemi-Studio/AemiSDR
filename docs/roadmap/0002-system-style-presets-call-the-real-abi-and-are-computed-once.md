---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0002 — System style presets call the real ABI, map styles, and are computed once

`BackdropBlurConfiguration.systemStyle(_:)` passes `style.rawValue` through `perform(_:with:)` to a
selector that takes `NSInteger` (`@24@0:8q16`). Probed on the iOS 18.6 and 27.0 simulators: every
style returns `_UIBackdropViewSettingsUltraLight` (radius 20). Through a typed IMP, 0/1/2 return
Light (30) / Dark (20) / Blur (30); 4, 6, 10 are "unsupported style constant" even then, because
`UIBlurEffect.Style` raw values are not backdrop-settings constants.

Each named preset is a computed `static var`: on iOS it calls private API on every access; on macOS it
builds, lays out and displays an `NSVisualEffectView` on every access.

## Probes

- Enumerate the `_UIBackdropViewSettings` constants that return a non-fallback class on both runtimes;
  record the table with build numbers in the diary.
- Red test (simulator): `.light` and `.dark` produce different configurations.
- Cost of one preset access before and after caching.

## What lands

A typed call through the registry (roadmap 0001), a `UIBlurEffect.Style` → settings-constant table built
from the probe, a public-API fallback for styles with no constant, presets cached per appearance.
Release note: presets change visibly, because they were all identical.
