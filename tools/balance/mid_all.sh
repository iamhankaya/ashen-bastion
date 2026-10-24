#!/usr/bin/env bash
# Orta oyun denge ölçümü: 4 politika × 2 karakter × N tohum, paralel (gate dışı). Kullanım:
#   bash tools/balance/mid_all.sh [çıktı_dizini=.mid] [ilk_tohum=1] [tohum_sayısı=20] [paralel=nproc]
# Ardından: python3 tools/balance/mid_report.py <çıktı_dizini>
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:-.mid}"; FIRST="${2:-1}"; N="${3:-20}"; JOBS="${4:-$(nproc)}"
GODOT_BIN="${GODOT_BIN:-$(bash tools/ci/ensure_godot.sh)}"
mkdir -p "$OUT"
CHUNK=5
jobs_file="$(mktemp)"
for pol in strong kite greedy idle; do
  for ch in gunslinger barutcu; do
    for ((s = FIRST; s < FIRST + N; s += CHUNK)); do
      n=$(( CHUNK < FIRST + N - s ? CHUNK : FIRST + N - s ))
      echo "$pol $ch $s $n $OUT/${pol}_${ch}_${s}.jsonl" >> "$jobs_file"
    done
  done
done
sort -k1,1r "$jobs_file" | xargs -P "$JOBS" -L 1 bash -c \
  '"$0" --headless -s res://tools/balance/mid_run.gd -- "$1" "$2" "$3" "$4" "$5" > /dev/null 2>&1; echo "bitti: $1 $2 $3"' "$GODOT_BIN"
rm -f "$jobs_file"
