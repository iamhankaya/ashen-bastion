#!/usr/bin/env bash
# Kart gate komutu: bash tools/gate.sh
# İsteğe bağlı bayraklar: GATE_EXPORT=1, GATE_NIGHTLY=1, GATE_RENDER=1
# Çıkış: 0 yeşil, 1 kırmızı, 3 ağ yok (GATE_NET).
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
rm -rf .gate && mkdir -p .gate

# Adım süreleri (v2.0 S0/F-028): her adım bitince "süre: N sn" yazılır, sonda tablo basılır (.gate/times.log).
STEP_NAME=""
STEP_START=$SECONDS
end_step() {
  [ -n "$STEP_NAME" ] || return 0
  echo "    süre: $((SECONDS - STEP_START)) sn" >&2
  echo "$((SECONDS - STEP_START)) sn  $STEP_NAME" >> .gate/times.log
  STEP_NAME=""
}
fail() { end_step; echo "GATE FAIL: $*" >&2; exit 1; }
step() { end_step; STEP_NAME="$*"; STEP_START=$SECONDS; echo "=== $*"; }

# Günlük taraması: izin listesi YOK. ANSI renk kodları atılır.
scan_log() { # scan_log <dosya>
  if sed 's/\x1b\[[0-9;]*m//g' "$1" | grep -nE '^(SCRIPT ERROR|Parse Error|ERROR:|\[GUT ERROR\])|^Errors +[1-9]' > .gate/scan.out; then
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
# Önceden var olan .godot önbelleği bozuksa --import çıkış 0 verip yalnız ERROR: satırı yazar (prova: tools/ci/prova_import_cache.sh).
HAD_CACHE=0; [ -d .godot ] && HAD_CACHE=1
# F-042: aralıklı SIGABRT çöküşüne karşı en çok 1 bilinen-imzalı yeniden deneme (tools/ci/godot_import.sh; sessiz değil).
bash tools/ci/godot_import.sh .gate/import.log || fail "--import başarısız (bkz. .gate/import.log, .gate/import_retry.txt)"
[ $HAD_CACHE -eq 1 ] && echo "not: .godot önbelleği önceden vardı; içe aktarma günlüğü hata verirse önce 'rm -rf .godot' dene" >&2
scan_log .gate/import.log

step "3. Lint"
gdformat --check scripts tools test > .gate/gdformat.log 2>&1 || { cat .gate/gdformat.log >&2; fail "gdformat"; }
gdlint scripts tools test > .gate/gdlint.log 2>&1 || { cat .gate/gdlint.log >&2; fail "gdlint"; }
if grep -rnE --include='*.gd' "to_upper|to_lower" scripts tools; then fail "to_upper/to_lower yasak (Türkçe i/İ tuzağı)"; fi

step "4. Veri doğrulama"
[ -f tools/validate_data.gd ] || fail "tools/validate_data.gd yok"
"$GODOT_BIN" --headless -s res://tools/validate_data.gd > .gate/validate.log 2>&1 || { cat .gate/validate.log >&2; fail "validate_data"; }
scan_log .gate/validate.log

step "4b. Dilim işareti sözdizimi (tools/v2_slices.txt)"
python3 tools/ci/check_slices.py tools/v2_slices.txt || fail "tools/v2_slices.txt (geçersiz simge / dosya yok)"
python3 tools/ci/check_slices.py --v202 tools/v202_slices.txt || fail "tools/v202_slices.txt (geçersiz simge / dosya yok)"

step "5. Python testleri"
PYDIRS=""
for d in tools/ci/tests tools/art/tests tools/audio/tests; do [ -d "$d" ] && PYDIRS="$PYDIRS $d"; done
if [ -n "$PYDIRS" ]; then
  python3 -m pytest -q -p no:cacheprovider $PYDIRS > .gate/pytest.log 2>&1; py_rc=$?
  tail -n 5 .gate/pytest.log
  [ $py_rc -eq 0 ] || { cat .gate/pytest.log >&2; fail "pytest"; }
  echo "PYTHON_TESTS: $(grep -oE '[0-9]+ passed' .gate/pytest.log | tail -1 | grep -oE '[0-9]+')"
fi

step "6. Birim + kabul (GUT)"
"$GODOT_BIN" --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json > .gate/gut.log 2>&1
gut_rc=$?
tail -n 30 .gate/gut.log
# user:// sızıntısı (tools/ci/gut_pre_hook.gd + gut_stub_hook.gd): her yol için "USER_LEAK: <yol>" satırı.
if sed 's/\x1b\[[0-9;]*m//g' .gate/gut.log | grep -E 'USER_LEAK:' > .gate/leak.out; then
  cat .gate/leak.out >&2
  fail "user:// sızıntısı (USER_LEAK; izin listesi: tools/ci/user_leak_allow.txt)"
fi
[ $gut_rc -eq 0 ] || fail "GUT çıkış kodu $gut_rc"
scan_log .gate/gut.log

step "7. Sahte yeşil korumaları"
[ -f .gate/junit.xml ] || fail "JUnit çıktısı yok"
python3 tools/ci/check_junit.py .gate/junit.xml tools/gate_min_tests.json || fail "asgari test sayısı"
python3 tools/ci/check_durations.py .gate/junit.xml || fail "tek test > 60 sn (ağır test test/long/ altına taşınır; tools/ci/check_durations.py)"
python3 tools/ci/check_slices.py tools/v2_slices.txt .gate/junit.xml || fail "işaretli dilimde pending ya da sıfır test (tools/v2_slices.txt)"
python3 tools/ci/check_slices.py --v202 tools/v202_slices.txt .gate/junit.xml || fail "işaretli dilimde pending ya da sıfır test (tools/v202_slices.txt)"

if [ -f test/acceptance/test_acc_perf_counters.gd ]; then
  step "8. İş sayacı kontrolü (6. adımda GUT içinde koştu)"
fi

if [ "${GATE_EXPORT:-0}" = "1" ]; then
  step "9. Debug APK"
  bash tools/ci/export_debug.sh > .gate/export.log 2>&1; rc=$?
  tail -n 15 .gate/export.log
  [ $rc -eq 3 ] && exit 3
  [ $rc -eq 0 ] || fail "debug APK (bkz. .gate/export.log)"
else
  echo "APK derlenmedi (GATE_EXPORT=1 değil)"
fi

if [ "${GATE_RENDER:-0}" = "1" ]; then
  step "10. Render smoke"
  if command -v xvfb-run >/dev/null; then
    xvfb-run -a "$GODOT_BIN" --rendering-driver opengl3 --audio-driver Dummy --quit-after 60 > .gate/render.log 2>&1 || fail "render smoke"
    scan_log .gate/render.log
  else
    echo "shader derlemesi doğrulanmadı: xvfb-run yok"
  fi
else
  echo "shader derlemesi doğrulanmadı (GATE_RENDER=1 değil)"
fi

end_step
echo "=== Adım süreleri"
cat .gate/times.log
[ -f .gate/import_retry.txt ] && { echo "=== İçe aktarma yeniden denemesi (F-042)"; cat .gate/import_retry.txt; }
python3 tools/ci/check_budget.py .gate/times.log || true
echo "GATE OK"
