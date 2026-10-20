---
status: in-progress
blocked-by:
date: 2026-10-20
---

# 0019 — Clear glass matches native clear glass, for any shape

The goal: the lens reproduces native `clear` Liquid Glass, measured by bitmap similarity in Glass Lab, for any shape.
Work is ordered by what depends on what, because optics tuned against the wrong shape is wasted and a faster shader that is
about to be rewritten is wasted too.

## Measured start (2026-10-20, Glass Lab, native clear against the lens, similarity x 100 inside the shape's box)

The lens is **no better than leaving the background alone** (nothing / lens): capsule checker 46.8 / 30.9, square checker 40.6 / 15.2,
rrect(8) checker 39.8 / 13.0, square complex 86.9 / 75.5. Causes found: it has no blur and no tint, it distorts the whole
interior (native is undistorted beyond about 20 pt from the edge), it has no continuous corner, and a zero corner radius makes
starburst artifacts at the corners. It cannot express a triangle, mixed radii or a continuous curve at all.

Native clear, measured (square 200 pt, light mode): interior = Gaussian blur sigma about 2.7 px (0.9 pt) plus an additive lift
`32/255 * (1 - 0.9 * L)` (L: linear luminance of the input); rim band about 20 pt where content is sampled from further inside by
up to about 60 px, decaying to zero (fit still saturates at its bound; refit with a wider bound).

## Order

1. **Shape as a distance field** (everything below reads it). Analytic: continuous corner and per-corner radii from ADR-0007, one shader function shared by the lens and the masks; a zero radius stays pointy (0016, 0017).
2. **Arbitrary shapes.** The same interface fed from a path: rasterise, exact Euclidean distance transform on the CPU (O(n), once per shape/size), sampled as a texture with a gradient. Test: a path of a rounded rectangle renders the same as the analytic one.
3. **Clear-glass optics** on top: blur, lift, rim refraction, fitted against native, with the fitting script kept.
4. **Re-measure** the Glass Lab matrix per shape after each step and record it; stop when the target similarity is reached or the remaining gap is explained.
5. **Performance.** Harness and guard are in place (`ShaderPerformanceTests`, `LensBaselineEquivalenceTests`; method and results in diary 2026-10-20-12). Done: spectral sample reuse (about 8 to 10%, pixel-identical). Tried and dropped: closed-form refraction (no measurable gain). Next, after step 3 settles the shader's structure: fewer texture samples for chromatic variants, and a like-for-like comparison against Apple's `glass_background_*`. Every change must keep the baseline-equivalence test green and clear the control's spread.

## Not on this path yet

CI (deferred by the owner), the foreground highlight and the background pass beyond what clear glass needs, and the CPU side
that fills Apple's uniforms (a dynamic capture would answer it; revisit only if the fit stalls).

## Status (2026-10-20, end of the session)

Done: the shape as a distance field (analytic with continuous corners and a radius per corner, verified against Apple's shader;
any path through an exact distance transform), the two-Gaussian blur, the tone, the ring outside the edge, the rim, a view
(`ClearGlassUIView`) and Glass Lab's `clear` mode; paired-tap blur (25 to 32% less GPU time). Similarity against native clear
glass over 8 shapes and 4 backgrounds: mean 92.8, min 88.1 (the old lens: about 30; doing nothing: about 52). ADR-0008, diary
2026-10-20-13.

Not done, in the order they matter: (1) the rim band 3 to 15 px inside the edge, 41 to 55% of what is left; (2) the live
backdrop (`ClearGlassUIView` takes a still image; the lens's capture coordinator is not wired in); (3) a SwiftUI wrapper;
(4) regular, tinted and interactive glass; (5) the wide halo at half resolution; (6) the roadmap 0016 corner API on the lens.

