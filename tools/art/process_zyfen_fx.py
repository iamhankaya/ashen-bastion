"""Zyfen ikonları ve rüzgar efekt dokuları: art/source/zyfen/{icons,fx} -> assets/.

python tools/art/process_zyfen_fx.py [--check]

- İkon: alfa kutusuna kırp, uzun kenar %80 olacak şekilde ortala, kare ICON_SIZE tuval.
  13 rüzgar becerisi assets/ui/icons/<id-tireli>.png, 7 ortak pasif varyantı assets/ui/icons/zyfen/<ortak-id-tireli>.png.
- Efekt: her kenarda en az MARGIN (%8) şeffaf pay (kenara ulaşan sönük pikseller silinir, tuval gerekirse büyür),
  uzun kenar en çok FX_MAX px. Çıktı assets/gfx/fx/zyfen/<ad>.png.
Kaynaklar (art/) export dışıdır.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC_ICONS = ROOT / "art" / "source" / "zyfen" / "icons"
SRC_FX = ROOT / "art" / "source" / "zyfen" / "fx"
OUT_ICONS = ROOT / "assets" / "ui" / "icons"
OUT_FX = ROOT / "assets" / "gfx" / "fx" / "zyfen"

ICON_SIZE = 256
ICON_FILL = 0.80
FX_MAX = 512
MARGIN = 0.08
ALPHA_EPS = 3          # bu değerin altındaki alfa "boş" sayılır (kenar payı denetimi)

WIND_SKILLS = [
    "ruzgar_kesigi", "hava_bicaklari", "delen_ruzgar", "bolunen_kesik", "girdap", "hortum", "hava_cebi",
    "nefes_dalgasi", "furtina_gozu", "ay_oragi", "kasirga_patlamasi", "gogun_mizragi", "tufan",
]
# Zyfen pasif adı -> ortak pasif kimliği (variants.zyfen.icon dosya adı)
PASSIVE_VARIANTS = {
    "bilenmis_ruzgar": "agir_kursun", "ruzgar_adimi": "cevik_cizme", "derin_nefes": "fazladan_mermi",
    "cabuk_toplayis": "hizli_doldurma", "cevik_eller": "hizli_parmak", "ceken_esinti": "miknatis",
    "yas_paltosu": "saglam_yelek",
}
FX_NAMES = [
    "fx_kesik", "fx_ay_oragi", "fx_hava_bicagi", "fx_kesik_parca", "fx_mizrak", "fx_gok_mizragi", "fx_girdap",
    "fx_hortum", "fx_tufan", "fx_hava_cebi", "fx_dalga", "fx_kasirga", "fx_avuc",
]


def icon_out(name: str) -> Path:
    if name in PASSIVE_VARIANTS:
        return OUT_ICONS / "zyfen" / (PASSIVE_VARIANTS[name].replace("_", "-") + ".png")
    return OUT_ICONS / (name.replace("_", "-") + ".png")


def make_icon(src: Path) -> Image.Image:
    im = Image.open(src).convert("RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v > ALPHA_EPS else 0).getbbox()
    if box is None:
        raise ValueError(f"{src.name}: tamamen saydam")
    im = im.crop(box)
    s = ICON_SIZE * ICON_FILL / max(im.size)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    out.alpha_composite(im, ((ICON_SIZE - im.width) // 2, (ICON_SIZE - im.height) // 2))
    return out


def make_fx(src: Path) -> Image.Image:
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im.getchannel("A"))
    ys, xs = np.nonzero(a > ALPHA_EPS)
    if len(xs) == 0:
        raise ValueError(f"{src.name}: tamamen saydam")
    # İçerik kutusuna göre tuvali yeniden kur: her kenarda >= MARGIN pay (uzun kenarın oranı), merkez korunur.
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cw, ch = x1 - x0, y1 - y0
    # Orijinal en-boy oranı (1:1, 2:1, 3:1) korunur: pivot (0.5, 0.5) tuval merkezi olsun.
    cx, cy = im.width / 2, im.height / 2
    half_w = max(cx - x0, x1 - cx)
    half_h = max(cy - y0, y1 - cy)
    ratio = im.width / im.height
    w = 2 * half_w / (1 - 2 * MARGIN)
    h = 2 * half_h / (1 - 2 * MARGIN)
    if w / h > ratio:
        h = w / ratio
    else:
        w = h * ratio
    W, H = int(np.ceil(w)), int(np.ceil(h))
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    arr = np.asarray(im).copy()
    arr[a <= ALPHA_EPS] = 0
    canvas.alpha_composite(Image.fromarray(arr), (round((W - im.width) / 2), round((H - im.height) / 2)))
    s = min(1.0, FX_MAX / max(W, H))
    if s < 1.0:
        canvas = canvas.resize((max(1, round(W * s)), max(1, round(H * s))), Image.LANCZOS)
    return canvas


def margin_ok(im: Image.Image, frac: float = MARGIN - 0.005) -> bool:
    a = np.asarray(im.getchannel("A"))
    h, w = a.shape
    mx, my = int(w * frac), int(h * frac)
    return not (a[:my].any() or a[h - my:].any() or a[:, :mx].any() or a[:, w - mx:].any())


def run(check: bool) -> int:
    bad = 0
    for name in [*WIND_SKILLS, *PASSIVE_VARIANTS]:
        out = icon_out(name)
        im = make_icon(SRC_ICONS / f"{name}.png")
        if check:
            bad += int(not out.exists())
        else:
            out.parent.mkdir(parents=True, exist_ok=True)
            im.save(out, optimize=True)
    for name in FX_NAMES:
        out = OUT_FX / f"{name}.png"
        im = make_fx(SRC_FX / f"{name}.png")
        ok = margin_ok(im)
        print(f"{name}: {im.size} pay {'OK' if ok else 'YETERSİZ'}")
        bad += int(not ok)
        if check:
            bad += int(not out.exists())
        else:
            out.parent.mkdir(parents=True, exist_ok=True)
            im.save(out, optimize=True)
    return 1 if bad else 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    sys.exit(run(ap.parse_args().check))
