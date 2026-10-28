#!/usr/bin/env bash
# S-budget: scripts/**/*.gd tek tip satır tavanı (varsayılan 800) + azalan istisna kaydı (tools/ci/check_line_budget.py).
# Taban: GATE_BASE_REF ya da merge-base(HEAD, origin/main); taban bulunamazsa ratchet denetimi atlanır (tavan yine denetlenir).
set -uo pipefail
PY=python3; python3 -c "" 2>/dev/null || PY=python  # Windows: python3 Store kısayolu çalışmaz
BASE="${GATE_BASE_REF:-$(git merge-base HEAD origin/main 2>/dev/null || true)}"
"$PY" tools/ci/check_line_budget.py ${BASE:+--base "$BASE"}
