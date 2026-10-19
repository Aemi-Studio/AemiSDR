---
status: proposed
date: 2026-10-20
---

# 0004 — CI runs the shared graph, on a pinned Aemi, against the iOS code it ships

## Context

Audit of `.github/workflows/ci.yml` and the tree on 2026-10-20 (diary 2026-10-20-01):

- **CI has not run since 2026-09-16.** The last four CI runs, that evening: failure, cancelled, failure,
  success. Nothing has checked `main` since, while Aemi moved under it.
- **A fresh clone does not resolve.** `Package.resolved` pins `aemi` at `b05d5f8`, which is no longer an
  ancestor of Aemi's `main` (history was rewritten); `swift build` fails with
  `fatal: unable to read tree (b05d5f8…)`. CI hides this by running `swift package update` first, so
  every CI run tests whatever `main` is that minute — not the graph a developer has.
- **The tests that run do not reach the risky code.** `swift test` on macOS runs 70 tests in 13 suites,
  all green, but 28 of the 37 source files are `#if os(iOS)`. The capture coordinator, the zero-copy
  bridge, the lens view and every private-API call have no test on any platform. The iOS leg only builds.
- **Floating third-party actions.** `actions/checkout@v6` and `setup-swift@main`, where every other
  ecosystem workflow pins commit SHAs.
- **The ecosystem moved on.** Aemi, TerminalKit, `ask`, HTTP, AemiJSON and the analyzers adopted, on
  2026-10-19/20, one graph with a single required `result` job, SHA-pinned actions, a manifest-keyed
  SwiftPM cache written only from `main`, stable 6.4.1 toolchains, and the analyzers pinned by version
  and hash. Measured on this tree today: arcleak 0 findings; dolly 53 (40 outside `Previews/`);
  deadwood 16: 9 public modifiers it reads as unused (a library's API is its entry point), 1
  high-confidence dead method (`ZeroCopyTextureBridge.markInFlight`), 5 unused interned names, and
  `LiquidLensUniforms._stride`, reachable only from tests;
  SwiftLint with Aemi's metrics config 1 error and 7 warnings; `.swift-format` differs from Aemi's.

## Decision

1. **Pin Aemi by revision** in `Package.swift`, as TerminalKit does (its ADR-0005, "one Aemi, one pin"),
   and commit the matching `Package.resolved`. CI runs `swift package resolve`, never `update`. Moving
   the pin is a reviewed commit.
2. **Call `Aemi-Studio/aemi/.github/workflows/swift-quality.yml@<sha>`** with `enable-linux: false` for the
   common gate, consumer path, macOS tests and the `result` job, plus a package-specific job for what the
   shared graph cannot do (Metal toolchain, iOS simulator).
3. **An iOS simulator test leg** on two runtimes — the floor (iOS 18.x) and the newest — running the full
   suite, including the private-API drift canary (ADR-0002) and compositor tests as they land.
4. **Analyzers**: arcleak gates now (zero findings). dolly and deadwood report only until their findings
   are triaged (roadmap 0015), then gate. `Previews/` is analysed but does not set the threshold.
5. **Style**: sync `.swift-format` and `.swiftlint.yml` from Aemi, in a commit of its own that changes no
   behaviour, then let the drift check gate.

## Consequences

- The iOS leg is cheap: `xcodebuild … -scheme AemiSDR-Package -destination 'platform=iOS Simulator,…' test`
  ran 77 tests in 13 suites in 25 s locally on warm derived data (the `AemiSDR` scheme has no test action).
  Hosted-runner cost is owed a measurement; it is the price of testing the code that ships. A scheduled weekly
  run of the canary on the newest simulator runtime catches OS drift between pushes.
- A pinned Aemi means AemiSDR learns of Aemi breakage when it moves the pin, not at random. That is the
  ecosystem's chosen trade (TerminalKit ADR-0005).
- The simulator is not a device: the canary run there is evidence for the simulator runtime only, and a
  device run is recorded as owed until it is automated.
