---
status: in-progress
blocked-by:
date: 2026-10-20
---

# 0018 — A mathematical, physical and optical review of the shaders

The owner asked for a deeper review of the equations behind blur, corner radii and the liquid lens, with proofs checked by machine (ADR-0006) and, separately, a measured match against native Liquid Glass (Glass Lab).

## Done

Five proofs (falloff, signed distance and corner coverage, Snell, Schlick, Sellmeier), pinned to their sources.

## To prove or measure next

- SDF 1-Lipschitz: 48 of 64 sign cases decided; the corner-corner cases need the absolute-value lemma.
- Gaussian and variable blur: kernel normalisation and that the variable-blur mask maps alpha to radius monotonically.
- Lens displacement: the radial displacement is zero at the centre, continuous, and bounded by the rim deviation; the chromatic ordering follows the dispersion ordering.
- SDF gradient: unit length away from the medial axis; the smoothed seam stays within the band.
- Superellipse masks use exponent 2, which draws circular arcs. Decide the target curve by measuring the system's corner, then prove the new curve's properties.
- Float32 and half-precision error bounds against the real-number models (interval or Gappa-style analysis), where a bound is worth stating.
