---
status: accepted
date: 2026-10-20
---

# 0001 — The ecosystem white paper applies here, adapted to a rendering library

## Context

`ask` and TerminalKit run on a white paper (evidence rule, red TDD, performance doctrine, strictness,
documentation law) with ADRs, a roadmap and a diary, each enforced by tests. AemiSDR had none of it: its
reasoning lived in code comments, several of which a probe later contradicted (diary 2026-10-20-01):

- "Legacy keys (removed in iOS 26)" — `setWindowServerAware:` and `setLayerUsesCoreImageFilters:` are
  already absent on the iOS 18.6 simulator, the package's floor.
- `systemStyle(_:)` "reads property values at runtime … so it automatically matches the current OS" —
  it returns the same fallback for every style (ADR-0002).
- CI is green — its last run was 2026-09-16, and a fresh clone cannot resolve: `Package.resolved` pins
  `aemi` at `b05d5f8`, a commit no longer on `main` (`fatal: unable to read tree`). CI only passes because
  it runs `swift package update` first (ADR-0004).

A comment is not a probe. The ecosystem already has the law that would have caught each of these.

## Decision

AemiSDR adopts the white paper, adapted where the platform differs, and the documentation layout with it:

| Ecosystem rule | AemiSDR adaptation | Why |
|---|---|---|
| Floor macOS 26: `Mutex`, `Atomic`, `Span`, `InlineArray` | Floor iOS 18 / macOS 15: `Mutex`, `Atomic` yes; `Span`, `InlineArray` only behind `#available` | Probed: both are "only available in iOS 26.0 or newer" at an iOS 18 target |
| `NSLock`/`DispatchQueue` banned | Not introduced; existing uses on a shrinking baseline (roadmap 0014) | Three `NSLock`s and two mask queues exist today |
| Hot path = keystroke | Hot path = display-link tick, `layoutSubviews`, `updateUIView` | The host pays them at 60–120 Hz |
| Terminal verification: bytes, oracle, real emulator | Math tests, real Metal shader tests, compositor tests on the simulator | Same shape: a model agreeing with itself is not evidence |
| — | New §3 private-API doctrine | The package's largest shipped risk (ADR-0002) |

The documentation law is enforced by `DocumentationLayoutTests` (diary length, white-paper length and no
probe ledger, one roadmap entry per file with `status:`, unique ADR and roadmap numbers, every ADR has a
`status:`), adapted from TerminalKit's suite.

## Consequences

- The white paper is a copy. TerminalKit's own copy records that it had drifted from `ask`'s once; a third
  copy makes that more likely. The shared core should live in Aemi and be synced like `.swift-format`,
  with this file keeping only the AemiSDR doctrine (proposed in Aemi; roadmap 0011).
- Findings from the 2026-10-20 review become roadmap entries, one per unit of work, rather than one
  essay. None is fixed by this ADR; it changes documents and tests only.
- The strictness flags and the shared CI graph are not switched on by this decision; each is measured
  first (roadmap 0011, 0012).
