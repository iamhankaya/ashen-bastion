#!/usr/bin/env python3
"""GUT günlüklerinden başarısız test adlarını basar (F-ashen-bastion-126: kapı günlüğü son 30 satıra kırpılır).

  gut_failures.py LOG...   her başarısız test için stderr'e `GUT_FAILED: <dosya> :: <test>`; çıkış her zaman 0.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prova_dry_run import parse_gut_failures  # noqa: E402


def main(argv: list[str]) -> int:
    for p in argv[1:]:
        try:
            text = Path(p).read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for item in parse_gut_failures(text)[0]:
            print(f"GUT_FAILED: {item}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
