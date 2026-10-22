---
status: done
blocked-by: 
date: 2026-10-22
---

# 0008 — Variable blur does no filter work on an unchanged layout

`layoutSubviews` → `updateMask` → `setupVariableBlurFilter` on every pass previously executed two KVC writes,
`filters = []` and `filters = [filter]` on the backdrop layer, and set alpha on every other subview — even
when the size and configuration were unchanged and the mask was a cache hit.

## Changes

- Bounded `VariableBlurUIView.updateMask` and `AlphaMaskUIView.updateMask` behind `appliedMaskKey` and `installedRadius` checks.
- Filter installation and radius configuration occur only on initial setup or actual configuration changes.
- Layer mask updates disable implicit animations via `CATransaction` actions suppression.

Regression: `variable blur does no filter reassignments on unchanged layout`, `alpha mask does not reapply mask on unchanged layout`.
