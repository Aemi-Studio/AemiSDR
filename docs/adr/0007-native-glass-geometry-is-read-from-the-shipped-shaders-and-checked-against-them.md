---
status: accepted
date: 2026-10-20
---

# 0007 — Native glass geometry is read from the shipped shaders and checked against them

## Context

The lens is meant to match native Liquid Glass, and "looks about right" cannot be measured. Screenshots of native glass
mix the shape, the blur, the tint, the highlight and the rim, so a screenshot comparison cannot say which part is wrong.
Apple ships the answer: the iOS simulator runtime carries Core Animation's shader library
(`QuartzCore.framework/default.metallib`, 228 entry points). It contains `glass_foreground`, `glass_background_*`, the
`sdf_*` generators, `brim_*` (jump flooding) and `rim_outline`, each as AIR with function names and uniform offsets intact.

## Decision

- **Read the shipped shader instead of guessing from pictures.** `Verification/AppleGlass/extract-shaders.sh` writes the
  library as LLVM IR, one file per shader, into a git-ignored local directory. REA drives the rest of the investigation
  (Mach-O and symbol work on the extracted QuartzCore binary).
- **Apple's shader is the oracle, and it never enters the repository.** `AppleGlassOracleTests` loads the library from the
  installed runtime at test time (or `AEMI_APPLE_QUARTZCORE_METALLIB`), drives Apple's own vertex stage, and renders the
  same random scenes through Apple's `glass_foreground_sdf` and through our reference
  (`Verification/Reference/GlassSDFReference.metal`). Every pixel is compared in 32-bit float. Without a runtime the tests skip.
- **The oracle must be able to fail.** Six mutations of the reference (corner extent, squircle fit, half rounding, corner
  ownership, the negative-radius path, the circle blend) must each be seen, with a difference above 0.01.
- **Our code is written from the measured mathematics**, not pasted from the disassembly. The reference documents the
  geometry in words; the numeric constants are facts the oracle forces to be right.

## What the oracle established (largest difference 9e-4 against peaks near 1.0; mutations show 0.15 to 0.96)

- The corner is a **continuous corner**: its extent is `R = 1.528665 * r`, not `r`.
- The circular corner distance is replaced by a fitted cubic in `t = min(w)/max(w)` of the corner-local coordinates, which bulges toward the pointy corner. This is not a superellipse exponent; the lens's circular corner is the wrong shape for native glass.
- It is blended with a plain circle of radius `r` by a per-edge parameter, and the corner term is rounded to **half precision** before it is scaled.
- Four corners are the largest of four reflected evaluations, each with its **own radius**: native glass supports per-corner radii (roadmap 0016).
- **The sign of a radius selects the curve**: negative is continuous, positive is circular, and the continuous curve fades to a circle as the radius approaches the half-size, so a capsule stays round.

## Consequences

- Shape parity with native glass is now a mechanical target, and the first measured gap between the lens and native is the corner.
- The tests depend on an installed simulator runtime and a host GPU, so they cannot run in a plain hosted CI job; they skip there.
- Apple can change the library. A new runtime that breaks agreement is a finding, not a flake.
