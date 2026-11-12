---
status: accepted
date: 2026-11-12
---

# 0009 — Blur is one backdrop-filter core, shared by both platforms

## Context

Sunset (a consumer) asked for a variable blur under its bars and a tuned backdrop blur for its panels, on macOS. AemiSDR's
`VariableBlurUIView` is iOS-only because it hangs `variableBlur` on a `UIVisualEffectView`; its macOS `BackdropBlurView` tunes an
`NSVisualEffectView`, which blurs what is behind the window, not what is under the view inside it. Probed on macOS 27.0.1
(diary 2026-11-12-01): `CAFilter` lists `variableBlur` and `gaussianBlur`; `CABackdropLayer` exists; both are in QuartzCore;
a `CABackdropLayer` with `variableBlur` and a mask blurs a live web page under it with a radius that falls to nothing.

## Decision

- The blur is described by a value, `BlurRecipe` (uniform or variable with a `BlurMask`, plus saturation and brightness),
  turned into a list of filter specifications by a pure function (`BlurFilterPlan`), then into `CAFilter`s on a
  `CABackdropLayer` by one main-actor type (`BlurBackdropLayer`). Every private class, selector and key goes through Abysm,
  typed and verified (ADR-0002), named by `_InternedKeys` (ADR-0003). A filter key is written only when the filter's own
  `inputKeys` lists it: `CAFilter` accepts unknown keys silently (probed), so a renamed key would otherwise be a no-op.
- An edge mask is expressed as fractions of the layer, so its image does not depend on the layer's size: it is made once per
  shape and a resize does no mask work. Probed: a 4 × 128 mask stretched to a 76 pt layer fades where the fractions say.
- Fallback, decided per view: private API off or a class missing → the system material; Reduce Transparency → an opaque fill.
- macOS gets the view first (`BlurBackdropView`). The iOS `VariableBlurUIView` keeps its public API and moves onto the core in
  a later slice (roadmap 0020), not in a big-bang rewrite.

## Consequences

- One place to audit for private filter use on both platforms; the canary covers the new entries.
- `BackdropBlurView` on macOS (tuning an `NSVisualEffectView`) stays: it blurs behind the window, a different effect.
