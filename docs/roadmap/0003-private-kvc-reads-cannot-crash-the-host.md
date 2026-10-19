---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0003 — Private KVC reads cannot crash the host

`UIScreen.displayCornerRadius` is `value(forKey: "_displayCornerRadius")` with no check, and is the
default argument of `VariableBlurUIView.init` and `AlphaMaskUIView.init`. Probed: a missing key raises
`NSUnknownKeyException`, so a rename crashes every host at view creation. The `requestedValues` setter
on `NSObject` raises the same way when the receiver is not a `_UIVisualEffectFilterEntry`.

Also here: `UIScreen.activeScreen` sorts every connected scene on each call and falls back to the
deprecated `UIScreen.main`; the `@available(iOS 13.0, tvOS 13.0, *)` annotations are below the floor.

## Probes

- Red test: the corner-radius read on an object without the getter returns the fallback, not a throw.
- `_displayCornerRadius` encoding `d16@0:8` on both runtimes (already recorded); call it through a
  typed IMP rather than KVC, which also removes the `NSNumber` box.

## What lands

Checked reads for every private KVC get/set (through the registry once it exists; a `responds(to:)`
guard before then), and a corner-radius default that cannot throw.
