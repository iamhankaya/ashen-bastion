#!/usr/bin/env bash
# v2.1 U6: ekran görüntüsü yakalama (gate DIŞI; .github/workflows/shots.yml çağırır). Yakalama betikleri tools/capture/shots_v21*.gd;
# yazılımsal GL (xvfb + llvmpipe) ile 1080x2400 PNG üretir. Kullanım: bash tools/ci/capture_shots.sh <çıktı_dizini> [senaryolar_a [senaryolar_b]]
# Bir senaryo düşerse betik kırmızı çıkar ama diğerleri yine yakalanır; hiç PNG yoksa da kırmızı (sahte yeşil yok).
set -uo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:?kullanım: capture_shots.sh <çıktı_dizini>}"
GODOT_BIN="${GODOT_BIN:-$(bash tools/ci/ensure_godot.sh)}"
mkdir -p "$OUT"
rc=0
for spec in "shots_v21.gd ${2:-}" "shots_v21_b.gd ${3:-}"; do
  # shellcheck disable=SC2086
  set -- $spec
  xvfb-run -a -s "-screen 0 1080x2400x24" "$GODOT_BIN" --path . --rendering-driver opengl3 --resolution 1080x2400 \
    -s "res://tools/capture/$1" -- "$OUT" ${2:+"$2"} || { echo "SHOTS_FAIL: $1" >&2; rc=1; }
done
n=$(find "$OUT" -name '*.png' | wc -l)
echo "SHOTS: $n PNG"
[ "$n" -gt 0 ] || rc=1
exit $rc
