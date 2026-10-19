---
status: pending
blocked-by: 0011
date: 2026-10-20
---

# 0012 — The ecosystem's strictness flags, adopted by measurement

Today: Swift 6 mode, `strictMemorySafety()`, and `enableExperimentalFeature("StrictConcurrency")`.
Missing against the ecosystem set: `ExistentialAny`, `InferIsolatedConformances`,
`InternalImportsByDefault`, `MemberImportVisibility`, warnings as errors.

## Probes

- Violation count for each flag alone, on macOS and the iOS simulator.
- Whether `StrictConcurrency` under `.v6` is redundant (build with and without, compare diagnostics).
- `@_exported import SwiftUI` in `AemiSDR.swift` under `InternalImportsByDefault` and
  `MemberImportVisibility`: what a consumer loses if it goes.

## What lands

One flag per commit, smallest count first, each with its count in the commit message.
