#!/usr/bin/env python3
"""Gate süre bütçesi uyarısı: python3 tools/ci/check_budget.py [.gate/times.log] [--strict]

`.gate/times.log` satırları "<N> sn  <adım adı>" (tools/gate.sh). Toplam, tools/ci/ci_budget.json `gate_job_minutes`
sınırının yüzde kaçı olduğu yazılır; `warn_percent` (varsayılan %80) aşılırsa "BÜTÇE UYARISI" basılır (bölme ya da sınır artırma
işi açılır). Yerel ölçüm CI makinesinden farklıdır (yalnız bilgi). Çıkış: 0 (--strict ile uyarıda 4), 2 girdi hatası.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

BUDGET = Path(__file__).resolve().parent / "ci_budget.json"


def total_seconds(text: str) -> int:
    return sum(int(m.group(1)) for m in re.finditer(r"^(\d+) sn\b", text, re.M))


def evaluate(total: int, budget: dict) -> tuple[float, bool]:
    limit = budget["gate_job_minutes"] * 60
    pct = total / limit * 100.0
    return pct, pct >= budget["warn_percent"]


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    strict = "--strict" in argv
    path = Path(args[0]) if args else Path(".gate/times.log")
    if not path.is_file():
        print(f"süre günlüğü yok: {path}", file=sys.stderr)
        return 2
    budget = json.loads(BUDGET.read_text(encoding="utf-8"))
    total = total_seconds(path.read_text(encoding="utf-8"))
    pct, warn = evaluate(total, budget)
    print(f"gate toplam {total} sn = bütçenin %{pct:.0f}'i (sınır {budget['gate_job_minutes']} dk, uyarı %{budget['warn_percent']})")
    if warn:
        print("BÜTÇE UYARISI: gate süresi uyarı eşiğinde; CI iş bölme/sınır artırma işi açılmalı (tools/ci/ci_budget.json)")
    return 4 if (warn and strict) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
