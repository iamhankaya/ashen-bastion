#!/usr/bin/env python3
"""Seçici koşu eşlemesinin kasıtlı-kırma (mutasyon) sınaması (F-044). Yöntem:

  1. prova_test_map.py mutate DOSYA...        verilen betiklerin her işlevinin başına push_error("MUT") ekler
     (temiz bir kopyada! çalışma ağacınızda koşturmayın)
  2. kopyada TAM suite'i koşun (örn. 4 parça: GATE_PART=gut GATE_SHARD=K/4 bash tools/gate.sh; her biri ayrı XDG_DATA_HOME)
  3. prova_test_map.py compare DOSYA... -- junit-1.xml junit-2.xml ...
     JUnit'te kırmızı (failure/error) olan her test dosyası, DOSYA'ların seçimlerinin BİRLEŞİMİNDE olmalı; olmayan varsa çıkış 1.
Sonuç (T20261025-64): 6 betik mutasyonu, 212 dosyanın 46'sı kırmızı, 46'sı da seçimde (kaçan 0, fazla seçim 11).
"""
from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_map  # noqa: E402


def mutate(paths: list[str]) -> int:
    for p in paths:
        out, n = [], 0
        for line in Path(p).read_text(encoding="utf-8").split("\n"):
            out.append(line)
            if re.match(r"^(static )?func \w+\(.*\).*:\s*$", line):
                out.append('\tpush_error("MUT")')
                n += 1
        Path(p).write_text("\n".join(out), encoding="utf-8")
        print(f"{p}: {n} işlev")
    return 0


def compare(files: list[str], junits: list[str]) -> int:
    failing: set[str] = set()
    for j in junits:
        for ts in ET.parse(j).getroot().iter("testsuite"):
            if int(ts.get("failures") or 0) or int(ts.get("errors") or 0):
                failing.add(ts.get("name"))
    m = test_map.load()
    union: set[str] = set()
    for f in files:
        sel = test_map.select([f], m)
        if sel == "FULL":
            print(f"{f}: FULL (kaçırma yok)")
            return 0
        union |= set(sel)
    missed = sorted(failing - union)
    print(f"kırmızı dosya {len(failing)}, seçilen {len(union)}, kaçan {len(missed)}, fazla seçim {len(union - failing)}")
    for t in missed:
        print("KAÇTI:", t, file=sys.stderr)
    return 1 if missed else 0


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "mutate":
        sys.exit(mutate(sys.argv[2:]))
    if len(sys.argv) > 4 and sys.argv[1] == "compare" and "--" in sys.argv:
        i = sys.argv.index("--")
        sys.exit(compare(sys.argv[2:i], sys.argv[i + 1:]))
    print(__doc__, file=sys.stderr)
    sys.exit(2)
