#!/usr/bin/env python3
"""JUnit çıktısını denetler: toplam > 0 ve dosya başına asgari sayılar (tek yönlü)."""
import json
import sys
import xml.etree.ElementTree as ET


def main(junit: str, mins_path: str) -> int:
    root = ET.parse(junit).getroot()
    # pending/skip edilen testler sayılmaz (hiçbir şey doğrulamazlar)
    got = {
        ts.get("name"): int(ts.get("tests")) - int(ts.get("skipped") or 0)
        for ts in root.iter("testsuite")
    }
    errors = []
    if sum(got.values()) == 0:
        errors.append("JUnit toplam test sayısı sıfır")
    mins = json.load(open(mins_path))
    for name, need in mins.items():
        have = got.get(name, 0)
        if have < need:
            errors.append(f"{name}: {have} test < asgari {need}")
    for e in errors:
        print("GATE_MINTESTS: " + e, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
