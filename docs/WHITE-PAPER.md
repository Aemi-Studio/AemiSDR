# AemiSDR — Project White Paper

The rules this package runs on. **Paste this at the start of every iteration.** The law was first written for
`ask` and carried into TerminalKit; this is the copy adapted to a rendering library that ships private API to
apps. An iteration that cannot satisfy a rule below stops and fixes the rule, or asks to change it in writing —
it does not quietly proceed. Where this copy and the ecosystem's disagree on a shared principle, that is a
defect to reconcile, not a local exception (ADR-0001).

## Runtime principles

These are what "fast" is allowed to mean here. Each one excludes something that would otherwise look like an
optimisation.

**A frame is the unit of cost.** AemiSDR runs inside someone else's app, on their main thread and their GPU.
Work done per display-link tick, per `layoutSubviews` and per `updateUIView` is paid at 60–120 Hz by a host
that did not write it. Do it once (at configuration), do it when something changed (a dirty flag, a
signature), or do not do it.

**Fewest allocations, none per frame.** A tick that captures, renders or re-applies a mask allocates zero
times once warm; buffers, IOSurfaces, pipelines and masks are reused, never re-made. A ceiling is
**measured and enforced by a test** (Aemi's `expectAllocations`), because a ceiling nobody checks is a wish.

**Close to zero copy.** Pixels cross the CPU→GPU boundary once, through an IOSurface the GPU samples in place
(`ZeroCopyTextureBridge`). No `CGImage` round-trip per frame, no `MTLTexture.replace` on the hot path, no
4-byte pixels where 1 byte is the information.

**Safest, and still near zero-copy.** Requirements together, never a trade. No `-Ounchecked`, no disabled
checks, no `unsafe` without a comment saying why it holds. Being fast and safe means **doing less work** —
skip an unchanged capture, scissor a small lens — not removing the checks that catch the bugs.

**Private API is a dependency we do not control.** It is resolved once, verified, called through the type
it actually has, and degrades to public API when it is gone — never a crash, never silent (§3, ADR-0002).

**Modern primitives, and a written reason for every escape.** The floor is iOS 18 / macOS 15. `Mutex` and
`Atomic` compile there; `Span` and `InlineArray` do not (probed: "only available in iOS 26.0 or newer"),
so they are used only behind `#available`. `NSLock`, `os_unfair_lock` and new `DispatchQueue`s are not
introduced; the existing ones are on a shrinking baseline. `@unchecked Sendable` and `nonisolated(unsafe)`
carry their invariant next to them.

**Tests are deterministic.** No `Task.sleep`, no polling, no wall-clock assertion. Wait on the event.
A GPU test that cannot get a Metal device reports a skip; it never passes silently.

**Every change that can affect performance is benchmarked** — before and after, same harness, release build,
median and spread with units, in the diary and the commit message. One that moves no number is reverted.

**Generic tools belong in Aemi.** Interned strings, the private-symbol resolver, allocation probes: if a
second consumer is plausible, the tool goes to Aemi and comes back as a dependency, pinned by revision.

**Reliable by default, and never silent.** A missing private symbol costs only the effect that needs it,
reported once per process as a `.fault`; everything else keeps working. The host can turn private API off.

---

## 0. The Evidence Rule

> **Every claim is challenged and backed by an actual probe before it is adopted or acted on.
> There is no place for an assumption.**

**A claim** is anything stated as fact about a toolchain, an OS runtime, a private class, a GPU, a
performance number or someone else's code. **A probe** is running the thing and observing the result: a
build, a test, a benchmark, a runtime introspection on the simulator or device. Recollection is not a probe.

**The protocol:** name the claim as a sentence that could be false → design a probe that would make it false
→ run it and record the command verbatim → record the verdict in the diary → act only then. An unprobed
claim is written down as an open question, never as a fact.

**The AemiSDR lesson.** `systemStyle(_:)` checked `responds(to: settingsForStyle:)` and then called it with
`perform(_:with:)`. The selector existed; its type encoding is `@24@0:8q16` — it takes an integer, and
`perform` passes an object. Every preset came back as the same fallback on the iOS 18.6 and 27.0 simulators.
*A selector
that responds is not a selector you may call; the probe that matters is the one that checks the type.*

**Not a probe:** a code comment ("removed in iOS 26" — the keys were already absent on the 18.6 simulator), a passing
macOS `swift test` for iOS-only code, a simulator result claimed for a device.

## 1. Red TDD

- **Red first**, observed failing for the right reason, before the implementation exists.
- One behaviour per test, named in backticks as a sentence: ``@Test func `a missing selector degrades to the public effect`()``.
- Green by the minimum *general* code. Refactor with tests green, one named move at a time.
- Red and green land in the same commit. Never assert on nothing; never share mutable state between tests.
- Coverage is measured by behaviour, never by percentage.
- **Every fix is regression-tested, and the test is shown to fail without it** (revert the fix or mutate it, watch the red, restore). A roadmap record may be `status: done` only if a `Regression:` line cites the tests, in backticks, that guard it; `RegressionEvidenceTests` rejects a done record that cites none or cites one that does not exist.
- New behaviour is built red first. A probe or experiment is not product code and is kept apart from it; whatever a probe produces that ships gets tests.

## 2. Performance doctrine

- **Measure to find the bottleneck, measure again to prove the fix.** Release builds only.
- **Percentiles, not averages.** Hitches are p99 frames.
- **Budgets are numbers with units**, owed until measured (roadmap 0013): main-thread cost per capture tick,
  GPU time per lens frame, first-paint mask generation, idle cost of a static screen (target: zero ticks).
- **Order of attack:** don't do the work → do less → do it elsewhere → in parallel → micro-optimise.
- **Never block the main thread on the GPU.** `nextDrawable()` and pipeline compilation do not run
  unbounded on main.
- **Never trade correctness or safety for speed.** No `-Ounchecked`, ever.

## 3. Private API doctrine

Private API is why this package exists and the largest risk it ships. Every use obeys all of these:

(Implemented by Abysm, `../Abysm`; AemiSDR declares the entries.)

1. **Declared once.** Each class, selector, KVC key and C symbol is one entry in a registry, with its
   expected owning image (`QuartzCore`, `UIKitCore`) and expected type encoding.
2. **Resolved once, verified, cached.** `objc_lookUpClass` / `dlsym(RTLD_DEFAULT, "OBJC_CLASS_$_…")`,
   `class_getImageName` for the owner, `class_get{Instance,Class}Method` + `method_getTypeEncoding` for
   the signature, `dladdr` on the IMP to see who implements it. A mismatch is "missing".
3. **Called through its real type.** A typed `@convention(c)` IMP whose signature was just verified.
   `perform(_:with:)` only for object-in, object-out selectors; never with a scalar.
4. **KVC only behind a getter/setter check.** `value(forKey:)` on a missing key raises
   `NSUnknownKeyException` (probed). `CALayer` and `CAFilter` accept unknown keys silently (probed),
   which is its own hazard: a renamed key is a no-op, so the canary must check the setter exists.
5. **Degrade, report once, keep going.** A missing entry disables only its effect, falls back to public API,
   and logs one `.fault` per process.
6. **The host decides.** A public policy can disable all private API (App Review risk, remote kill switch).
7. **Strings are interned and decoded once** — at registry resolution, not per frame (ADR-0003).
8. **A drift canary runs on the floor and the newest runtime**: a test that resolves every entry on an
   iOS 18 and the latest iOS simulator, and fails on a missing symbol or a changed encoding (ADR-0004).

## 4. GPU and capture doctrine

- A capture slot is held until **every** GPU command that reads it has completed, not only the first.
- A shared resource is shared only between consumers whose exact dimensions match; a pool that reallocates
  on alternate frames is not a pool.
- A capture is skipped when nothing visible changed — and "visible" includes the lens's own position.
- Verification has three levels, as TerminalKit's has for terminals: **math tests** (the Swift model of
  the optics), **shader tests** (the real Metal function on a real device, skipped without one), and
  **compositor tests** (a running UIKit hierarchy on the simulator) — owed, and recorded as owed until they run.

## 5. Swift package strictness

Swift 6 language mode and `StrictMemorySafety` are on. `ExistentialAny`, `InferIsolatedConformances`,
`InternalImportsByDefault`, `MemberImportVisibility` and warnings-as-errors are the ecosystem's set (see
`ask`'s white paper for the SE references); each is adopted after its violation count is measured, on a
ratchet that shrinks (roadmap 0012). Optimized tests enable testability explicitly
(`swift test -c release --enable-testable-imports`); shipping builds do not, and are not claimed identical.

## 6. Style, size and analysis

- Style is Aemi's canonical `.swift-format`; SwiftLint owns size and complexity only. Drift is a red build.
- One top-level type per file, named for it; a file listing is the map.
- deadwood, dolly and arcleak run pinned by version and SHA-256. A finding ends in one of three ways: fix
  it, name the abstraction it was missing, or accept it at the source with a written reason.
- Previews and demo code are analysed separately from shipping code; they never set a library's threshold.

## 7. Documentation law

- `docs/adr/NNNN-title.md` — one decision per file, with a `status:`. New evidence makes a new ADR that
  supersedes the old one.
- `docs/roadmap/NNNN-title.md` — one unit of work per file, with a `status:`.
- `docs/diary/YYYY-MM-DD-NN.md` — the working log and where probe history lives. At most 256 lines.
- This file: principles, not a log, at most 200 lines. The law is enforced by `DocumentationLayoutTests`.

## 8. Commit discipline

Atomic and buildable; the message states **why**. Never mix a refactor and a behaviour change. Slice by
behaviour. Report residual risk and follow-ups explicitly — silence reads as "nothing left".

## 9. Bans

Unprobed claims. Unbenchmarked performance changes. Debug or best-run benchmarks. Sleeps in tests.
`perform(_:with:)` with a scalar. Unguarded `value(forKey:)` on private keys. Per-frame string decoding.
`branch:` dependencies in a shipped `Package.resolved` that CI papers over with `swift package update`.
Big-bang rewrites. Drive-by churn. A dependency for convenience — **a dependency is an architectural decision.**
