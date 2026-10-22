---
status: done
blocked-by: 
date: 2026-10-22
---

# 0006 — A capture is skipped only when nothing visible changed

`ContentSignature` (iOS 26 path) previously captured only the content view's bounds, subview/sublayer counts,
and layer contents identity. It lacked `frameInContent` (the lens view's position relative to the content),
causing moving a lens over static content to skip captures and retain stale textures.

## Changes

- Added `frameInContent: CGRect` to `ContentSignature`.
- Hoisted the same-dimensions check in `ensureBridge` above Metal device lookup.

Regression: `moving the effect view over static content invalidates the content signature`.
