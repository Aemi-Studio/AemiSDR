---
status: in-progress
blocked-by:
date: 2026-11-12
---

# 0020 — Backdrop and variable blur on macOS, through one core

ADR-0009. Asked by Sunset (its research `docs/research/blur`): a variable blur under its bars (tab bar, address bar, find bar,
the ends of its sidebar list) and a tuned backdrop blur for panels and the command bar's backdrop.

## Slices

1. **Core values and plan** (`BlurRecipe`, `BlurMask`, `BlurFilterPlan`), pure and tested without private API.
2. **Filters and the backdrop layer through Abysm** (`BlurFilterFactory`, `BlurBackdropLayer`): typed resolution, keys checked
   against `inputKeys`, no filter work when the recipe is unchanged; canary entries.
3. **macOS view** (`BlurBackdropNSView`, `BlurBackdropView`): the fallback chain, Reduce Transparency, filter changes applied on
   the next main-actor turn (never inside a SwiftUI update: the macOS 26 crash noted in `BackdropBlurView`).
4. **iOS**: `VariableBlurUIView` onto the core, its public API kept; the canary on the iOS simulator.
5. **Budgets** (roadmap 0013): main-thread cost of `apply` with an unchanged recipe (target: no filter writes, no allocation),
   GPU cost of a 38 pt variable band over a scrolling page, release build, median and p99.

## Done so far

- Slices 1–3 (2026-11-12): `BlurRecipe`, `BlurMask`, `BlurFilterPlan`, `BlurMaskImages`, `BlurFilterFactory`, `BlurBackdropLayer`,
  `BlurBackdropMode`, `BlurBackdropNSView`, `BlurBackdropView`. Tests: `BlurRecipeTests`, `BlurMaskImageTests`,
  `BlurBackdropLayerTests`, `BlurBackdropNSViewTests` (18). iOS simulator build succeeds (the core compiles there; no iOS view yet).

## Not yet known

- The GPU cost of `variableBlur` against `gaussianBlur` at the same radius.
- Behaviour in full screen, across Spaces, and with Reduce Motion.
