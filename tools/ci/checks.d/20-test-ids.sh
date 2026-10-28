#!/usr/bin/env bash
# S-ids: test kimliği kaybı yok (static kip: Godot/JUnit gerekmez; (ii) declared(base) kaybı + kayıt dosyası geçerliliği + DUP/UNSUPPORTED).
# JUnit’li tam kip (i)/(iii) shard-verify aşamasına kapı geçişi fazında bağlanır; şimdilik fark raporu: check_test_ids.py --report-only --junit ...
set -uo pipefail
PY=python3; python3 -c "" 2>/dev/null || PY=python
BASE="${GATE_BASE_REF:-$(git merge-base HEAD origin/main 2>/dev/null || true)}"
if [ -n "$BASE" ]; then "$PY" tools/ci/check_test_ids.py --mode static --base "$BASE"; else "$PY" tools/ci/check_test_ids.py --mode static --no-base; fi
