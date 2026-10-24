#!/usr/bin/env python3
"""Yer tutucu karakter görseli üretici (v2.0 S1): mevcut bir görselin tonunu kaydırır; gerçek görsel gelene dek
ikinci karakterin PNG'leri bu araçla üretilir. Çalışma zamanında shader/tint YOKTUR: çıktı önceden işlenmiş PNG'dir,
gerçek görsel gelince yalnız PNG (ve karakter JSON'undaki `rig` sayıları) değişir.

Kullanım:
  python tools/art/make_placeholder.py <kaynak.png> <hedef.png> [--sepia .55] [--hue -18] [--sat .75] [--val .92]
  python tools/art/make_placeholder.py --barutcu          # gunslinger görsellerinden zyfen_{body,portrait}.png + barutcu_arm.png (yer tutucu)

Adımlar (sırayla): sepya karışımı -> ton kaydırma (derece) -> doygunluk çarpanı -> parlaklık çarpanı.
Alfa kanalı aynen korunur; boyut ve mod değişmez. Çıktı kaynağa göre deterministiktir.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SEPIA = 0.55
HUE_DEG = -18.0
SAT_MULT = 0.75
VAL_MULT = 0.92
SEPIA_MATRIX = np.array(
    [[0.393, 0.769, 0.189], [0.349, 0.686, 0.168], [0.272, 0.534, 0.131]], dtype=np.float32
)
# --barutcu: (kaynak, hedef)
BARUTCU = [
    ("assets/gfx/char/gunslinger_body.png", "assets/gfx/char/barutcu_body.png"),
    ("assets/gfx/char/gunslinger_arm.png", "assets/gfx/char/barutcu_arm.png"),
    ("assets/ui/portre-seviye-atlama.png", "assets/gfx/char/barutcu_portrait.png"),
]


def shift(
    img: Image.Image,
    sepia: float = SEPIA,
    hue_deg: float = HUE_DEG,
    sat: float = SAT_MULT,
    val: float = VAL_MULT,
) -> Image.Image:
    """Tonu kaydırılmış kopya döndürür (alfa korunur)."""
    has_alpha = img.mode == "RGBA"
    alpha = img.getchannel("A") if has_alpha else None
    rgb = img.convert("RGB")
    arr = np.asarray(rgb, dtype=np.float32)
    sep = np.clip(arr @ SEPIA_MATRIX.T, 0.0, 255.0)
    mixed = np.clip((1.0 - sepia) * arr + sepia * sep, 0.0, 255.0).astype(np.uint8)
    hsv = np.asarray(Image.fromarray(mixed, "RGB").convert("HSV"), dtype=np.float32).copy()
    hsv[..., 0] = np.mod(hsv[..., 0] + hue_deg / 360.0 * 256.0, 256.0)
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0.0, 255.0)
    hsv[..., 2] = np.clip(hsv[..., 2] * val, 0.0, 255.0)
    out = Image.fromarray(np.rint(hsv).astype(np.uint8), "HSV").convert("RGB")
    if has_alpha:
        out.putalpha(alpha)
    return out


def convert(src: Path, dst: Path, **kw: float) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shift(Image.open(src), **kw).save(dst, optimize=True)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*", help="<kaynak.png> <hedef.png>")
    ap.add_argument("--barutcu", action="store_true", help="barutcu_{body,arm,portrait}.png üret")
    ap.add_argument("--sepia", type=float, default=SEPIA)
    ap.add_argument("--hue", type=float, default=HUE_DEG)
    ap.add_argument("--sat", type=float, default=SAT_MULT)
    ap.add_argument("--val", type=float, default=VAL_MULT)
    a = ap.parse_args(argv)
    kw = {"sepia": a.sepia, "hue_deg": a.hue, "sat": a.sat, "val": a.val}
    if a.barutcu:
        for s, d in BARUTCU:
            convert(ROOT / s, ROOT / d, **kw)
            print(f"{s} -> {d}")
        return 0
    if len(a.paths) != 2:
        ap.error("kaynak ve hedef gerekli (ya da --barutcu)")
    convert(Path(a.paths[0]), Path(a.paths[1]), **kw)
    return 0


if __name__ == "__main__":
    sys.exit(main())
