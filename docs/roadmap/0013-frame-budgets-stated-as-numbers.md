---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0013 — Frame budgets stated as numbers

The white paper names four budgets; none is measured yet: main-thread cost per capture tick, GPU time per
lens frame, first-paint mask generation, and the idle cost of a static screen (target: zero capture ticks
after the first).

## Probes

- Signposts around capture, render and mask generation in the demo app; release build; simulator first,
  then a device; median and p99 over a scripted scroll.
- The idle case: a static screen with a lens, count display-link ticks that rasterise.

## What lands

The numbers, recorded in the diary with device, OS build and toolchain, and a test for each budget that
can be checked without a device (allocation counts, tick counts).
