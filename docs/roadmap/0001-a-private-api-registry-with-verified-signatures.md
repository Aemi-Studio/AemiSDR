---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0001 — A private-API registry with verified owners and signatures

ADR-0002. Every private class, selector, KVC key and C symbol becomes one registry entry with its expected
image and type encoding, resolved once (`objc_lookUpClass`, `dlsym`, `class_getImageName`,
`method_getTypeEncoding`, `dladdr` on the IMP) and called through a typed `@convention(c)` IMP.

## Probes

- Red: a registry entry with a wrong encoding (`@24@0:8@16` for `settingsForStyle:`) resolves as
  `missing(.encoding)`; a class name from the wrong image resolves as `missing(.image)`.
- Resolution cost per entry and for the whole registry, release build, median and spread, on the simulator.
- The drift canary: one test resolves every entry and asserts `available`, on the iOS 18.x and newest
  simulator runtimes. Plant a renamed key; the canary must fail.
- Swizzle detection: an IMP replaced at test time is reported, not refused.

## What lands

The resolver as a type with no AemiSDR knowledge (promotion to Aemi is then a file move), the AemiSDR
entries, a public `AemiSDR.PrivateAPIPolicy` kill switch with public-API fallbacks, and the canary.
