---
status: pending
blocked-by: 0011
date: 2026-10-20
---

# 0015 — Analyzer findings triaged to fix, abstraction or accepted reason

Measured 2026-10-20 with dolly 0.10.2, deadwood 0.10.1, arcleak 0.10.2 and Aemi's SwiftLint config:

- arcleak: 0 findings in 38 files.
- dolly: 53 clone groups, 40 outside `Previews/`. Notable: the iOS and macOS filter accessors in
  `_VisualEffectInternals`, the five observer registrations in `BackdropCoordinatorRegistry`, the twin
  `updateMask`/`generate…Mask` pipelines in `AlphaMaskUIView` and `VariableBlurUIView`.
- deadwood: 16 — 9 public modifiers (false positives for a library), `markInFlight` (dead), 5 unused
  interned names, `_stride` reachable only from tests.
- SwiftLint: `large_tuple` (error) in `MetalCompilerTool.parseArguments`; type body length in
  `AemiSDRPreview`; 7-parameter functions ×4; 103-line `updateMask`; complexity 17 in `systemStyle`.

## What lands

Each finding ends as a fix, a named abstraction (likely: one mask pipeline shared by both views), or an
accept with a reason at the source. deadwood runs with public API as entry points before it gates.
