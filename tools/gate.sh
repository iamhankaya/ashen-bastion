#!/usr/bin/env bash
# Kart gate komutu: bash tools/gate.sh
# İsteğe bağlı bayraklar: GATE_EXPORT=1, GATE_NIGHTLY=1, GATE_RENDER=1
# Çıkış: 0 yeşil, 1 kırmızı, 3 ağ yok (GATE_NET).
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
rm -rf .gate && mkdir -p .gate

fail() { echo "GATE FAIL: $*" >&2; exit 1; }
step() { echo "=== $*"; }

# Günlük taraması: izin listesi YOK. ANSI renk kodları atılır.
scan_log() { # scan_log <dosya>
  if sed 's/\x1b\[[0-9;]*m//g' "$1" | grep -nE '^(SCRIPT ERROR|Parse Error|ERROR:)' > .gate/scan.out; then
    cat .gate/scan.out >&2
    fail "günlükte hata satırı: $1"
  fi
}

step "1. Godot kurulumu"
GODOT_BIN="$(bash tools/ci/ensure_godot.sh)"; rc=$?
if [ $rc -ne 0 ] || [ -z "$GODOT_BIN" ]; then
  [ $rc -eq 3 ] && exit 3
  fail "ensure_godot.sh çıkış $rc"
fi
export GODOT_BIN
echo "Godot: $GODOT_BIN"

step "2. İçe aktarma"
"$GODOT_BIN" --headless --import > .gate/import.log 2>&1 || fail "--import başarısız (bkz. .gate/import.log)"
scan_log .gate/import.log

step "3. Lint"
gdformat --check scripts tools test > .gate/gdformat.log 2>&1 || { cat .gate/gdformat.log >&2; fail "gdformat"; }
gdlint scripts tools test > .gate/gdlint.log 2>&1 || { cat .gate/gdlint.log >&2; fail "gdlint"; }
if grep -rnE "to_upper|to_lower" scripts; then fail "to_upper/to_lower yasak (Türkçe i/İ tuzağı)"; fi

step "4. Veri doğrulama"
if [ -f tools/validate_data.gd ]; then
  "$GODOT_BIN" --headless -s res://tools/validate_data.gd > .gate/validate.log 2>&1 || { cat .gate/validate.log >&2; fail "validate_data"; }
  scan_log .gate/validate.log
fi

step "5. Python testleri"
PYDIRS=""
for d in tools/ci/tests tools/art/tests tools/audio/tests; do [ -d "$d" ] && PYDIRS="$PYDIRS $d"; done
if [ -n "$PYDIRS" ]; then
  python3 -m pytest -q -p no:cacheprovider $PYDIRS || fail "pytest"
fi

step "6. Birim + kabul (GUT)"
"$GODOT_BIN" --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json > .gate/gut.log 2>&1
gut_rc=$?
tail -n 30 .gate/gut.log
[ $gut_rc -eq 0 ] || fail "GUT çıkış kodu $gut_rc"
scan_log .gate/gut.log

step "7. Sahte yeşil korumaları"
[ -f .gate/junit.xml ] || fail "JUnit çıktısı yok"
python3 tools/ci/check_junit.py .gate/junit.xml tools/gate_min_tests.json || fail "asgari test sayısı"

if [ -f test/acceptance/test_acc_perf_counters.gd ]; then
  step "8. İş sayacı kontrolü (6. adımda GUT içinde koştu)"
fi

if [ "${GATE_EXPORT:-0}" = "1" ]; then
  step "9. Debug APK"
  if [ -f tools/ci/ensure_android_sdk.sh ]; then
    bash tools/ci/ensure_android_sdk.sh || fail "android sdk"
    mkdir -p build && "$GODOT_BIN" --headless --export-debug "Android" build/ab-debug.apk || fail "export"
  else
    echo "APK derlenmedi: ensure_android_sdk.sh yok (U1-10)"
  fi
else
  echo "APK derlenmedi (GATE_EXPORT=1 değil)"
fi

if [ "${GATE_RENDER:-0}" = "1" ]; then
  step "10. Render smoke"
  if command -v xvfb-run >/dev/null; then
    xvfb-run -a "$GODOT_BIN" --rendering-driver opengl3 --quit-after 5 > .gate/render.log 2>&1 || fail "render smoke"
    scan_log .gate/render.log
  else
    echo "shader derlemesi doğrulanmadı: xvfb-run yok"
  fi
else
  echo "shader derlemesi doğrulanmadı (GATE_RENDER=1 değil)"
fi

echo "GATE OK"
