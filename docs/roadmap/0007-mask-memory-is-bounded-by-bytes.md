---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0007 — Mask memory is bounded by bytes, not by count

`MaskCache` is an `NSCache` with `countLimit = 32` and no cost. Probed on macOS: `createCGImage` from the
mask context yields 32 bits per pixel, 12.2 MiB for a 1206×2622 full-screen mask, so 32 entries can hold
~390 MiB. The masks carry one channel of information.

## Probes

- Whether `CALayer.mask` and the `variableBlur` filter's `inputMaskImage` read alpha or luminance from a
  1-byte image, on the simulator. `.A8` with a nil colour space returned nil on macOS; `.L8` with linear
  gray works but has no alpha.
- Memory of a cache filled with full-screen masks, before and after.
- Whether setting the mask layer's `frame`/`contents` inside `layoutSubviews` triggers an implicit
  animation (the mask is a standalone `CALayer`).

## What lands

`totalCostLimit` with cost = `bytesPerRow × height` (safe, independent of format), then a 1-byte format
if the probe shows the consumers read it, and `CATransaction.setDisableActions` if the animation probe fires.
