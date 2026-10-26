"""Exp küreleri: art/source/gem-orbs/{normal,elit,ara_boss}.png -> assets/gfx/fx/gems/<ad>.png (128x128, RGBA).

python tools/art/process_gem_orbs.py [--check]

Kaynak tuvali kırpılmaz: kaynaktaki %12 boş pay oyun içi boyut oranını (34/48/68 px, GemTiers.ORB_PX) belirler.
Kaynaklar (art/) export dışıdır.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art" / "source" / "gem-orbs"
OUT = ROOT / "assets" / "gfx" / "fx" / "gems"
NAMES = ["normal", "elit", "ara_boss"]
SIZE = 128


def process(name: str) -> Image.Image:
    img = Image.open(SRC / f"{name}.png").convert("RGBA")
    # Şeffaf pikselin gizli RGB'si küçültmede kenara sızmasın: premultiplied çalış.
    return img.convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="yazmadan çıktıların güncel olduğunu denetle")
    args = ap.parse_args(argv)
    bad = 0
    for n in NAMES:
        out = OUT / f"{n}.png"
        img = process(n)
        if args.check:
            if not out.exists() or Image.open(out).convert("RGBA").tobytes() != img.tobytes():
                print(f"GÜNCEL DEĞİL: {out.relative_to(ROOT)}")
                bad += 1
            continue
        OUT.mkdir(parents=True, exist_ok=True)
        img.save(out, optimize=True)
        print(f"{out.relative_to(ROOT)} {img.size}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
