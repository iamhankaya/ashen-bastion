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


def evaluate(total: int, budget: dict, key: str = "gate_job_minutes") -> tuple[float, bool]:
    limit = budget[key] * 60
    pct = total / limit * 100.0
    return pct, pct >= budget["warn_percent"]


def main(argv: list[str]) -> int:
    key = "gate_job_minutes"
    if "--key" in argv:  # parçalı CI (F-044): static_job_minutes | gut_shard_job_minutes | gate_job_minutes
        key = argv[argv.index("--key") + 1]
        argv = [a for a in argv if a not in ("--key", key)]
    args = [a for a in argv[1:] if not a.startswith("--")]
    strict = "--strict" in argv
    path = Path(args[0]) if args else Path(".gate/times.log")
    if not path.is_file():
        print(f"süre günlüğü yok: {path}", file=sys.stderr)
        return 2
    budget = json.loads(BUDGET.read_text(encoding="utf-8"))
    total = total_seconds(path.read_text(encoding="utf-8"))
    pct, warn = evaluate(total, budget, key)
    print(f"gate toplam {total} sn = bütçenin %{pct:.0f}'i (sınır {budget[key]} dk, uyarı %{budget['warn_percent']})")
    if warn:
        print("BÜTÇE UYARISI: gate süresi uyarı eşiğinde; CI iş bölme/sınır artırma işi açılmalı (tools/ci/ci_budget.json)")
    return 4 if (warn and strict) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
