---
status: done
blocked-by: 
date: 2026-10-20
---

# 0009 — The shader tool cannot hang a build, and compiles for the package's floor

- `MetalCompilerTool.execute` calls `waitUntilExit()` before draining the pipe. Probed with the same
  code: 65,536 bytes of child output completes; 65,537 bytes hangs until killed. A Metal error cascade or
  a warning flood longer than the pipe buffer stalls the build forever.
- The plugin passes `--ios-min-version 14.0` and `--macos-min-version 11.0`; the package floor is iOS 18 /
  macOS 15.
- An output path outside `--allowed-root` is reported as `missingArgument`.
- Every platform's bundle carries all three metallibs.

## Probes

- Red: a child that writes 200,000 bytes completes.
- Shader compile with the floor's min version: does the generated code or language version change?
  Compare metallib sizes and a GPU timing of the lens pass.
- Bundle size per platform with one metallib.

## What lands

Drain-then-wait (or `readabilityHandler`), min versions from the floor, a dedicated error case, and per
-destination resources if the build system allows it.

## Done (2026-10-20)

- The hang: drain-then-wait. Red at 65,537 bytes (and 200,000 and 1,000,000), green at every size (diary 2026-10-20-02, 10).
- The floor: the plugin no longer passes versions; the tool's default is iOS 18.0 / macOS 15.0, and a test reads `Package.swift` so
  the two cannot drift. The metallib changes (macOS 17,432 -> 20,088 bytes, iOS 17,416 -> 20,072), and every variant draws the same
  pixels as the source compiled at run time (largest channel difference 0/255).
- The misused error: an output outside the root now throws `outputOutsideAllowedRoot`.
- One metallib per destination: declined. Six libraries are about 20 KB each and SwiftPM plugin outputs cannot be selected per platform.
- Performance: not claimed. A GPU-time comparison of the two floors could not be made to resolve (see diary 2026-10-20-10).

Regression: `output at and beyond the 64 KiB pipe buffer is drained, never deadlocked`, `the tool's default floor is the floor declared in Package dot swift`, `the build plugin does not override the tested floor`, `an output outside the allowed root is rejected`, `the shipped library draws the same pixels as the source compiled at run time`
