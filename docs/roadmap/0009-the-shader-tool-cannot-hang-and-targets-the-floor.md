---
status: pending
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
