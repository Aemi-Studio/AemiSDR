---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0006 — A capture is skipped only when nothing visible changed

`ContentSignature` (iOS 26 path) is the content view's bounds, its subview and sublayer counts and its
`contents` identity. It does not include `frameInContent`, the lens's own position, so moving a lens over
static content keeps the old capture. A scroll view nested below the content sibling changes none of the
four fields either; `forceCaptureEveryFrame` exists to paper over that.

`drawHierarchy` rasterises the whole content view each time, clipped only by the target buffer.

## Probes

- Compositor test (simulator): move a lens 40 pt over a static view; the captured texture must change.
- Same, with a nested `ScrollView` scrolled by 100 pt.
- Cost of one capture versus content size, to see whether clipping the context helps.

## What lands

The lens frame in the signature, a cheap dirty signal for nested scrolling (or documented
`forceCaptureEveryFrame` guidance with a measured cost), and a clip if it measures as a win.
