#!/usr/bin/env python3
"""v202 zorlu koşu özeti (R0, plan '#### v202 dilimi'): aşama 1 = tüm dosyalar tek süreçte, aşama 2 = dosya başına süreç.

  v202_forced_summary.py [--expected-stage2 N] STAGE1.xml STAGE2.xml...   JSON özet (stdout)

leak     : aşama 1'de kırmızı, aşama 2'de yeşil (global/önbellek sızıntısı)
real     : aşama 2 kırmızısı, simge -> kimlikler (gerçek kod/varsayım kırmızısı)
pending  : aşama 2'de pending kalan kimlikler
deferred : aşama 2 kırmızısı simge başına > 10 olan simgeler (kapalı kalır, bulgu açılır)
total_over: toplam gerçek kırmızı > 30 (hangi simgenin ertelendiği insan kararıdır)
problems : girdi sorunları (F-ashen-bastion-133): eksik/okunamayan XML, sıfır test içeren XML, aşama-2 dosya sayısı
           --expected-stage2 N'den az; boş değilse çıkış 1 (özet yine yazılır)
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


def _read(path: Path, problems: list[str]) -> dict:
    """XML'i yükler; eksik/bozuk dosya ve sıfır test `problems`'e yazılır, boş sözlük döner."""
    try:
        cases = load(path.read_text(encoding="utf-8"))
    except (OSError, ET.ParseError) as e:
        problems.append(f"{path.name}: okunamadı ({type(e).__name__})")
        return {}
    if not cases:
        problems.append(f"{path.name}: sıfır test")
    return cases


def main(argv: list[str]) -> int:
    args = argv[1:]
    expected = None
    if args[:1] == ["--expected-stage2"] and len(args) > 1 and args[1].isdigit():
        expected, args = int(args[1]), args[2:]
    if len(args) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    problems: list[str] = []
    stage1 = _read(Path(args[0]), problems)
    stage2 = {}
    for p in args[1:]:
        stage2.update(_read(Path(p), problems))
    if expected is not None and len(args) - 1 != expected:
        problems.append(f"aşama 2: {len(args) - 1} XML var, {expected} bekleniyordu (bayat dosya da sorundur)")
    out = summarize(stage1, stage2)
    out["problems"] = problems
    print(json.dumps(out, indent=2, ensure_ascii=False))
    for pr in problems:
        print(f"FORCED_SUMMARY_PROBLEM: {pr}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
