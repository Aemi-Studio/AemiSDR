---
status: in-progress
blocked-by:
date: 2026-10-20
---

# 0019 — The lens and masks use the native glass geometry

ADR-0007 pins the native shape geometry against Apple's shader. The lens and the Core Image masks still use a circular
rounded box, so a capsule or a rounded rectangle differs from native glass at every corner.

## Plan (each step red first, against the oracle where it applies)

1. A shared Metal SDF with the continuous corner, a per-corner radius and a corner curve, used by `LiquidLens.metal` and `AemiSDR.ci.metal`.
2. `LiquidLensConfiguration` and the mask API gain a corner curve (`.circular`, `.continuous`) and four radii; a zero radius stays pointy (roadmap 0016, 0017).
3. Re-measure the Glass Lab similarity against native `UIGlassEffect` per shape, and record it.
4. The wedge-coverage and Lipschitz properties (0017, 0018) are re-checked for the new SDF.

## Open

The foreground highlight (`glass_foreground`) and the background pass (`glass_background_*`: refraction, blur, tint) are
decoded only in part. Who fills their uniforms from a `UIGlassEffect` is unknown and is the next REA question.
