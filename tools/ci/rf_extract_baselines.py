#!/usr/bin/env python3
"""Karakterizasyon bazlarını CI günlüğünden ayıklar (T20261028-35, plan Faz 4 madde 18).

Kullanım: python3 tools/ci/rf_extract_baselines.py LOG [--task T20261028-35] [--reason METIN]
Günlükteki `CHAR_BASELINE <ad> <tek satır JSON>` satırlarını test/characterization/baseline/<ad>.json dosyasına yazar
(anahtarlar sıralı, girinti 1, LF, sonda satır sonu) ve tools/ci/baseline_changes.txt'e
`dosya | sha256 | gerekçe | görev` satırı ekler. Baz yalnız tester fazında bu araçla değişir.
"""
import argparse
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = ROOT / "test" / "characterization" / "baseline"
CHANGES = ROOT / "tools" / "ci" / "baseline_changes.txt"
LINE = re.compile(r"CHAR_BASELINE (\S+) (.*)$")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--task", default="T20261028-35")
    ap.add_argument("--reason", default="ilk baz: refactor öncesi kod")
    a = ap.parse_args()
    found: dict[str, str] = {}
    for raw in open(a.log, encoding="utf-8", errors="replace"):
        m = LINE.search(raw.rstrip("\n"))
        if m:
            found[m.group(1)] = m.group(2)
    if not found:
        print("BASELINE_EXTRACT: günlükte CHAR_BASELINE satırı yok", file=sys.stderr)
        return 1
    BASE.mkdir(parents=True, exist_ok=True)
    with open(CHANGES, "a", encoding="utf-8", newline="\n") as ch:
        for name, text in sorted(found.items()):
            data = (json.dumps(json.loads(text), sort_keys=True, indent=1, ensure_ascii=False) + "\n").encode("utf-8")
            path = BASE / f"{name}.json"
            path.write_bytes(data)
            rel = path.relative_to(ROOT).as_posix()
            ch.write(f"{rel} | {hashlib.sha256(data).hexdigest()} | {a.reason} | {a.task}\n")
            print(f"{rel} ({len(data)} bayt)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
