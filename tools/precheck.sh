#!/usr/bin/env bash
# Push öncesi hızlı ön denetim (altyapı-B): CI'ın kırmızı vereceği sınıfları yerelde, değişen dosyalar üzerinde yakalar.
#   bash tools/precheck.sh [--godot] [--base REF]
# Kapsam: Godot'suz sınıflar (test_map, gdformat, gdlint, to_upper/to_lower, .sh kipi, pytest, satır tavanı, UI kuralı,
# katman, test kimlikleri) ve --godot ile Godot'lu sınıflar (USER_LEAK + değişikliğe bağlı içerik/birim testleri).
# Çıkış: 0 temiz, 1 en az bir PRECHECK_FAIL, 2 kullanım hatası. Hata biçimi (stderr): PRECHECK_FAIL: <sınıf>: <ayrıntı>.
# Atlanan sınıf sessiz yeşil sayılmaz: PRECHECK_SKIP: <sınıf>: <neden> yazılır (araç yok / henüz eklenmedi / platform).
# Bu betik tam kapının YERİNE GEÇMEZ; PR CI'ı ve son kapı her zaman tam gate'i koşar.
set -uo pipefail
# stdin'den çalıştırma (bash -s < precheck.sh) $0'ı "bash" yapar; kök bulunamaz (gate.sh ile aynı kural).
if [ "$(basename -- "$0")" != "precheck.sh" ] || [ ! -f "$0" ]; then
  echo "precheck.sh dosya olarak çalıştırılmalı (bash tools/precheck.sh); stdin'den (bash -s) çalıştırılamaz: \$0='$0'" >&2; exit 2
fi
cd "$(dirname "$0")/.." || exit 2

GODOT=0; BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --godot) GODOT=1 ;;
    --base) BASE="${2:-}"; [ -n "$BASE" ] || { echo "--base için REF gerekir" >&2; exit 2; }; shift ;;
    *) echo "bilinmeyen bağımsız değişken: $1 (kullanım: precheck.sh [--godot] [--base REF])" >&2; exit 2 ;;
  esac
  shift
done

FAILS=0
fail() { echo "PRECHECK_FAIL: $1: $2" >&2; FAILS=$((FAILS + 1)); }
skip() { echo "PRECHECK_SKIP: $1: $2" >&2; }

# Python: Windows'ta Git Bash'te `python3` Microsoft Store takma adı olabilir; gerçekten çalışanı seç.
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c 'import sys' >/dev/null 2>&1; then PY="$cand"; break; fi
done

case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) WINDOWS=1 ;; *) WINDOWS=0 ;; esac

TMP="$(mktemp -d)" || { echo "geçici dizin oluşturulamadı" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

# --- Değişen dosyalar: taban ile merge-base'ten bu yana (çalışma ağacı dahil) + izlenmeyenler. Silinenler hariç. -------------
if [ -z "$BASE" ]; then
  BASE="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -z "$BASE" ] && git rev-parse -q --verify origin/main >/dev/null 2>&1; then BASE=origin/main; fi
  if [ -z "$BASE" ] && git rev-parse -q --verify main >/dev/null 2>&1; then BASE=main; fi
  [ -n "$BASE" ] || BASE=HEAD
fi
MB="$(git merge-base HEAD "$BASE" 2>/dev/null)" || { echo "taban '$BASE' ile ortak ata bulunamadı" >&2; exit 2; }
{ git diff --name-only --diff-filter=d "$MB"; git ls-files -o --exclude-standard; } | sort -u > "$TMP/changed.txt"
# precheck.sh yalnız git ağacında anlamlıdır; .claude/.godot/.gate tarama dışı
grep -vE '^(\.claude|\.godot|\.gate)/' "$TMP/changed.txt" > "$TMP/changed2.txt" || true
mv "$TMP/changed2.txt" "$TMP/changed.txt"
echo "precheck: $(grep -c . "$TMP/changed.txt" || true) değişen dosya (taban: $BASE)"

changed_ext() { grep -E "\\.$1\$" "$TMP/changed.txt" | while read -r f; do [ -f "$f" ] && echo "$f"; done; }
mapfile -t GD_FILES < <(changed_ext gd)
mapfile -t SH_FILES < <(changed_ext sh)

# --- 1. test_map: üretim (denetim değil); `ensure` yoksa (S-map öncesi) mevcut `check` ------------------------------------
if [ -f tools/ci/test_map.py ]; then
  if [ -z "$PY" ]; then
    skip TEST_MAP "çalışan python yok"
  elif grep -qE "cmd == ['\"]ensure['\"]" tools/ci/test_map.py; then  # komut gerçekten dağıtılıyor mu ('ensure_ascii' değil)
    "$PY" tools/ci/test_map.py ensure > "$TMP/map.log" 2>&1 || { cat "$TMP/map.log" >&2; fail TEST_MAP "test_map.py ensure başarısız"; }
  else
    "$PY" tools/ci/test_map.py check > "$TMP/map.log" 2>&1 || { cat "$TMP/map.log" >&2; fail TEST_MAP "test_map.json güncel değil (test_map.py generate)"; }
  fi
else
  skip TEST_MAP "tools/ci/test_map.py yok"
fi

# --- 2. gdformat / gdlint (yalnız değişen .gd) ----------------------------------------------------------------------------
if [ ${#GD_FILES[@]} -gt 0 ]; then
  if command -v gdformat >/dev/null 2>&1; then
    gdformat --check "${GD_FILES[@]}" > "$TMP/gdformat.log" 2>&1 || { cat "$TMP/gdformat.log" >&2; fail GDFORMAT "gdformat --check kırmızı"; }
  else
    skip GDFORMAT "gdformat kurulu değil (pip install -r tools/ci/requirements-ci.txt)"
  fi
  if command -v gdlint >/dev/null 2>&1; then
    gdlint "${GD_FILES[@]}" > "$TMP/gdlint.log" 2>&1 || { cat "$TMP/gdlint.log" >&2; fail GDLINT "gdlint kırmızı"; }
  else
    skip GDLINT "gdlint kurulu değil (pip install -r tools/ci/requirements-ci.txt)"
  fi

  # --- 3. to_upper/to_lower yasak (Türkçe i/İ); gate.sh yalnız scripts/tools/test tarar, burada değişen her .gd
  for f in "${GD_FILES[@]}"; do
    case "$f" in scripts/*|tools/*|test/*) ;; *) continue ;; esac
    # F-131: tabanda izlenen dosyada yalnız EKLENEN satırlar taranır (eski ihlal bu dalın işi değil; gate.sh de yeni ihlali kırar).
    # Tabanda olmayan (yeni/izlenmeyen) dosya baştan sona taranır.
    if git cat-file -e "$MB:$f" 2>/dev/null; then
      git diff -U0 "$MB" -- "$f" | grep -E '^\+[^+]|^\+$' | grep -E 'to_upper|to_lower' > "$TMP/ul.out" || true
      [ -s "$TMP/ul.out" ] && rc=0 || rc=1
    else
      grep -nE 'to_upper|to_lower' "$f" > "$TMP/ul.out" && rc=0 || rc=1
    fi
    if [ $rc -eq 0 ]; then
      cat "$TMP/ul.out" >&2
      fail UPPER_LOWER "$f (to_upper/to_lower yasak: Türkçe i/İ tuzağı)"
    fi
  done
fi

# --- 4. .sh kipi 100755: izlenen dosyada dizin kipi; izlenmeyende (yalnız Linux/WSL) dosya sistemi bitine bakılır ------------
for f in "${SH_FILES[@]}"; do
  mode="$(git ls-files -s -- "$f" | cut -d' ' -f1)"
  if [ -n "$mode" ]; then
    [ "$mode" = "100755" ] || fail SH_MODE "$f ($mode; git update-index --chmod=+x $f)"
  elif [ $WINDOWS -eq 0 ] && [ ! -x "$f" ]; then
    fail SH_MODE "$f (çalıştırma biti yok; chmod +x)"
  fi
done

# --- 5. pytest (yavaşlar hariç): Linux/WSL'de güvenilir, Windows'ta yalnız uyarı ------------------------------------------
if [ -d tools/ci/tests ]; then
  if [ $WINDOWS -eq 1 ]; then
    skip PYTEST "Windows'ta güvenilir değil (ortam kırmızıları); Linux/WSL ya da CI'da koş"
  elif [ -z "$PY" ]; then
    skip PYTEST "çalışan python yok"
  else
    "$PY" -m pytest -q -p no:cacheprovider -k "not slow" tools/ci/tests > "$TMP/pytest.log" 2>&1 \
      || { tail -n 40 "$TMP/pytest.log" >&2; fail PYTEST "pytest -k 'not slow' kırmızı"; }
  fi
else
  skip PYTEST "tools/ci/tests yok"
fi

# --- 6. Sözleşme denetleyicileri (sözleşme fazları ekledikçe devreye girer; yoksa açıkça atlanır) -------------------------
run_check() { # run_check <ETİKET> <betik> [argümanlar...]
  local label="$1" script="$2"; shift 2
  if [ ! -f "tools/ci/$script" ]; then skip "$label" "tools/ci/$script henüz yok"; return 0; fi
  if [ -z "$PY" ]; then skip "$label" "çalışan python yok"; return 0; fi
  "$PY" "tools/ci/$script" "$@" > "$TMP/$label.log" 2>&1 || { cat "$TMP/$label.log" >&2; fail "$label" "$script kırmızı"; }
}
run_check LINE_BUDGET check_line_budget.py --base "$MB"
run_check UI_RULES check_ui_rules.py
run_check LAYERS check_layers.py --base "$MB"
run_check TEST_IDS check_test_ids.py --mode static --base "$MB"

# --- 7. --godot: USER_LEAK + değişikliğe bağlı içerik/birim testleri (tools/gate.sh --changed) ----------------------------
if [ $GODOT -eq 1 ]; then
  if [ -z "${GODOT_BIN:-}" ] || ! "$GODOT_BIN" --version >/dev/null 2>&1; then
    fail GODOT "GODOT_BIN tanımlı değil ya da çalışmıyor (örn. export GODOT_BIN=/c/.../Godot_v4.7.2-stable_win64_console.exe)"
  else
    GATE_JOBS=1 bash tools/gate.sh --changed --base "$MB" > "$TMP/gate.log" 2>&1; grc=$?
    sed 's/\x1b\[[0-9;]*m//g' "$TMP/gate.log" > "$TMP/gate.txt"
    if grep -E 'USER_LEAK:' "$TMP/gate.txt" > "$TMP/leak.out"; then
      cat "$TMP/leak.out" >&2
      fail USER_LEAK "user:// sızıntısı (izin listesi: tools/ci/user_leak_allow.txt)"
    elif [ $grc -ne 0 ]; then
      tail -n 40 "$TMP/gate.txt" >&2
      fail GATE_FAST "gate.sh --changed çıkış $grc"
    fi
  fi
else
  skip GODOT "Godot'lu sınıflar (USER_LEAK, içerik/birim testleri) için --godot"
fi

if [ $FAILS -gt 0 ]; then echo "precheck: $FAILS sınıf kırmızı" >&2; exit 1; fi
echo "precheck: temiz (atlananlar PRECHECK_SKIP satırlarında)"
