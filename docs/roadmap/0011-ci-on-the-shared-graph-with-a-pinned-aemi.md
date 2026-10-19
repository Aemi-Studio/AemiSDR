---
status: pending
blocked-by: 
date: 2026-10-20
---

# 0011 — CI on the shared graph, with a pinned Aemi and an iOS test leg

ADR-0004. In order, each its own commit:

1. Pin `aemi` by a revision on its `main` and commit the resolved file; CI resolves, never updates.
2. Sync `.swift-format` and `.swiftlint.yml` from Aemi (format-only commit).
3. Call `swift-quality.yml@<sha>` with `enable-linux: false`; arcleak gating, dolly and deadwood reporting.
4. An iOS simulator test job on the floor runtime and the newest; a weekly scheduled canary run.
5. Propose in Aemi that the white-paper core be synced like `.swift-format`, with each package keeping only
   its own doctrine section, and drift checked in the shared gate.

## Probes

- A fresh clone resolves and builds with the committed file and no `update`.
- Each gate fails on a planted violation and passes without it.
- The iOS leg runs the canary and reports its test count.
