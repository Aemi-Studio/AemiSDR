---
status: in-progress
blocked-by: 
date: 2026-10-20
---

# 0005 — The display link and drawables never cost a stalled main thread

- `DisplayLinkProxy.fire` does nothing when its coordinator is gone, but never invalidates the link: a
  missed `dismantleUIView` leaves a `CADisplayLink` waking the main thread at up to 120 Hz forever.
  The fix is one line (`guard let target else { link.invalidate(); return }`), and makes the documented
  "residual risk" in the coordinator's closing comment go away.
- `renderIfNeeded` runs from every `layoutSubviews`, so a layout pass with nothing changed encodes and
  presents a full lens pass.
- `metalLayer.nextDrawable()` is called on the main thread with no in-flight limit. Claim to probe from
  Apple's documentation: it blocks up to one second when no drawable is free.
- A new `LiquidLensPipelineKey` compiles a specialised pipeline synchronously on main.

## Probes

- Red test: a coordinator released without `tearDown()`; the link is invalidated on its next fire.
- Count renders across 100 no-op layout passes (expect 0 after the fix).
- Main-thread time in `nextDrawable()` with the GPU saturated, before and after an in-flight semaphore
  or `allowsNextDrawableTimeout`.
- Time to first frame for a new pipeline key, synchronous versus asynchronous compilation.
