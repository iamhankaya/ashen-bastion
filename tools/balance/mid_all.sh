#!/usr/bin/env bash
# Orta oyun denge ölçümü (D fazı): varsayılan 2 politika (strong, kite) × 2 karakter × 400 tohum (A400 = 3001-3400), paralel,
# gate dışı. Kullanım:
#   bash tools/balance/mid_all.sh [çıktı_dizini=.mid] [ilk_tohum=3001] [tohum_sayısı=400] [paralel=nproc]
#   POLICIES="strong kite greedy idle" CHARS="gunslinger" ortam değişkenleriyle değiştirilir.
# Ardından: python3 tools/balance/mid_report.py <çıktı_dizini>
#   python3 tools/balance/compare_baseline.py docs/design/v2.0.2/balance/baseline-v201-A400.jsonl <çıktı_dizini> \
#       --noise docs/design/v2.0.2/balance/baseline-v201-B400.jsonl --nodyn docs/design/v2.0.2/balance/baseline-v201-nodyn-A400.jsonl
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:-.mid}"; FIRST="${2:-3001}"; N="${3:-400}"; JOBS="${4:-$(nproc)}"
GODOT_BIN="${GODOT_BIN:-$(bash tools/ci/ensure_godot.sh)}"
mkdir -p "$OUT"
CHUNK=5
jobs_file="$(mktemp)"
for pol in ${POLICIES:-strong kite}; do
  for ch in ${CHARS:-gunslinger zyfen}; do
    for ((s = FIRST; s < FIRST + N; s += CHUNK)); do
      n=$(( CHUNK < FIRST + N - s ? CHUNK : FIRST + N - s ))
      echo "$pol $ch $s $n $OUT/${pol}_${ch}_${s}.jsonl" >> "$jobs_file"
    done
  done
done
sort -k1,1r "$jobs_file" | xargs -P "$JOBS" -L 1 bash -c \
  '"$0" --headless -s res://tools/balance/mid_run.gd -- "$1" "$2" "$3" "$4" "$5" > /dev/null 2>&1; echo "bitti: $1 $2 $3"' "$GODOT_BIN"
rm -f "$jobs_file"
