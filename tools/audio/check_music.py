#!/usr/bin/env python3
"""assets/audio/music/*.ogg bütünlüğü. `--require`: manifestteki 7 parçanın tamamı olmak zorunda."""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def missing(root: Path = ROOT) -> list:
    cfg = json.loads((root / "tools/audio/audio_manifest.json").read_text(encoding="utf-8"))
    return [t["id"] for t in cfg["tracks"] if not (root / "assets/audio/music" / f"{t['id']}.ogg").exists()]


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--require", action="store_true")
    a = ap.parse_args()
    m = missing()
    if m:
        print("eksik müzik çıktıları:", ", ".join(m))
    sys.exit(1 if (m and a.require) else 0)
