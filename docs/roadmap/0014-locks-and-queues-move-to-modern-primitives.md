---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0014 — Locks and queues move to modern primitives

`Mutex` and `Atomic` are available at the iOS 18 floor (probed by type-checking at
`arm64-apple-ios18.0-simulator`); `Span` and `InlineArray` are not.

Baseline today: `NSLock` in `_PrivateAPIDiagnostics`, `ZeroCopyTextureBridge` and `LiquidLensRenderer`,
each guarding `nonisolated(unsafe)` storage; two serial `DispatchQueue`s for mask generation; a
`nonisolated(unsafe)` static counter on a `@MainActor` class that needs no annotation; `DispatchQueue.main.async`
retries in the macOS `BackdropBlurView` that give up after two ticks.

## Probes

- Lock replacement is behaviour-preserving: the existing tests, plus TSan on macOS.
- Mask generation off main with structured concurrency versus the serial queue: latency of the first and
  the hundredth mask, and peak concurrent CI renders.

## What lands

`Mutex` for the three locks with the `unsafe` markers gone, one commit each; the queue decision recorded
with its numbers; a ratchet test that fails when a new `NSLock` or `DispatchQueue(` appears.
