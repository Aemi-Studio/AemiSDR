---
status: accepted
date: 2026-10-20
---

# 0005 — Display corners are read per corner, and the scalar is the largest of them

## Context

`UIScreen.displayCornerRadius` was one number, read with `value(forKey:)`. Probed (diary 2026-10-20-02): on the iPhone Duo
(iOS 27.2 simulator) the scalar APIs say 59 while the scene's corner configuration says 8 / 59 / 8 / 59, so a scalar rounds
the two hinge-side corners that the hardware leaves nearly square. The old read also raised on a missing key, and returned 0
rather than the estimate when the key was gone.

## Decision

- `DisplayCornerRadii` (topLeft, topRight, bottomLeft, bottomRight) is the public type. Corners are physical, as the system
  reports them; no remapping on rotation, because it could not be probed.
- Source order: `UIApplicationSceneSettings.cornerRadiusConfiguration` (reached as `UIWindowScene._FBSScene.settings`), then
  `UITraitCollection.displayCornerRadius`, then `UIScreen._displayCornerRadius`, then the idiom estimate. A negative or
  non-numeric value is not believed and the next source is tried.
- `displayCornerRadius` stays, and is the largest corner: equal to the system's scalar on every display probed (62, 59).
- Every private read goes through Abysm: signature checked, `nil` instead of `NSUnknownKeyException`.
- The choice among sources is a pure function, tested with the Duo's values on any machine; the reading is tested live.

## Consequences

- `VariableBlurUIView` and `AlphaMaskUIView` still take one `cornerRadius`: the largest corner, which over-rounds the Duo's
  hinge side. Per-corner masks need the shaders to take four radii (roadmap 0016).
- Depends on a pinned revision of [g-cqd/Abysm](https://github.com/g-cqd/Abysm), published separately under MIT.
- `UIScreen._exclusionArea` (the camera cutout rect), `UIWindow._safeAreaCornerInsets` and the new public hinge / reserved-region
  API (iOS 27.1) are related display-shape data; none is used yet.
