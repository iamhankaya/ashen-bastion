#!/usr/bin/env bash
# Orta oyun denge ölçümü (D fazı): varsayılan 2 politika (strong, kite) × 2 karakter × 400 tohum (A400 = 3001-3400), paralel,
# gate dışı. Kullanım:
#   bash tools/balance/mid_all.sh [çıktı_dizini=.mid] [ilk_tohum=3001] [tohum_sayısı=400] [paralel=nproc]
#   POLICIES="strong kite greedy idle" CHARS="gunslinger" ortam değişkenleriyle değiştirilir.
#   v2.1: CELLS="normal:easy quick:normal endless:normal" (mod:zorluk) verilirse her hücre mid_run.gd'ye mod ve zorluk olarak geçer;
#   boşsa profilsiz legacy koşu (normal:hard, v2.0.x ile birebir).
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
# İş satırı: politika karakter ilk_tohum sayı çıktı [mod zorluk]; hücresiz satırda mod/zorluk yok (legacy).
for cell in ${CELLS:-legacy}; do
  extra=""; tag=""
  if [ "$cell" != "legacy" ]; then extra="${cell%%:*} ${cell##*:}"; tag="${cell/:/_}_"; fi
  for pol in ${POLICIES:-strong kite}; do
    for ch in ${CHARS:-gunslinger zyfen}; do
      for ((s = FIRST; s < FIRST + N; s += CHUNK)); do
        n=$(( CHUNK < FIRST + N - s ? CHUNK : FIRST + N - s ))
        echo "$pol $ch $s $n $OUT/${tag}${pol}_${ch}_${s}.jsonl${extra:+ $extra}" >> "$jobs_file"
      done
    done
  done
done
sort -k1,1r "$jobs_file" | xargs -P "$JOBS" -L 1 bash -c \
  '"$0" --headless -s res://tools/balance/mid_run.gd -- "${@:1:5}" ${6:+"$6" "$7"} > /dev/null 2>&1; echo "bitti: $1 $2 $3 ${6:-legacy}"' "$GODOT_BIN"
rm -f "$jobs_file"
