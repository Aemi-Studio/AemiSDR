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
  flattened to segments; nearest-segment distance and nonzero winding give the field and its unit outward gradient,
  uploaded together as RGBA16F. The raster EDT remains a tested fallback/reference, not the production path field.
  Native capsules use the continuous field, not circular ends: off-axis joins exposed substantial deformation errors.
- **The blur is an isotropic sum of one to three exact Gaussians, not Apple's filter.** The kernel that best maps a plain background to native
  clear glass is not a Gaussian: weight 1.0 at the centre, 0.31 at one pixel, then a flat tail of about 0.05 out to eight
  pixels. That is a small blur plus a wide defocus halo, which is also why a single Gaussian cannot fit it (rms 0.0276
  against 0.0157 for two). The blur is therefore a tight core (21%, sigma 0.73 px) plus a wide halo (79%, sigma 4.2 px),
  each an exact separable Gaussian with weights normalised to sum to one, truncated at three sigma (maximum radius 32 px).
  The first pass computes the horizontal components together; the second keeps the vertical components separate. The glass
  mixes them by SDF depth, interpolating separately normalised edge/interior weights over a powered smoothstep ramp. A separable product of the mixed
  one-dimensional kernel would be cheaper and wrong: its cross terms are wide in one direction and narrow in the other and
  streak along the axes. No downsample chain, no box or disc plateau. `ClearGlassBlur.gaussian(_:)` gives a single Gaussian.
  The blur runs on display-encoded values: blurring in linear light fits far worse (rms 0.09 to 0.12).
  `.optical` is a three-Gaussian heavy-tailed approximation, not a physically proved optical PSF; `.frosted` is softer.
  Clearer edges and blurrier interiors are an aesthetic option, not a claim about native glass's depth-dependent blur.
- **The native rim is a circular arc:** `A * (1 - sqrt(t * (2 - t)))`, `t = clamp(depth / H, 0, 1)`, along the inward normal.
  The form is observed in QuartzCore AIR's `glass_background_r_lpf` inner-refraction chain; **A = 60 pt and H = 20 pt are
  inferred from captures**, not observed CPU uniforms. The old exponential/Gaussian approximation under-pulled by 11 px at
  the first half-pixel. Flat-red subtraction in `deformation.py` cancels both neutral tone and rim light; the old tone-only
  decoder biased those measurements. The measured circle profile now agrees within 0.1 px at the sampled depths (diary 15).
  The exponential/Gaussian and single-Gaussian profiles remain available for custom appearances.
- **The tone** adds `lift * (1 - falloff * L)` in display space, where `L` is the linear luminance of the blurred backdrop:
  lift 32/255 and falloff 0.83, which give the flat colours exactly (black 32, grey 154, green 13, ...). `lift = 0` removes
  the veil; `veilColor` makes it coloured instead of neutral.
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
  none by default and the comparisons disable it. Optional `chromatic` gives red/green/blue different pulls.
- **Exact path fields.** A path is flattened to segments and the distance is measured to the nearest one, with the gradient
  the unit direction to the nearest point and the sign from the winding number (nonzero). A finite difference of a
  rasterised distance transform stepped along slanted edges and showed as banding.
- **Measure the edge locally.** `edge_report.py` separates depth bands and off-axis sectors on both circle halves and both
  capsule ends; `feature_report.py` tracks detected dots and grid ridges (threshold-dependent diagnostics). `rim_profile.py`
  reproduces the native profile. Controls cover neutral light, clipping, phase continuity, band dilution and feature gating.
  Whole-box SSIM is retained only as a secondary summary, never evidence of edge parity.

## Verification

Geometry: the kernel sums to one and follows the Gaussian; the transform equals the exhaustive distance on random masks (and
fails when the half-pixel offset or the transform is broken); the production shape function equals the verified reference,
distance and gradient (and fails when the extent or a gradient sign changes). Rendering: a blurred impulse is the exact
Gaussian; flat colours come out as measured on native glass (black 32, grey 154, red 255/26/26, ...); the rim pulls from inside
on both sides and leaves the interior alone (fails when the sign flips); a rounded-rectangle path draws what the analytic
shape draws. The arc's measured profile, GPU/CPU pull agreement, capsule field, triangle blur reach and displaced paired
sampling have explicit red-first regressions (diary 15). An experimental merged vertical pass failed pixel equivalence by
5/255 at fractional sampling positions and was removed: tap pairing does not commute with a displaced bilinear lookup.

## Consequences and limits

- Native fidelity and preferred aesthetics are separate goals; default blur and rim-light colour still differ locally.
- Clear flat colours matched in light/dark appearance; textured dark, regular, tinted and interactive matrices remain open.
- Phase scores exclude clipped/weak codes and the first 1.5 px. Sampling-map similarity is not an exact optical oracle.
- Path distance is exact to flattened segments, not Beziers; flattening and overlapping nonzero-fill boundaries need bounds.
- Mixed zero/nonzero corner radii need dedicated finite GPU coverage; nonsquare `.circle` is a circular capsule, not an ellipse.
- Blur scissors include the furthest displaced sample, including chromatic extremes; otherwise triangle base corners read
  cleared/unwritten scratch texels and turn black. The field-based reach is currently scanned on redraw.
- `ClearGlassUIView` still takes a still image and requests drawables on the main thread (roadmap 0005). GPU timing on M2 Pro:
  0.465 ms for 300x200 pt at 3x, 2.362 ms for 650x650 pt; paired-tap controls within 0.4%. Not a frame-budget guarantee.
- The macOS tuning app, live capture, SwiftUI wrapper, scratch-memory budgeting and like-for-like native background timing
  are still owed; CI remains deferred.

## Licensing

The reference geometry reproduces Apple's constants and structure to match its output. The owner decided (2026-10-20) that
this is fine in this MIT repository. Apple's binary is still never copied: the oracle reads it from the installed runtime.
