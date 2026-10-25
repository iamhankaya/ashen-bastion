"""Gunslinger beceri ikonları: art/source/gunslinger/icons -> assets/ui/icons/<id-tireli>.png.

python tools/art/process_gunslinger_icons.py [--check]

İşleme A2a ile aynı (process_zyfen_fx.make_icon): alfa kutusuna kırp, uzun kenar %80, 256 px kare tuval.
19 ikon: 7 aktif, 4 evrim, Barut Kesesi, 7 ortak pasif (Zyfen varyantları assets/ui/icons/zyfen/ altında, dokunulmaz).
Kaynaklar (art/) export dışıdır.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from process_zyfen_fx import ICON_FILL, ICON_SIZE, make_icon  # noqa: E402,F401

ROOT = Path(__file__).resolve().parents[2]
SRC_ICONS = ROOT / "art" / "source" / "gunslinger" / "icons"
OUT_ICONS = ROOT / "assets" / "ui" / "icons"

ACTIVES = [
    "cift_tabanca", "yelpaze_atis", "keskin_nisan", "seken_mermi", "son_mermi_patlar", "doldurma_sacilmasi", "sarapnel",
]
EVOLUTIONS = ["gurleyen_yelpaze", "kiyamet_mermisi", "mermi_firtinasi", "zincirleme_patlama"]
PASSIVES = ["barut_kesesi"]
COMMON_PASSIVES = [
    "agir_kursun", "cevik_cizme", "fazladan_mermi", "hizli_doldurma", "hizli_parmak", "miknatis", "saglam_yelek",
]
ALL = [*ACTIVES, *EVOLUTIONS, *PASSIVES, *COMMON_PASSIVES]


def icon_out(name: str) -> Path:
    return OUT_ICONS / (name.replace("_", "-") + ".png")


def run(check: bool) -> int:
    bad = 0
    for name in ALL:
        out = icon_out(name)
        if check:
            bad += int(not out.exists())
            continue
        make_icon(SRC_ICONS / f"{name}.png").save(out, optimize=True)
    return 1 if bad else 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    sys.exit(run(ap.parse_args().check))
