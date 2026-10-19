---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0008 — Variable blur does no filter work on an unchanged layout

`layoutSubviews` → `updateMask` → `setupVariableBlurFilter` on every pass: two KVC writes, then
`filters = []` and `filters = [filter]` on the backdrop layer, then alpha on every other subview — even
when the size and configuration are unchanged and the mask is a cache hit. Each pass also decodes three
interned names (ADR-0003). The backdrop layer is found as `subviews.first`, while the visual-effect code
finds the same view by class.

## Probes

- Count filter-array assignments over 100 layout passes with no change (expect 0 after the fix).
- Main-thread time per layout pass in a scrolling list of 20 blurred cells, before and after.

## What lands

Filter installation once per filter instance and configuration change; the mask applied only when its
key changes; the backdrop view found by class through the registry.
