---
status: done
blocked-by: 
date: 2026-10-22
---

# 0005 — The display link and drawables never cost a stalled main thread

Previously, an orphaned `DisplayLinkProxy` remained scheduled on the run loop, `LiquidLensUIView.layoutSubviews()`
rendered unconditionally on static layouts, and `nextDrawable()` was called without an in-flight bound.

## Changes

- `DisplayLinkProxy.fire(_:)` invalidates the link when its target has been deallocated.
- Gated `LiquidLensUIView.renderIfNeeded()` behind a `needsRender` flag, re-rendering only on geometry, source or configuration changes.
- Bounded in-flight drawables via `Atomic<Int>` to skip frames when all drawables are held rather than stalling the main thread.

Regression: `a link whose owner disappeared invalidates itself instead of retaining its forwarding target`,
`unchanged layout passes do not trigger redundant render attempts`,
`resizing the view marks it as needing a render`.
