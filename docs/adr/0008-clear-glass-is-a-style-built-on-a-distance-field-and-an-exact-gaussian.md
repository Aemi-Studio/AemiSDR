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
- **The rim** pulls the backdrop from further inside along the inward normal, by a function of depth alone. Measured with a
  position-coded background (a sinusoid whose phase survives blur and an additive lift, decoded after inverting the tone;
  Glass Lab's `deformation.py`), the pull is the same for a square, a capsule, a circle, a rounded rectangle and a triangle to
  within 1 or 2 px, and purely inward (tangential component 0). It is `a * exp(-d / b) + c * exp(-(d / w)^2)`: a sharp
  exponential spike at the edge plus a broad Gaussian body (29.1 pt over 2.5 pt, and 21.4 pt over 9.6 pt), rms 0.62 px
  against the measured profile. A single Gaussian, which the first versions used, is 6 px rms and 25 px at worst off.
- **The tone** adds `lift * (1 - falloff * L)` in display space, where `L` is the linear luminance of the blurred backdrop:
  lift 32/255 and falloff 0.83, which give the flat colours exactly (black 32, grey 154, green 13, ...).
- **The ring and the rim light depend on the direction of the edge.** Native glass darkens a ring just outside the edge by a
  constant (77/255 at half a pixel out, 38/255 at a pixel and a half), but only where the edge faces left or right: it
  follows `n.x^2` and is absent on the top and bottom edges. Inside the edge it adds a bright stroke of light that does the
  opposite: strongest where the edge faces up or down (about 0.37 of full scale at the edge over half a point, `|n.y|^1.4`,
  plus a soft tail of 0.14 over 1.75 pt concentrated on the horizontal edges, `|n.y|^10`), absent on the left and right
  edges, and rising with the backdrop (factor 1 + 1.43 luma). The glass draws the ring by re-drawing the backdrop darker, so
  the layer extends a margin beyond the shape. Both were measured on a circle, which contains every edge direction.
- **No chromatic aberration.** Apple's glass shaders contain aberration code (`aberration_amount`, `aberration_dir`,
  `aberration_height`, `aberrate_textureN` in all eight variants), but inside native `clear` glass the three channels of a
  gray-coded background are identical to 0.07 levels of 255 at every depth, so it is off for this style. Our clear glass has
  none and the comparisons ignore it. It will be an optional per-channel term, off by default.
- **Exact path fields.** A path is flattened to segments and the distance is measured to the nearest one, with the gradient
  the unit direction to the nearest point and the sign from the winding number (nonzero). A finite difference of a
  rasterised distance transform stepped along slanted edges and showed as banding.
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
- The shapes agree on the displacement to about 2%; the capsule is 1.5 to 3 px under native at one depth and is not understood.
- The path field is exact to half a pixel; the gradient comes from finite differences of the texture.
- `ClearGlassUIView` asks for a drawable on the main thread, which roadmap 0005 records as a hazard; per-frame cost is not yet
  measured.

## Licensing

The reference geometry reproduces Apple's constants and structure to match its output. The owner decided (2026-10-20) that
this is fine in this MIT repository. Apple's binary is still never copied: the oracle reads it from the installed runtime.
