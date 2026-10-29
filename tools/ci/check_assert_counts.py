#!/usr/bin/env python3
"""Assertion sayacı (R3 kanıtı): bölme/taşıma öncesi ve sonrası JUnit `assertions` toplamı kaybolmamalı.

  check_assert_counts.py --before J... --after J... [--moved F] [--removed F]

Her `önce` kimliği için hedefler = moved_tests.txt satırının yenileri (satır yoksa kendisi); sonra-toplamı >= önce olmalı.
removed_tests.txt'teki kimlikler muaftır. Hata: stderr `ASSERTS_LOST: <id>: önce N, sonra M`, çıkış 1.
Dürüst sınır: sayı koşu anındaki assert çağrısı sayısıdır; assertion'ın gücünü ölçmez (onu mutasyon kanıtı ölçer).
"""
from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import check_test_ids as T  # noqa: E402


def counts(paths) -> dict:
    out: dict = {}
    for p in paths:
        for tc in ET.parse(p).getroot().iter("testcase"):
            out[f"{tc.get('classname')}::{tc.get('name')}"] = int(tc.get("assertions") or 0)
    return out


def lost(before: dict, after: dict, moved: dict, removed: set) -> list[str]:
    errs = []
    for i, n in sorted(before.items()):
        if i in removed:
            continue
        m = sum(after.get(t, 0) for t in moved.get(i, [i]))
        if m < n:
            errs.append(f"ASSERTS_LOST: {i}: önce {n}, sonra {m}")
    return errs


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", nargs="+", required=True)
    ap.add_argument("--after", nargs="+", required=True)
    ap.add_argument("--moved", default=str(HERE / "moved_tests.txt"))
    ap.add_argument("--removed", default=str(HERE / "removed_tests.txt"))
    a = ap.parse_args(argv)
    moved, e1 = T.parse_moved(Path(a.moved).read_text(encoding="utf-8"))
    removed, e2 = T.parse_removed(Path(a.removed).read_text(encoding="utf-8"))
    errs = e1 + e2 + lost(counts(a.before), counts(a.after), moved, removed)
    for e in errs:
        print(e, file=sys.stderr)
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
