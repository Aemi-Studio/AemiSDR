---
status: done
blocked-by: 
date: 2026-10-22
---

# 0004 — Capture slots live as long as the GPU reads them, and pools share only equal sizes

`ZeroCopyTextureBridgePool` previously bucketed dimensions, causing alternate reallocations of the
IOSurface ring between consumers of slightly different sizes. `LiquidLensUIView` and `ConsumableTexture`
also dropped references before GPU work completed.

## Changes

- Pooled bridges are keyed by exact `(device, width, height)`.
- `TextureSourceLease` manages source lease lifetimes, calling `onConsumed` only after the view replaces
  the source and all GPU reads complete.
- `ConsumableTexture` retains `CVMetalTexture` alongside the `MTLTexture`.
- `ensureBridge` dimension equality check hoisted above Metal device lookup.

Regression: `equal sizes share a bridge but unequal sizes never share a ring`,
`unregistering does not permit an outstanding texture to be overwritten`,
`an unknown or unregistered consumer cannot acquire a slot`,
`a replaced source remains reserved until every GPU read finishes`,
`completion after a resize cannot release a new generation's slot`,
`a source that cannot render yet stays reserved until replacement or view destruction`.
