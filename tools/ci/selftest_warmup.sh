#!/usr/bin/env bash
# selftest_gate.sh ısınması (F-119): kökte Godot kurar ve bir kez --import yapar; .godot/imported dolar (senaryo kopyalarına aktarılır, actions/cache yazar).
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT_BIN="$(bash tools/ci/ensure_godot.sh)"
export GODOT_BIN
mkdir -p .gate  # .gate gitignore'lu: günlük senaryo kopyalarına girmez
bash tools/ci/godot_import.sh .gate/selftest_warmup_import.log
