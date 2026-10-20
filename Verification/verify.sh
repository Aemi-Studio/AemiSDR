#!/bin/sh
# Re-checks every machine-checked proof: the solver's answers, the negative controls, the source pins and the
# coefficient transcription. Needs Z3 (brew install z3). A missing solver FAILS; it is never a pass.
#
# After deliberately changing a modelled function, re-check the model against the new code, then re-pin:
#   AEMI_UPDATE_PINS=1 swift test --filter 'a proof models the source function'
set -eu
cd "$(dirname "$0")/.."
exec swift test --filter 'SourceFunctionTests|ProofSpecTests|SolverHarnessTests|RepositoryProofTests'
