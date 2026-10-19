---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0004 — Capture slots live as long as the GPU reads them, and pools share only equal sizes

Found by reading; each needs a simulator test before the fix.

1. **Pool thrash.** `ZeroCopyTextureBridgePool` keys bridges by power-of-two bucket, but
   `ensureBuffers` reallocates the whole ring whenever the exact width or height differs. Two lenses of
   1002 and 1010 px in one bucket reallocate every slot on alternate renders and bump every consumer's
   generation.
2. **Early release.** `LiquidLensUIView` hands `onConsumed` to the first render's completion, then keeps
   re-rendering the same texture from `layoutSubviews` after the slot is free. With a shared bridge,
   another consumer may write its pixels into that slot while it is being sampled.
3. **Texture lifetime.** `ConsumableTexture` carries the `MTLTexture` but not the `CVMetalTexture`;
   a ring reallocation drops the latter while the GPU may still read the former.
4. `markInFlight` is dead (deadwood, high confidence); `ensureBridge` calls
   `MTLCreateSystemDefaultDevice()` every tick when the effect layer is not a `CAMetalLayer`.

## Probes

- Two consumers, sizes in one bucket: count ring reallocations over 100 renders (expect 0 after the fix).
- A consumer that re-renders after release while a second consumer writes: pixel check of the first.

## What lands

Pool keyed on exact dimensions (or allocation at bucket size with a valid-region uniform, if measured
cheaper), a slot released when it is replaced and its last command buffer completed, the
`CVMetalTexture` retained in `ConsumableTexture`, the dead method removed.
