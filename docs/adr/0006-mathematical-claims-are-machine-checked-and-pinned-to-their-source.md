---
status: accepted
date: 2026-10-20
---

# 0006 — Mathematical and optical claims are machine-checked and pinned to their source

## Context

The shaders encode mathematics (signed distances, easing polynomials, Snell refraction, Fresnel reflectance, Sellmeier
dispersion) and the visible result depends on it holding at every input, not just the inputs a test happens to try.
The owner asked for these claims to be formally verified in the codebase, in tests or hooks.

"Verified at 100%" cannot honestly be promised for a renderer: a proof is about a model, and the GPU runs float32 or
half-precision code. What can be made mechanical is (1) the real-number properties of the model, (2) the link between the
model and the code it describes, and (3) the guarantee that a lie or a stale proof fails.

## Decision

- Proofs are SMT-LIB files in `Verification/Proofs/`, decided by **Z3** (nonlinear real arithmetic) and run by
  `RepositoryProofTests`. A file declares `; id`, `; claim`, one `; source: path#function sha256:…` per modelled
  function, and `; expect:` the answer of every `(check-sat)` in order.
- **Every proof carries negative controls**: queries that must be `sat`, so a vacuous or broken run cannot pass. The
  harness is itself tested to refute a false lemma and to treat a missing solver as an error, never a pass.
- **Pinning.** The digest of each modelled function (comments and whitespace removed) is stored in the proof. Changing the
  function makes the proof stale and fails; re-pinning is deliberate (`AEMI_UPDATE_PINS=1`) after the model is re-checked.
- **Data transcription** is checked mechanically: every Sellmeier coefficient in the code must appear in the proof.
- Support code lives in the test target, so no shipping binary links a proof harness. macOS only.

## What is proved today (all decided by Z3, exact rational/real arithmetic)

| Proof | Establishes |
|---|---|
| falloff-curves | each of six easing polynomials maps [0,1] into [0,1], is non-decreasing, fixes 0 and 1 |
| rounded-rect-sdf | sign of the distance (negative exactly inside), centre value, **corner wedges and the outermost pixel row are fully masked for every radius and fade width**, in both mask kernels |
| snell-refraction | air to denser medium never totally reflects, so the guard cannot reject an angle; the refracted direction is a unit vector |
| schlick-fresnel | transmission stays in [0, 1 − F0] so the clamp is inert, is non-decreasing in cos, and equals 1 − F0 at normal incidence |
| sellmeier-dispersion | each term decreases across the visible band, no resonance lies inside it, and every material's typed-in data gives blue > green > red > air and the published index at 546.1 nm |

## What is NOT claimed

- Float32 or half-precision rounding. The proofs are real-number models; GPU-versus-CPU tests bound the arithmetic.
- That native Liquid Glass is matched. That is empirical (Glass Lab) and measured, not proved.
- That the SDF is 1-Lipschitz (a true distance bound). **Open.** The monolithic query returns `unknown`; splitting it into
  64 sign cases proves 48 and leaves the 16 in which both points lie in a corner region, which need the absolute-value step
  as a separate lemma. It stays open until all cases are decided; it is not asserted.
- Anything about code that is not pinned. A claim about unpinned code is a comment.

## Consequences

- Editing a modelled shader function fails the build until the model is re-checked and re-pinned: a proof cannot silently
  describe code that no longer exists.
- Z3 is a development dependency (`brew install z3`). A machine without it fails the proof tests loudly.
- Verification is one command: `Verification/verify.sh`. Wiring it into a pre-push hook is a repository-trust decision for
  the owner (`project-hooks trust`); it is not done here.
