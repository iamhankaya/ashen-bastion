#!/usr/bin/env bash
# A/B denge verisi: eklentili/eklentisiz, ≥100 tohum, paralel (gate dışı). Kullanım:
#   bash tools/balance/ab_all.sh [çıktı_dizini=.ab] [ilk_tohum=1] [tohum_sayısı=100] [paralel=nproc]
# Ardından: python3 tools/balance/ab_report.py <çıktı_dizini> [rapor.md]
# Süre (4 çekirdek, Godot 4.7.2 headless): ≈ 1 saat (tek koşu: kite ≈ 35 sn, greedy ≈ 7 sn).
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:-.ab}"; FIRST="${2:-1}"; N="${3:-100}"; JOBS="${4:-$(nproc)}"
GODOT_BIN="${GODOT_BIN:-$(bash tools/ci/ensure_godot.sh)}"
mkdir -p "$OUT"
CHUNK=25
jobs_file="$(mktemp)"
for arm in on off; do
  pols="idle kite greedy"; [ "$arm" = on ] && pols="idle kite greedy greedy_pickup"
  for pol in $pols; do
    for ((s = FIRST; s < FIRST + N; s += CHUNK)); do
      n=$(( CHUNK < FIRST + N - s ? CHUNK : FIRST + N - s ))
      echo "$pol $s $n $arm $OUT/${arm}_${pol}_${s}.json" >> "$jobs_file"
    done
  done
done
# En uzun işler (kite) önce başlasın.
sort -k1,1r "$jobs_file" | xargs -P "$JOBS" -L 1 bash -c \
  '"$0" --headless -s res://tools/balance/ab_run.gd -- "$1" "$2" "$3" "$4" "$5" > /dev/null 2>&1; echo "bitti: $1 $2 $4"' "$GODOT_BIN"
rm -f "$jobs_file"
