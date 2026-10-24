#!/usr/bin/env bash
# v2.0.2 Gunslinger denge baseline'ı (gate dışı, arka plan işi). v2.0.1 kodunu SABİT commit'te çıkarır (git archive,
# çalışma ağacını bozmaz) ve üç kolu koşar (hepsi Gunslinger):
#   v201-A      v2.0.1, tohum kümesi A (tools/balance/seeds_v202.txt, ilk 60)
#   v201-B      v2.0.1 aynı kod, küme B (bağımsız ikinci 60) => GÜRÜLTÜ TABANI = A ile B arasındaki fark
#   v201-nodyn-A v2.0.1 + tools/balance/patches/no_dynamite.patch (dinamit ve Barutçu havuzdan çıkarılmış), küme A
# Politikalar: strong, kite (gate ölçütü) + greedy, idle (bilgi amaçlı; plandaki "fast" = greedy, hızlı taş toplayıcı).
# Kullanım:
#   bash tools/balance/baseline_run.sh [prepare|run|collect|all|status] [kol ...]
#   BASELINE_COMMIT=<sha> OUT=.baseline JOBS=<n> POLICIES="strong kite greedy idle"  (ortam değişkenleri)
# Yeniden başlatılabilir: bitmiş iş dosyası atlanır; yarıda kalan koşu aynı komutla sürer.
# `collect` birleşik çıktıyı docs/design/v2.0.2/balance/baseline-<kol>.jsonl dosyalarına yazar (commit'lenir; ham iş
# dosyaları OUT altındadır ve .gitignore'dadır). Ardından: python3 tools/balance/compare_baseline.py <taban> <yeni>.
# Süre (4 çekirdek, Godot 4.7.2): tek koşu ≈ 12 sn (ölümlü); 3 kol × 60 tohum × 4 politika ≈ 1 saat.
# Gerekirse CI workflow_dispatch ile kol başına paralel koşulur (aynı komut, `run <kol>`).
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
CMD="${1:-all}"; shift || true
COMMIT="${BASELINE_COMMIT:-9833741}"
OUT="${OUT:-.baseline}"
JOBS="${JOBS:-$(nproc)}"
POLICIES="${POLICIES:-strong kite greedy idle}"
CHAR="${CHAR:-gunslinger}"
CHUNK=5
SEEDS_FILE="$ROOT/tools/balance/seeds_v202.txt"
DEST="$ROOT/docs/design/v2.0.2/balance"
ARMS_ALL="v201-A v201-B v201-nodyn-A"
ARMS="${*:-$ARMS_ALL}"

arm_src() { case "$1" in v201-nodyn-A) echo nodyn ;; *) echo v201 ;; esac; }
arm_set() { case "$1" in *-B) echo B ;; *) echo A ;; esac; }
godot_bin() { GODOT_BIN="${GODOT_BIN:-$(bash "$ROOT/tools/ci/ensure_godot.sh")}"; echo "$GODOT_BIN"; }

# kümenin tohumları (boşlukla), ardışık olmalı (mid_run.gd ilk_tohum + sayı alır)
set_seeds() { awk -v s="$1" '$1 == s { print $2 }' "$SEEDS_FILE" | sort -n; }

prepare() {
  local G; G="$(godot_bin)"
  if [ ! -d "$OUT/src/v201/.godot" ]; then
    rm -rf "$OUT/src/v201"; mkdir -p "$OUT/src/v201"
    git archive "$COMMIT" | tar -x -C "$OUT/src/v201"
    (cd "$OUT/src/v201" && "$G" --headless --import > /dev/null 2>&1)
  fi
  if [ ! -f "$OUT/src/nodyn/.patched" ]; then
    rm -rf "$OUT/src/nodyn"; cp -a "$OUT/src/v201" "$OUT/src/nodyn"
    (cd "$OUT/src/nodyn" && patch -s -p1 < "$ROOT/tools/balance/patches/no_dynamite.patch" && touch .patched)
  fi
  echo "hazır: $OUT/src (commit $COMMIT)"
}

run_arm() {
  local arm="$1" src set G jobs_file
  src="$(arm_src "$arm")"; set="$(arm_set "$arm")"; G="$(godot_bin)"
  mkdir -p "$OUT/results/$arm"
  jobs_file="$(mktemp)"
  local seeds first n prev
  mapfile -t seeds < <(set_seeds "$set")
  [ "${#seeds[@]}" -ge 60 ] || { echo "tohum kümesi $set < 60" >&2; exit 1; }
  for pol in $POLICIES; do
    local i=0
    while [ $i -lt ${#seeds[@]} ]; do
      first="${seeds[$i]}"; n=1; prev="$first"
      while [ $((i + n)) -lt ${#seeds[@]} ] && [ "$n" -lt $CHUNK ] && [ "${seeds[$((i + n))]}" -eq $((prev + 1)) ]; do
        prev=$((prev + 1)); n=$((n + 1))
      done
      local f="$ROOT/$OUT/results/$arm/${pol}_${first}.jsonl"
      [ -s "$f" ] || echo "$pol $first $n $f $ROOT/$OUT/src/$src" >> "$jobs_file"
      i=$((i + n))
    done
  done
  # en uzun işler (kite/strong) önce
  sort -k1,1r "$jobs_file" | xargs -P "$JOBS" -L 1 bash -c \
    'cd "$5" && "$0" --headless -s res://tools/balance/mid_run.gd -- "$1" '"$CHAR"' "$2" "$3" "$4.part" > /dev/null 2>&1 && mv "$4.part" "$4"; echo "bitti: '"$arm"' $1 $2"' "$G"
  rm -f "$jobs_file"
}

collect() {
  mkdir -p "$DEST"
  for arm in $ARMS; do
    local n; n=$(cat "$OUT/results/$arm"/*.jsonl 2> /dev/null | grep -c . || true)
    cat "$OUT/results/$arm"/*.jsonl 2> /dev/null | python3 -c '
import json, sys
rows = [json.loads(l) for l in sys.stdin if l.strip()]
rows.sort(key=lambda r: (r["policy"], r["seed"]))
sys.stdout.write("".join(json.dumps(r, sort_keys=True) + "\n" for r in rows))' > "$DEST/baseline-$arm.jsonl"
    echo "$arm: $n satır -> $DEST/baseline-$arm.jsonl"
  done
}

status() {
  for arm in $ARMS; do
    local done_n; done_n=$(cat "$OUT/results/$arm"/*.jsonl 2> /dev/null | grep -c . || true)
    local want=$(( $(set_seeds "$(arm_set "$arm")" | wc -l) * $(wc -w <<< "$POLICIES") ))
    echo "$arm: $done_n / $want"
  done
}

case "$CMD" in
  prepare) prepare ;;
  run) prepare; for a in $ARMS; do run_arm "$a"; done ;;
  collect) collect ;;
  status) status ;;
  all) prepare; for a in $ARMS; do run_arm "$a"; done; collect ;;
  *) echo "kullanım: baseline_run.sh [prepare|run|collect|all|status] [kol ...]" >&2; exit 2 ;;
esac
