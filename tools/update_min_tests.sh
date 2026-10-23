#!/usr/bin/env bash
# Asgari test sayılarını son JUnit çıktısından BİLİNÇLİ olarak günceller (yalnız yükselir).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JUNIT="${1:-$ROOT/.gate/junit.xml}"
[ -f "$JUNIT" ] || { echo "JUnit yok: $JUNIT (önce gate'i koş)" >&2; exit 1; }
python3 - "$JUNIT" "$ROOT/tools/gate_min_tests.json" <<'PY'
import json, sys, xml.etree.ElementTree as ET
junit, target = sys.argv[1], sys.argv[2]
cur = {}
for ts in ET.parse(junit).getroot().iter("testsuite"):
    cur[ts.get("name")] = int(ts.get("tests")) - int(ts.get("skipped") or 0)
try:
    old = json.load(open(target))
except FileNotFoundError:
    old = {}
new = dict(old)
for k, v in cur.items():
    new[k] = max(v, old.get(k, 0))
json.dump(dict(sorted(new.items())), open(target, "w"), indent=2, ensure_ascii=False)
open(target, "a").write("\n")
print(f"{len(new)} dosya, toplam {sum(new.values())} test")
PY
