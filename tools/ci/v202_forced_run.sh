#!/usr/bin/env bash
# v202 zorlu koşu (R0, plan '#### v202 dilimi'): tüm simgeler açıkmış gibi test_acc_v202_* dosyalarını iki aşamada koşar.
#   Aşama 1: tüm dosyalar tek Godot sürecinde.  Aşama 2: her dosya kendi sürecinde ve kendi user:// dizininde.
# Kullanım: GODOT_BIN=... bash tools/ci/v202_forced_run.sh ÇIKTI_DİZİNİ   (depo kökünden; --import yapılmış olmalı)
# Çıktı: ÇIKTI/stage1.xml, ÇIKTI/stage2-<dosya>.xml, ÇIKTI/*.log, ÇIKTI/summary.json (v202_forced_summary.py). Hep 0 döner (bilgi amaçlı).
set -uo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:?kullanım: v202_forced_run.sh ÇIKTI_DİZİNİ}"
[ -n "${GODOT_BIN:-}" ] || { echo "GODOT_BIN tanımlı değil" >&2; exit 2; }
mkdir -p "$OUT"
export V202_SLICES_FORCE="P,R,W,Z,E,A"

run() { # run AD DOSYA... : .gutconfig.json'un kopyası, yalnız bu dosyalar, kendi JUnit ve user:// dizini
  local name="$1"; shift
  printf '%s\n' "$@" > "$OUT/$name.list"
  python3 - "$OUT/$name.list" "$OUT/$name.json" "$PWD/$OUT/$name.xml" <<'PY'
import json, sys
cfg = json.load(open(".gutconfig.json", encoding="utf-8"))
cfg["dirs"] = []
cfg["tests"] = ["res://" + f for f in open(sys.argv[1], encoding="utf-8").read().split()]
cfg["junit_xml_file"] = sys.argv[3]
json.dump(cfg, open(sys.argv[2], "w", encoding="utf-8"))
PY
  mkdir -p "$OUT/xdg-$name"
  XDG_DATA_HOME="$PWD/$OUT/xdg-$name" "$GODOT_BIN" --headless -s res://addons/gut/gut_cmdln.gd -gconfig="$PWD/$OUT/$name.json" \
    > "$OUT/$name.log" 2>&1 < /dev/null
  echo "$name: çıkış $?"
}

mapfile -t FILES < <(ls test/acceptance/test_acc_v202_*.gd)
run stage1 "${FILES[@]}"
for f in "${FILES[@]}"; do run "stage2-$(basename "$f" .gd)" "$f"; done
python3 tools/ci/v202_forced_summary.py "$OUT/stage1.xml" "$OUT"/stage2-*.xml > "$OUT/summary.json"
cat "$OUT/summary.json"
