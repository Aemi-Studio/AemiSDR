---
status: done
blocked-by:
date: 2026-10-22
---

# 0018 — A mathematical, physical and optical review of the shaders

The owner asked for a deeper review of the equations behind blur, corner radii and the liquid lens, with proofs checked by machine (ADR-0006) and, separately, a measured match against native Liquid Glass (Glass Lab).

## Done

Seven machine-checked proofs, pinned to their sources:
- `falloff-curves`: polynomials map [0,1] to [0,1], non-decreasing, fixed points.
- `rounded-rect-sdf`: sign, center value, corner wedge coverage, outermost row coverage.
- `circular-sdf`: closed global 1-Lipschitz property across all 16 region pairs via absolute-contraction and norm lemmas, with sharpness witnesses.
- `circular-arc`: bounds in [0, A], zero at height, monotonicity, and sensitivity bounds.
- `snell-refraction`: absence of total internal reflection from air to denser media; unit vector directions.
- `schlick-fresnel`: transmission in [0, 1 - F0], monotonicity, normal incidence.
- `sellmeier-dispersion`: normal dispersion, absence of in-band resonances, published indices.

Regression: `a proof gives exactly the answers it declares`, `a proof models the source function as it is now`.

## To prove or measure next

- Continuous native corner field properties under empirical simulator measurement (see roadmap 0019).
- Float32 and half-precision error bounds against the real-number models where a bound is worth stating.
