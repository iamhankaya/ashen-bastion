#!/usr/bin/env bash
# v1.1 uzun doğrulama (gate DIŞI): 20 dk bot koşuları (P20 tam hali) + bellek büyümesi. Süre: ≈ 30–60 dk (tek çekirdek).
# Kullanım: bash tools/verify_long.sh            (ardından A/B için: bash tools/balance/ab_all.sh)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$(bash tools/ci/ensure_godot.sh)}"
CFG="$(mktemp --suffix=.json)"
cat > "$CFG" <<'JSON'
{"dirs":["res://test/long"],"prefix":"test_","suffix":".gd","include_subdirs":true,"should_exit":true,"should_exit_on_success":true,"log_level":1,"post_run_script":"res://tools/ci/gut_stub_hook.gd"}
JSON
"$GODOT_BIN" --headless --import > /dev/null 2>&1
"$GODOT_BIN" --headless -s res://addons/gut/gut_cmdln.gd -gconfig="$CFG" -gexit
rc=$?
rm -f "$CFG"
exit $rc
