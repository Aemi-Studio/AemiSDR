---
status: in-progress
blocked-by:
date: 2026-10-20
---

# 0019 — Clear glass matches native clear glass, for any shape

The goal: a clear-glass style reproduces native `clear` Liquid Glass, measured locally at edges as well as globally in
Glass Lab, for any shape. Native fidelity and the owner's preferred blur/veil/fringing are separate objectives.
Work is ordered by what depends on what, because optics tuned against the wrong shape is wasted and a faster shader that is
about to be rewritten is wasted too.

## Measured start (2026-10-20, Glass Lab, native clear against the lens, similarity x 100 inside the shape's box)

The lens is **no better than leaving the background alone** (nothing / lens): capsule checker 46.8 / 30.9, square checker 40.6 / 15.2,
rrect(8) checker 39.8 / 13.0, square complex 86.9 / 75.5. Causes found: it has no blur and no tint, it distorts the whole
interior (native is undistorted beyond about 20 pt from the edge), it has no continuous corner, and a zero corner radius makes
starburst artifacts at the corners. It cannot express a triangle, mixed radii or a continuous curve at all.

Initial fit (superseded by diaries 14–15), square 200 pt, light mode: interior = Gaussian blur sigma about 2.7 px (0.9 pt) plus an additive lift
`32/255 * (1 - 0.9 * L)` (L: linear luminance of the input); rim band about 20 pt where content is sampled from further inside by
up to about 60 px, decaying to zero (fit still saturates at its bound; refit with a wider bound).

## Order

1. **Shape as a distance field** (everything below reads it). Analytic: continuous corner and per-corner radii from ADR-0007 in the clear shader; adopting it in the original lens and masks remains owed (0016, 0017).
2. **Arbitrary shapes.** Exact distance to flattened path segments, nonzero winding and unit gradients on the CPU; the raster EDT remains a fallback/reference. Test: a rounded-rectangle path renders like the analytic one.
3. **Clear-glass optics** on top: blur, lift, rim refraction, fitted against native, with the fitting script kept.
4. **Re-measure** the Glass Lab matrix and edge-local depth bands/off-axis sectors after each step. Use dots and lines as
   well as phase codes; print valid-code coverage and keep clipping/noise controls. An overall score cannot establish parity.
5. **Performance.** Harness and guard are in place (`ShaderPerformanceTests`, `LensBaselineEquivalenceTests`; method and results in diary 2026-10-20-12). Done: spectral sample reuse (about 8 to 10%, pixel-identical). Tried and dropped: closed-form refraction (no measurable gain). Next, after step 3 settles the shader's structure: fewer texture samples for chromatic variants, and a like-for-like comparison against Apple's `glass_background_*`. Every change must keep the baseline-equivalence test green and clear the control's spread.

## Deferred

CI (by the owner), regular/tinted/interactive styles and the CPU side that fills Apple's uniforms. A dynamic capture would
answer the latter; do not confuse a static shader formula with observed runtime uniforms.

## Earlier milestone (diary 13)

Done: the shape as a distance field (analytic with continuous corners and a radius per corner, verified against Apple's shader;
any path through an exact distance transform), the two-Gaussian blur, the tone, the ring outside the edge, the rim, a view
(`ClearGlassUIView`) and Glass Lab's `clear` mode; paired-tap blur (25 to 32% less GPU time). Similarity against native clear
glass over 8 shapes and 4 backgrounds: mean 92.8, min 88.1 (the old lens: about 30; doing nothing: about 52). ADR-0008, diary
2026-10-20-13.

## Current milestone (diary 15)

- Fixed the capsule's circular/continuous field mismatch at off-axis joins and replaced the approximate native rim with the
  AIR-observed circular arc (60 pt amplitude / 20 pt height inferred from captures). No blanket native-parity claim.
- Reproducible edge bands, 17/30/63/77-degree sectors on both ends/halves, dot/line feature diagnostics, and a tested phase
  decoder that cancels neutral rim light. Low-contrast codes retain 99–100% coverage instead of 44–48%.
- Low-contrast mean endpoint errors: 0.16 px for square/circle/capsule/rrect, 0.52 px for triangle. First 5 px: 0.45–0.56 px
  for analytic shapes, 3.24 px for triangle. Blur and rim-light colour errors remain visible despite good geometry.
- The 32-cell whole-box matrix moved 97.33 to 98.26 (minimum 92.53 to 96.86). This is secondary evidence, not the edge score.
- One-to-three Gaussian components with depth-dependent weights, veil colour/removal and optional fringing are implemented.
  Removed a merged-pass experiment that changed fractional displaced pixels by 5/255. Triangle blur reach covers displaced
  samples, including chromatic extremes, rather than leaving dark corner wedges.

Regression: `capsule optics use the native continuous field near off-axis joins`,
`the native rim profile follows the measured displacement to within a quarter pixel`,
`triangle corners preserve a uniform backdrop when the rim looks beyond the shape bounds`,
`paired blur taps preserve displaced textured sampling at fractional positions`.

Mixed-zero/per-corner GPU robustness is now guarded by `mixed sharp and rounded corners keep finite distances and unit
gradients` and `nonfinite corner radii become sharp finite corners` (diary 2026-10-22-01). The earlier all-zero-only guard
was insufficient.

Next, in dependency order: edge-local blur/rim-light colour and triangle residuals; the macOS native/custom tuning app; measured performance and scratch-memory budgets; live backdrop and SwiftUI wrapper;
original-lens corner adoption and the remaining review/proof tasks. CI stays last.

