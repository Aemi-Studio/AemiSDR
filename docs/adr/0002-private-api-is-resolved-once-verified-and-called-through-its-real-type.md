---
status: proposed
date: 2026-10-20
---

# 0002 — Private API is resolved once, verified, and called through its real type

## Context

AemiSDR uses six private classes, four private selectors called directly, and some forty private KVC
keys across QuartzCore, UIKitCore and AppKit — 58 interned names in all
(inventory: `Sources/AemiSDR/Internal/_InternedKeys.swift`). The existing guard
is `responds(to:)` before `perform`, plus a one-shot `.fault` log — a good start that the probes showed is
not enough (diary 2026-10-20-01, iOS 18.6 and 27.0 simulators):

1. **A selector that responds can still be called wrongly.** `+[_UIBackdropViewSettings settingsForStyle:]`
   has encoding `@24@0:8q16` (an `NSInteger` argument). `perform(sel, with: style.rawValue)` boxes the
   `Int` into an `NSNumber` and passes the pointer. UIKit logs "unsupported style constant: 262227050"
   and returns `_UIBackdropViewSettingsUltraLight` for **every** style. Called through a typed IMP the
   same selector returns `…Light` (radius 30), `…Dark` (20), `…Blur` (30) for 0, 1, 2.
   Every `BackdropBlurConfiguration` preset on iOS is therefore the same configuration today.
2. **The style numbers are a second bug.** `UIBlurEffect.Style` raw values are not
   `_UIBackdropViewSettings` style constants: 4, 6 and 10 (`.regular`, `.systemUltraThinMaterial`,
   `.systemChromeMaterial`) are "unsupported" even with the right ABI. A mapping table is needed, and
   each row is a probe.
3. **Unguarded KVC crashes.** `value(forKey:)` on a missing key raises `NSUnknownKeyException` (probed on
   `UIScreen`). `UIScreen.displayCornerRadius` does exactly that with `_displayCornerRadius`, and it is
   the default argument of `VariableBlurUIView.init` and `AlphaMaskUIView.init` — a rename would crash
   every host app at view creation. The `requestedValues` setter on `NSObject` raises the same way.
4. **Silent KVC is the opposite hazard.** `CALayer` and `CAFilter` accept unknown keys without raising
   (probed). A renamed `CABackdropLayer` key is a no-op, invisible to any crash report.
5. **Comments drift.** `setUpdateRate:` is present on 27.0 and absent on 18.6; `setWindowServerAware:`
   and `setLayerUsesCoreImageFilters:` are absent on both, so the "pre-iOS 26" branch is dead code
   across the whole supported range (on the simulators probed).

## Decision

Every private symbol goes through one resolver, in this order, once per process:

1. **Lookup** — `objc_lookUpClass(name)`; for exported classes also `dlsym(RTLD_DEFAULT, "OBJC_CLASS_$_" + name)`
   (found for `CAFilter` and `CABackdropLayer` on both runtimes). C functions resolve through `dlsym` only.
2. **Owner** — `class_getImageName` must end in the expected image (`QuartzCore`, `UIKitCore`, `AppKit`).
   A same-named class from another image is treated as missing.
3. **Signature** — `class_getInstanceMethod`/`class_getClassMethod` and `method_getTypeEncoding` must equal
   the recorded encoding, e.g. `@24@0:8q16`, `d16@0:8`, `v20@0:8B16`. A changed encoding is missing.
4. **Implementation** — `dladdr(method_getImplementation(m))` records which image implements it. A
   different image (a swizzle by a debugging tool or another SDK) is reported once, not refused.
5. **Call** — through `unsafeBitCast(imp, to: @convention(c) (…) -> …)` of the verified type, with the
   `unsafe` justified at the call site by step 3. `perform(_:with:)` remains only for object→object
   selectors already verified. KVC goes through a checked getter/setter pair.

Results are cached as `available` or `missing(reason)`. A missing entry disables its feature, falls back
to public API (`UIBlurEffect` materials, `UIScreen` without corner radius → `0`), and logs one `.fault`.
A public `AemiSDR.PrivateAPIPolicy` lets the host disable every entry. The strings stay interned and are
decoded during resolution only (ADR-0003).

**Where it lives:** the resolver is generic — any Aemi package that touches a private symbol needs it — so
it belongs in Aemi (white paper: generic tools belong in Aemi). The **entries** are AemiSDR's. Until Aemi
ships it, it is written test-first in AemiSDR behind an internal type with no AemiSDR knowledge, so the
move is a file move.

## Consequences

- One-time cost per entry at first use, measured before adoption (roadmap 0001). The per-frame cost falls:
  today every tick re-decodes the interned names and re-runs `responds(to:)`.
- A drift canary becomes possible: a test that resolves every entry and asserts `available`, run on the
  iOS 18 and newest simulators in CI (ADR-0004). An OS update that renames a key fails CI, not a user.
- `systemStyle(_:)` changes behaviour visibly: presets that were all "UltraLight" become different. That
  is the fix, and it is called out in the release notes (roadmap 0002).
- The ABI table is evidence, not documentation: each encoding in the registry was observed on a runtime,
  recorded in the diary with the runtime's build number.
