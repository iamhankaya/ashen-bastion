#!/usr/bin/env bash
# Kart gate komutu: bash tools/gate.sh
# İsteğe bağlı bayraklar: GATE_EXPORT=1, GATE_NIGHTLY=1, GATE_RENDER=1
# Çıkış: 0 yeşil, 1 kırmızı, 2 kullanım hatası, 3 ağ yok (GATE_NET).
#
# Tam gate (varsayılan; PR CI'ı, entegrasyon merge'ü ve son kapı BUNU koşar, parçalı CI aynı kapsamı bölerek koşar):
#   bash tools/gate.sh
# CI parçaları (F-044; birleşimleri tam gate ile aynı kapsamdır, doğrulama işi birleşimi denetler):
#   GATE_PART=static bash tools/gate.sh                       adım 1-5: kurulum, içe aktarma, lint, veri, Python testleri
#   GATE_PART=gut GATE_SHARD=K/N bash tools/gate.sh           adım 1-2 + 6: yalnız K. parçanın GUT test dosyaları
#   GATE_PART=verify GATE_SHARD_COUNT=N bash tools/gate.sh    parça JUnit'lerini birleştirir + adım 7 (Godot gerekmez)
# Hızlı mod (YALNIZ geliştirici geri bildirimi; docs/dev/ci-speed.md):
#   bash tools/gate.sh --changed [--base REF]
#   Değişen dosyalara göre test seçer (tools/ci/test_map.py); eşlemede yeri olmayan/paylaşılan dosya => tam gate.
#   Başarı "GATE OK" DEĞİL "GATE_FAST OK (KISMİ)" yazar; CI'da (CI/GITHUB_ACTIONS) çalışmaz.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

FAST=0; FAST_BASE="${GATE_BASE:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --changed) FAST=1 ;;
    --base) FAST_BASE="${2:-}"; shift ;;
    *) echo "bilinmeyen bağımsız değişken: $1 (kullanım: gate.sh [--changed [--base REF]])" >&2; exit 2 ;;
  esac
  shift
done
PART="${GATE_PART:-all}"
case "$PART" in all|static|gut|verify) ;; *) echo "GATE_PART geçersiz: $PART (all|static|gut|verify)" >&2; exit 2 ;; esac
if [ $FAST -eq 1 ]; then
  if [ "$PART" != "all" ]; then echo "--changed ile GATE_PART birlikte kullanılamaz" >&2; exit 2; fi
  if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "HIZLI MOD CI'DA YASAK: PR CI'ı, entegrasyon merge'ü ve son kapı her zaman tam suite koşar (docs/dev/ci-speed.md)" >&2; exit 2
  fi
fi
SHARD_K=0; SHARD_N=0
if [ "$PART" = "gut" ]; then
  [[ "${GATE_SHARD:-}" =~ ^([0-9]+)/([0-9]+)$ ]] || { echo "GATE_PART=gut için GATE_SHARD=K/N gerekir" >&2; exit 2; }
  SHARD_K="${BASH_REMATCH[1]}"; SHARD_N="${BASH_REMATCH[2]}"
  [ "$SHARD_K" -ge 1 ] && [ "$SHARD_K" -le "$SHARD_N" ] || { echo "GATE_SHARD=$SHARD_K/$SHARD_N geçersiz" >&2; exit 2; }
elif [ -n "${GATE_SHARD:-}" ]; then
  echo "GATE_SHARD yalnız GATE_PART=gut ile anlamlıdır" >&2; exit 2
fi
if [ "$PART" = "verify" ]; then
  [[ "${GATE_SHARD_COUNT:-}" =~ ^[0-9]+$ ]] || { echo "GATE_PART=verify için GATE_SHARD_COUNT=N gerekir" >&2; exit 2; }
fi

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

# --- Hızlı mod: seçim (yalnız geliştirici geri bildirimi). Şüphede/paylaşılan dosyada tam gate'e düşer. ----------------------
SELECTED=""
if [ $FAST -eq 1 ]; then
  if [ -z "$FAST_BASE" ]; then
    FAST_BASE="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [ -z "$FAST_BASE" ] && git rev-parse -q --verify origin/main >/dev/null; then FAST_BASE=origin/main; fi
    [ -n "$FAST_BASE" ] || FAST_BASE=HEAD
  fi
  MB="$(git merge-base HEAD "$FAST_BASE" 2>/dev/null)" || MB=""
  if [ -z "$MB" ]; then
    echo "hızlı mod: '$FAST_BASE' ile ortak ata bulunamadı => TAM GATE" >&2; FAST=0
  elif ! python3 tools/ci/test_map.py check > .gate/map_check.log 2>&1; then
    cat .gate/map_check.log >&2
    echo "hızlı mod: tools/ci/test_map.json güncel/tutarlı değil => TAM GATE" >&2; FAST=0
  else
    { git diff --name-only "$MB"; git ls-files -o --exclude-standard; } | sort -u > .gate/changed.txt
    if python3 tools/ci/test_map.py select < .gate/changed.txt > .gate/selected.txt 2> .gate/select.why; then
      if [ "$(head -n1 .gate/selected.txt)" = "FULL" ]; then
        cat .gate/select.why >&2
        echo "hızlı mod: paylaşılan/eşlemesiz dosya değişti => TAM GATE koşuluyor" >&2; FAST=0
      else
        SELECTED="$(cat .gate/selected.txt)"
        echo "hızlı mod: $(wc -l < .gate/changed.txt) değişen dosya, $(grep -c . .gate/selected.txt || true) test dosyası seçildi (taban: $FAST_BASE)"
      fi
    else
      cat .gate/select.why >&2; echo "hızlı mod: seçim hatası => TAM GATE" >&2; FAST=0
    fi
  fi
fi

if [ "$PART" != "verify" ]; then
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
fi

if [ "$PART" = "all" ] || [ "$PART" = "static" ]; then
  step "3. Lint"
  if [ $FAST -eq 1 ]; then
    # Hızlı mod: yalnız değişen .gd dosyaları (gdformat/gdlint dosya başınadır; o dosyalar için sonuç tam lint ile aynıdır)
    LINT_ARGS=()
    while read -r f; do [ -f "$f" ] && LINT_ARGS+=("$f"); done < <(grep -E '\.gd$' .gate/changed.txt || true)
    LINT_UP=("${LINT_ARGS[@]}")
  else
    LINT_ARGS=(scripts tools test)
    LINT_UP=(scripts tools)
  fi
  if [ ${#LINT_ARGS[@]} -gt 0 ]; then
    gdformat --check "${LINT_ARGS[@]}" > .gate/gdformat.log 2>&1 || { cat .gate/gdformat.log >&2; fail "gdformat"; }
    gdlint "${LINT_ARGS[@]}" > .gate/gdlint.log 2>&1 || { cat .gate/gdlint.log >&2; fail "gdlint"; }
    if grep -rnE --include='*.gd' "to_upper|to_lower" "${LINT_UP[@]}"; then fail "to_upper/to_lower yasak (Türkçe i/İ tuzağı)"; fi
  fi

  step "4. Veri doğrulama"
  [ -f tools/validate_data.gd ] || fail "tools/validate_data.gd yok"
  "$GODOT_BIN" --headless -s res://tools/validate_data.gd > .gate/validate.log 2>&1 || { cat .gate/validate.log >&2; fail "validate_data"; }
  scan_log .gate/validate.log

  step "4b. Dilim işareti sözdizimi (tools/v2_slices.txt)"
  python3 tools/ci/check_slices.py tools/v2_slices.txt || fail "tools/v2_slices.txt (geçersiz simge / dosya yok)"
  python3 tools/ci/check_slices.py --v202 tools/v202_slices.txt || fail "tools/v202_slices.txt (geçersiz simge / dosya yok)"

  step "5. Python testleri"
  PYDIRS=""
  for d in tools/ci/tests tools/art/tests tools/audio/tests; do
    [ -d "$d" ] || continue
    # Hızlı mod: yalnız değişen araç dizininin testleri (tools/ci değişimi zaten tam gate'tir)
    if [ $FAST -eq 1 ] && ! grep -q "^${d%/tests}/" .gate/changed.txt; then continue; fi
    PYDIRS="$PYDIRS $d"
  done
  if [ -n "$PYDIRS" ]; then
    python3 -m pytest -q -p no:cacheprovider $PYDIRS > .gate/pytest.log 2>&1; py_rc=$?
    tail -n 5 .gate/pytest.log
    [ $py_rc -eq 0 ] || { cat .gate/pytest.log >&2; fail "pytest"; }
    echo "PYTHON_TESTS: $(grep -oE '[0-9]+ passed' .gate/pytest.log | tail -1 | grep -oE '[0-9]+')"
  fi
fi

GUT_CONFIG="res://.gutconfig.json"; GUT_LOG=.gate/gut.log; JUNIT=.gate/junit.xml
if [ "$PART" = "gut" ]; then
  GUT_CONFIG="res://.gate/gutconfig-$SHARD_K.json"; GUT_LOG=".gate/gut-$SHARD_K.log"; JUNIT=".gate/junit-$SHARD_K.xml"
  python3 tools/ci/shard.py config "$SHARD_K" "$SHARD_N" ".gate/gutconfig-$SHARD_K.json" --junit "res://$JUNIT" || fail "shard.py config"
  echo "parça $SHARD_K/$SHARD_N: $(python3 tools/ci/shard.py assign "$SHARD_K" "$SHARD_N" | wc -l) test dosyası"
elif [ $FAST -eq 1 ]; then
  if [ -z "$SELECTED" ]; then
    echo "hızlı mod: değişikliğe bağlı test dosyası yok; GUT koşulmadı"
    GUT_CONFIG=""
  else
    python3 tools/ci/shard.py config-files .gate/selected.txt .gate/gutconfig-fast.json || fail "hızlı mod GUT yapılandırması"
    GUT_CONFIG="res://.gate/gutconfig-fast.json"
  fi
fi

if [ "$PART" != "static" ] && [ "$PART" != "verify" ] && [ -n "$GUT_CONFIG" ]; then
  step "6. Birim + kabul (GUT)"
  "$GODOT_BIN" --headless -s res://addons/gut/gut_cmdln.gd -gconfig="$GUT_CONFIG" > "$GUT_LOG" 2>&1
  gut_rc=$?
  tail -n 30 "$GUT_LOG"
  # user:// sızıntısı (tools/ci/gut_pre_hook.gd + gut_stub_hook.gd): her yol için "USER_LEAK: <yol>" satırı.
  if sed 's/\x1b\[[0-9;]*m//g' "$GUT_LOG" | grep -E 'USER_LEAK:' > .gate/leak.out; then
    cat .gate/leak.out >&2
    fail "user:// sızıntısı (USER_LEAK; izin listesi: tools/ci/user_leak_allow.txt)"
  fi
  [ $gut_rc -eq 0 ] || fail "GUT çıkış kodu $gut_rc"
  scan_log "$GUT_LOG"
fi

if [ "$PART" = "verify" ]; then
  step "6b. Parça JUnit birleştirme (GATE_SHARD_COUNT=$GATE_SHARD_COUNT)"
  SHARD_DIR="${GATE_JUNIT_DIR:-.gate/shards}"
  mapfile -t SHARD_FILES < <(find "$SHARD_DIR" -name 'junit-*.xml' 2>/dev/null | sort)
  [ ${#SHARD_FILES[@]} -eq "$GATE_SHARD_COUNT" ] || fail "parça JUnit sayısı ${#SHARD_FILES[@]} != $GATE_SHARD_COUNT ($SHARD_DIR)"
  python3 tools/ci/shard.py check-merge --require-all "${SHARD_FILES[@]}" || fail "parça kapsamı eksik/yinelenen (tools/ci/shard.py check-merge)"
  python3 tools/ci/shard.py merge .gate/junit.xml "${SHARD_FILES[@]}" || fail "JUnit birleştirilemedi"
fi

if [ $FAST -eq 0 ] && { [ "$PART" = "all" ] || [ "$PART" = "verify" ]; }; then
  step "7. Sahte yeşil korumaları"
  [ -f .gate/junit.xml ] || fail "JUnit çıktısı yok"
  python3 tools/ci/check_junit.py .gate/junit.xml tools/gate_min_tests.json || fail "asgari test sayısı"
  python3 tools/ci/check_durations.py .gate/junit.xml || fail "tek test > 60 sn (ağır test test/long/ altına taşınır; tools/ci/check_durations.py)"
  python3 tools/ci/check_slices.py tools/v2_slices.txt .gate/junit.xml || fail "işaretli dilimde pending ya da sıfır test (tools/v2_slices.txt)"
  python3 tools/ci/check_slices.py --v202 tools/v202_slices.txt .gate/junit.xml || fail "işaretli dilimde pending ya da sıfır test (tools/v202_slices.txt)"
elif [ $FAST -eq 1 ] && [ -n "$GUT_CONFIG" ]; then
  # Hızlı mod: asgari sayı yalnız seçilen dosyalar için; tek test süre sınırı aynı; dilim/pending denetimi tam JUnit ister
  # (yalnız tam gate'te koşar).
  step "7. Sahte yeşil korumaları (hızlı mod: kısmi)"
  python3 tools/ci/check_junit.py .gate/junit.xml tools/gate_min_tests.json --only .gate/selected.txt || fail "asgari test sayısı (hızlı mod)"
  python3 tools/ci/check_durations.py .gate/junit.xml || fail "tek test > 60 sn (ağır test test/long/ altına taşınır; tools/ci/check_durations.py)"
fi

if [ "$PART" = "all" ] && [ $FAST -eq 0 ] && [ -f test/acceptance/test_acc_perf_counters.gd ]; then
  step "8. İş sayacı kontrolü (6. adımda GUT içinde koştu)"
fi

if [ "$PART" = "all" ]; then
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
fi

end_step
echo "=== Adım süreleri"
cat .gate/times.log
[ -f .gate/import_retry.txt ] && { echo "=== İçe aktarma yeniden denemesi (F-042)"; cat .gate/import_retry.txt; }
case "$PART" in
  all) python3 tools/ci/check_budget.py .gate/times.log || true ;;
  static) python3 tools/ci/check_budget.py .gate/times.log --key static_job_minutes || true ;;
  gut) python3 tools/ci/check_budget.py .gate/times.log --key gut_shard_job_minutes || true ;;
esac
if [ $FAST -eq 1 ]; then
  echo "GATE_FAST OK (KISMİ: yalnız değişikliğe bağlı testler; bu GATE OK DEĞİLDİR — PR CI'ı, entegrasyon merge'ü ve son kapı tam suite koşar)"
elif [ "$PART" = "all" ]; then
  echo "GATE OK"
else
  echo "GATE_PART=$PART OK (parça yeşil; tam kapı = static + tüm gut parçaları + verify, GATE OK yalnız tam gate'te yazılır)"
fi
