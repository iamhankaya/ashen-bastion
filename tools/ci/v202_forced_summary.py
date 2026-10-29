#!/usr/bin/env python3
"""v202 zorlu koşu özeti (R0, plan '#### v202 dilimi'): aşama 1 = tüm dosyalar tek süreçte, aşama 2 = dosya başına süreç.

  v202_forced_summary.py STAGE1.xml STAGE2.xml...   JSON özet (stdout)

leak     : aşama 1'de kırmızı, aşama 2'de yeşil (global/önbellek sızıntısı)
real     : aşama 2 kırmızısı, simge -> kimlikler (gerçek kod/varsayım kırmızısı)
pending  : aşama 2'de pending kalan kimlikler
deferred : aşama 2 kırmızısı simge başına > 10 olan simgeler (kapalı kalır, bulgu açılır)
total_over: toplam gerçek kırmızı > 30 (hangi simgenin ertelendiği insan kararıdır)
"""
import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_slices  # noqa: E402

PER_SYMBOL_MAX = 10
TOTAL_MAX = 30


def load(xml_text: str) -> dict:
    """kimlik (sınıf::ad) -> 'pass' | 'fail' | 'pending'."""
    out = {}
    for c in ET.fromstring(xml_text).iter("testcase"):
        if c.find("failure") is not None or c.find("error") is not None:
            st = "fail"
        elif c.get("status") == "pending" or c.find("skipped") is not None:
            st = "pending"
        else:
            st = "pass"
        out[f"{c.get('classname')}::{c.get('name')}"] = st
    return out


def summarize(stage1: dict, stage2: dict) -> dict:
    real = defaultdict(list)
    for i, st in sorted(stage2.items()):
        sym = check_slices.slice_of(i.split("::", 1)[1], check_slices.V202)
        if st == "fail":
            real[sym or "?"].append(i)
    total = sum(len(v) for v in real.values())
    return {
        "leak": sorted(i for i, st in stage1.items() if st == "fail" and stage2.get(i) == "pass"),
        "real": dict(real),
        "pending": sorted(i for i, st in stage2.items() if st == "pending"),
        "deferred": sorted(s for s, v in real.items() if len(v) > PER_SYMBOL_MAX),
        "total_real": total,
        "total_over": total > TOTAL_MAX,
    }


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    stage1 = load(Path(argv[1]).read_text(encoding="utf-8"))
    stage2 = {}
    for p in argv[2:]:
        stage2.update(load(Path(p).read_text(encoding="utf-8")))
    print(json.dumps(summarize(stage1, stage2), indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
