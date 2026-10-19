---
status: proposed
date: 2026-10-20
---

# 0003 — Interned private names are decoded once, not on every read

## Context

`_InternedKeys` declares 58 private names with Aemi's `@Interned`, which keeps them out of the binary's
string table. The macro expands each property into a **getter that decodes on every read**
(`get { SI.v([…], key) }`), and `SI.v` builds a permutation array and an output array, then a `String`.

These names are read on hot paths: `_filterValue` builds a three-name array per filter per lookup,
`VariableBlurUIView.updateMask` (every `layoutSubviews`) reads `radiusParam`, `normalizeParam` and
`maskParam`, and the visual-effect accessors read two or three names per property access.

Probe (diary 2026-10-20-01), `SI` copied verbatim, `swiftc -O`, 100,000 reads × 9 rounds, allocations
counted with libmalloc's `malloc_logger` hook as `AemiTestKit` does:

| Read | median | p90 | allocations/read |
|---|---|---|---|
| `@Interned`, 11-byte name | 155 ns | 196 ns | 2 |
| `@Interned`, 27-byte name | 255 ns | 308–406 ns | 3 |
| `static let` of the same `SI.v(…)` | 0.9 ns | 0.9 ns | 0 |

The literal byte array itself does not allocate in `-O` (2 allocations for an 11-byte name: permutation
and output; the 27-byte name adds the heap `String`). Single-module approximation: `SI.v` is
`@inlinable`, so cross-module codegen should match, but that is not yet probed.

## Decision

- AemiSDR reads private names only through the private-API registry (ADR-0002), which decodes each name
  once during resolution and keeps the resolved `Selector`, `AnyClass` or key. No interned getter is read
  in a per-frame path.
- Aemi is asked, in its own ADR, for a decode-once form of the macro (a `static let` peer storage, or a
  `@Interned(.cached)` variant), deterministic keys per declaration (today `UInt64.random` at expansion
  makes every build's binary differ), and typed forms (`#InternedSelector`, `#InternedClass`) so a call
  site cannot pass a decoded `String` where a `Selector` was meant.

## Consequences

- The obfuscation goal is unchanged: the name is still absent from the binary; it exists in memory once,
  as it already did transiently on every read.
- Five names are never read (deadwood: `lightenGrayFlag`, `darkenCompFlag`, `backdropAllowsInPlaceKey`,
  `backdropRectKey`, `backdropUpdateRateKey`); they are removed rather than cached (roadmap 0010).
- Until Aemi ships the cached form, a local `static let` cache in AemiSDR is acceptable only as a bridge,
  with a TODO naming the Aemi ADR.
