#!/usr/bin/env python3
"""Zyfen yer tutucu beceri ikonları (v2.0.2 S1): assets/ui/icons/<id-tireli>.svg. Gerçek ikonlar (A2) aynı yola yazılır,
karakter/beceri JSON'u değişmez. Soğuk renkli rozet + rüzgar kıvrımı; başlık/aria-label beceri adıdır.

Kullanım: python tools/art/make_placeholder_icons.py
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "icons"
# kimlik -> (görünen ad, kıvrım sayısı)
ICONS = {
    "ruzgar_kesigi": ("Rüzgar Kesiği", 1),
    "hava_bicaklari": ("Hava Bıçakları", 3),
    "girdap": ("Girdap", 2),
    "hortum": ("Hortum", 3),
    "delen_ruzgar": ("Delen Rüzgar", 1),
    "bolunen_kesik": ("Bölünen Kesik", 2),
    "hava_cebi": ("Hava Cebi", 2),
    "nefes_dalgasi": ("Nefes Dalgası", 3),
    "furtina_gozu": ("Fırtına Gözü", 2),
    "ay_oragi": ("Ay Orağı", 1),
    "kasirga_patlamasi": ("Kasırga Patlaması", 3),
    "gogun_mizragi": ("Göğün Mızrağı", 1),
    "tufan": ("Tufan", 3),
}


def svg(name: str, swirls: int) -> str:
    paths = []
    for k in range(swirls):
        y = 34 + k * 14 - (swirls - 1) * 7
        paths.append(f'<path d="M20 {y} Q44 {y - 12} 62 {y} T76 {y - 4}" stroke="#CFE8F2" stroke-width="4"/>')
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96" fill="none" '
        f'stroke-linejoin="round" stroke-linecap="round" role="img" aria-label="{name}"><title>{name}</title>\n'
        '<rect x="6" y="6" width="84" height="84" rx="14" fill="#1B3A4B" stroke="#0B1C26" stroke-width="3"/>\n'
        + "\n".join(paths)
        + "\n</svg>\n"
    )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for sid, (name, swirls) in ICONS.items():
        path = OUT / (sid.replace("_", "-") + ".svg")
        path.write_text(svg(name, swirls), encoding="utf-8")
        print(path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
