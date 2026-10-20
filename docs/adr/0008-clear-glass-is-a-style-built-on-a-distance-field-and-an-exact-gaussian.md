---
status: accepted
date: 2026-10-20
---

# 0008 — Clear glass is its own style, built on a distance field and exact Gaussians

## Context

Measured in Glass Lab against native `clear` Liquid Glass, the existing refracting lens was no better than leaving the
background alone (similarity inside the shape: capsule checker 30.9 against 46.8 for nothing, square checker 15.2 against
40.6). It distorts the whole interior, has no blur and no tint, has no continuous corner, makes starbursts at sharp corners
and cannot express a triangle, mixed radii or a continuous curve. Native clear glass is a different thing, not a tuning of
the lens: a soft blur of the whole interior, a tint that depends on what is behind it, and a thin rim band where the backdrop
is pulled in from further inside.

The owner also said Apple's blur is poor and asked for either a more accurate model or a good Gaussian.

## Decision

- **A separate style on its own pipeline** (`ClearGlass.metal`, `ClearGlassRenderer`, `ClearGlassUIView`). The lens, its
  configuration, its 112-byte uniform block and its proofs are untouched.
- **The shape is a signed distance and its gradient, and nothing else.** Analytic: a rounded rectangle with a radius per
  corner and a continuous or circular curve, the function verified against Apple's own shader (ADR-0007). Any shape: a path is
  rasterised and an exact Euclidean distance transform gives the field (Felzenszwalb and Huttenlocher), uploaded as a
  half-precision texture. One ring of virtual outside pixels makes a shape that fills its raster have an edge at the border.
- **The blur is two exact Gaussians, not one and not Apple's.** The kernel that best maps a plain background to native
  clear glass is not a Gaussian: weight 1.0 at the centre, 0.31 at one pixel, then a flat tail of about 0.05 out to eight
  pixels. That is a small blur plus a wide defocus halo, which is also why a single Gaussian cannot fit it (rms 0.0276
  against 0.0157 for two). The blur is therefore a tight core (21%, sigma 0.73 px) plus a wide halo (79%, sigma 4.2 px),
  each an exact separable Gaussian with weights normalised to sum to one and a radius of three sigma. The first pass computes
  both horizontal blurs at once, the second both vertical blurs and mixes them. A separable product of the mixed
  one-dimensional kernel would be cheaper and wrong: its cross terms are wide in one direction and narrow in the other and
  streak along the axes. No downsample chain, no box or disc plateau. `ClearGlassBlur.gaussian(_:)` gives a single Gaussian.
  The blur runs on display-encoded values: blurring in linear light fits far worse (rms 0.09 to 0.12).
- **The ring.** Native glass darkens what is just outside its edge by a constant, not a proportion (over grey and white it
  takes the same 77/255 at half a pixel out and 38/255 at a pixel and a half, at 3x), falling linearly to nothing at about
  2.5 px. The glass draws it by re-drawing the backdrop slightly darker, so the layer extends a margin beyond the shape.
- **Parameters come from a fit, kept in `Examples/GlassLab/Tools`**, against native captures over seven shapes at once:
  rim depth 27.9 pt, rim width 9.1 pt (a Gaussian profile; a free-form profile and a refraction-model profile did not beat
  it), lift 0.122, falloff 0.57, rms error 0.0118 against 0.123 for doing nothing. Continuous corners fit slightly better than circular (rms 0.01183 against 0.01210), so UIKit's
  `uniformCorners` is continuous.

## Verification

Geometry: the kernel sums to one and follows the Gaussian; the transform equals the exhaustive distance on random masks (and
fails when the half-pixel offset or the transform is broken); the production shape function equals the verified reference,
distance and gradient (and fails when the extent or a gradient sign changes). Rendering: a blurred impulse is the exact
Gaussian; flat colours come out as measured on native glass (black 32, grey 154, red 255/26/26, ...); the rim pulls from inside
on both sides and leaves the interior alone (fails when the sign flips); a rounded-rectangle path draws what the analytic
shape draws. Every claim above was shown to fail on a mutation.

## Consequences and limits

- Fitted on the light appearance only. Dark mode, tinted and interactive variants are not measured.
- The rim profile is fitted on a few shapes and backgrounds; near the very edge (3 to 15 px in) the native sampling is
  steeper than any model tried, and that band carries the largest share of the remaining error.
- The path field is exact to half a pixel; the gradient comes from finite differences of the texture.
- `ClearGlassUIView` asks for a drawable on the main thread, which roadmap 0005 records as a hazard; per-frame cost is not yet
  measured.
