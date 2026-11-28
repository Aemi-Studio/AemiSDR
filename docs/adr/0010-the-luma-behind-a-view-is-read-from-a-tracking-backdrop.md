---
status: accepted
date: 2026-11-28
---

# 0010 — The luma behind a view is read from a tracking backdrop

## Context

A consumer (Sunset) wants text to take a light or dark ink from what is actually behind it: its own window's layers, and on
macOS the windows and desktop behind a translucent window. The system does this for its own controls (iOS's status bar and
grabbers through UIKit's `_UILumaTrackingBackdropView` and `_UILumaTrackingGroup`; AppKit's scroll pockets; SwiftUI's glass),
from `CABackdropLayer`'s luma tracking: the renderer averages the luma of what the backdrop captured on the GPU
(`CA::OGL::update_backdrop_luma`, `calculate_average_luma`) and sends it to the app (`_XBackdropDidChangeLuma`), which calls
the layer's delegate with `-backdropLayer:didChangeLuma:`. Reading the screen another way (ScreenCaptureKit) needs a
permission and costs a capture.

Probed (diary 2026-11-28-01): a tracking layer reports only while the renderer draws it, so how it is set up decides
whether anything comes; and the setup that works on macOS works on iOS.

## Decision

- `BackdropLumaLayer` makes the tracking backdrop through Abysm, typed and verified (ADR-0002), names interned (ADR-0003):
  enabled, in a group, half scale, luma taken after its filter, one identity `colorMatrix`, opacity 0.01, and on macOS
  `windowServerAware` (iOS has no such method). Without any one of these the reports stall; at opacity 0.001, hidden, or
  capture-only, none come.
- `LumaDelegate` receives the reports. Its method's name is private, so it is added at run time under the interned
  selector with the system's encoding (`v32@0:8@16d24`), not declared with `@objc(…)`.
- `LumaSampler` holds the layer while its view is in a window, keeps the last luma and level, and puts a layer in again
  when it went silent for a few intervals (a healthy one reports every interval, a constant backdrop too).
- `LumaLevel.after` is the pure part: dark below a band, light above it, unchanged inside it, so text does not flicker.
- `BackdropLumaNSView` and `BackdropLumaUIView` are the public views: put behind a block of text, they draw nothing a
  person sees and take no touches.
- With private API off, or a name missing, nothing is made and `isAvailable` is false: the host keeps its scheme's ink.

## Consequences

- The value is the display's: Rec. 709 weights on gamma-encoded values in the display's colour space, in 64 steps. Hosts
  compare it with a band, not with a contrast ratio computed from it.
- An occluded window is not drawn, so it reports nothing; that is the right answer for text no one sees.
- A package's tests on iOS have no window scene, so nothing they draw is drawn: the live check on iOS is
  `Examples/LumaCheck`, whose tests run in an app.
