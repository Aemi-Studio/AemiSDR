---
status: pending
blocked-by: 0001
date: 2026-10-20
---

# 0010 — Interned names are decoded once and the unused ones removed

ADR-0003. Probed: 155 ns and 2 allocations per read for an 11-byte name, 255 ns and 3 for a 27-byte name,
against 0.9 ns and none for a decoded `static let`.

## What lands

- Names read only through the registry (roadmap 0001), decoded at resolution.
- `lightenGrayFlag`, `darkenCompFlag`, `backdropAllowsInPlaceKey`, `backdropRectKey`,
  `backdropUpdateRateKey` removed (never read).
- An allocation ceiling test on one warm capture tick and one unchanged layout pass, so a per-frame
  decode cannot come back.
- In Aemi, its own ADR: decode-once `@Interned`, deterministic keys, `#InternedSelector` and
  `#InternedClass`.
