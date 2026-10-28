#!/usr/bin/env bash
# S-layers: katman matrisi (sim/store/domain/validate/view/autoload/ui/ctrl) + azalan istisna kaydı (tools/ci/check_layers.py).
# Taban: GATE_BASE_REF ya da merge-base(HEAD, origin/main); taban yoksa ratchet (LAYER_NEW_EXCEPTION) atlanır, ihlal denetimi yine koşar.
set -uo pipefail
PY=python3; python3 -c "" 2>/dev/null || PY=python
BASE="${GATE_BASE_REF:-$(git merge-base HEAD origin/main 2>/dev/null || true)}"
"$PY" tools/ci/check_layers.py ${BASE:+--base "$BASE"}
