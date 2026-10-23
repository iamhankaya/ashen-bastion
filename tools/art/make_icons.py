"""Uygulama ikonu üretimi: art/ref/uygulama-ikonu-kaynak.png -> assets/icon/*.png (+ docs/dev/icon-preview.png).

python tools/art/make_icons.py [--preview] [--verify]

Kaynakta cam çerçeve + koyu dış alan vardır; `CROP` yalnız iç sanatı alır (çerçeve köşeleri dışarıda kalır).
- main_192x192: tam kırpılmış sanat (legacy).
- background_432x432: kırpılmış sanat 432 tuvalin ortasına `ART_SCALE` ile küçülür (adaptive maske
  yalnız ortadaki 288 px'i gösterir; şapka-ay-silah dairede kalsın diye); çevre, aynı sanatın
  bulanık/koyu büyütülmüş hâliyle dolar.
- foreground_432x432: tamamen saydam (karakter zaten arka planın parçası).
- monochrome_432x432: beyaz silüet (ay halkası + şapkalı karakter), 264 px güvenli bölgede.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art" / "ref" / "uygulama-ikonu-kaynak.png"
OUT = ROOT / "assets" / "icon"
PREVIEW = ROOT / "docs" / "dev" / "icon-preview.png"

CROP = (125, 115, 1130, 1120)       # kaynak px: çerçevesiz iç sanat (kare)
ART_SCALE = 0.64                    # background'da sanatın tuval oranı
SAFE = 264                          # adaptive güvenli bölge (px, 432 tuvalde)
VISIBLE = 288                       # en geniş maske (daire) çapı

# Kaynak px koordinatları: ay (daire) ve karakter silüeti (kaba çokgen, şapka-pelerin-silah).
MOON = (637, 400, 365)
CHAR = [
    (462, 198), (500, 205), (522, 240), (548, 262), (560, 300), (620, 358), (535, 345),
    (565, 385), (600, 410), (625, 460), (640, 560), (640, 640), (690, 740), (790, 990),
    (785, 1060), (725, 1068), (665, 1000), (650, 900), (655, 1000), (665, 1100), (610, 1190),
    (530, 1185), (520, 1110), (330, 1110), (130, 1135), (40, 1085), (130, 940), (60, 885),
    (200, 750), (190, 650), (250, 560), (300, 480), (330, 400), (372, 345), (345, 298),
    (400, 285), (440, 255),
]
WHITE = (255, 255, 255)


def load_art() -> Image.Image:
    return Image.open(SRC).convert("RGB").crop(CROP)


def make_main(art: Image.Image) -> Image.Image:
    return art.resize((192, 192), Image.LANCZOS)


def make_background(art: Image.Image) -> Image.Image:
    n = 432
    base = art.resize((n, n), Image.LANCZOS)
    big = art.resize((int(n * 1.5),) * 2, Image.LANCZOS)
    o = (big.width - n) // 2
    bg = big.crop((o, o, o + n, o + n)).filter(ImageFilter.GaussianBlur(14))
    bg = Image.eval(bg, lambda v: int(v * 0.55))
    s = round(n * ART_SCALE)
    fg = art.resize((s, s), Image.LANCZOS)
    m = Image.new("L", (s, s), 0)
    f = 18
    ImageDraw.Draw(m).rectangle((f, f, s - f, s - f), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(f / 2.5))
    bg.paste(fg, ((n - s) // 2, (n - s) // 2), m)
    del base
    return bg


def make_foreground() -> Image.Image:
    return Image.new("RGBA", (432, 432), (0, 0, 0, 0))


def make_monochrome() -> Image.Image:
    ss = 4
    n = 432 * ss
    mx, my, mr = MOON
    xs = [p[0] for p in CHAR] + [mx - mr, mx + mr]
    ys = [p[1] for p in CHAR] + [my - mr, my + mr]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    sc = (SAFE - 4) * ss / max(x1 - x0, y1 - y0)
    ox = n / 2 - (x0 + x1) / 2 * sc
    oy = n / 2 - (y0 + y1) / 2 * sc

    def t(p):
        return (p[0] * sc + ox, p[1] * sc + oy)

    cx, cy = t((mx, my))
    r = mr * sc
    ring = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(ring)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    d.ellipse((cx - r * 0.82, cy - r * 0.82, cx + r * 0.82, cy + r * 0.82), fill=0)
    char = Image.new("L", (n, n), 0)
    ImageDraw.Draw(char).polygon([t(p) for p in CHAR], fill=255)
    # karakterin etrafında ay halkasında boşluk (silüet okunsun)
    gap = char.filter(ImageFilter.MaxFilter(8 * ss + 1))
    ring = Image.composite(Image.new("L", (n, n), 0), ring, gap)
    a = np.maximum(np.asarray(ring), np.asarray(char))
    a = Image.fromarray(a).resize((432, 432), Image.LANCZOS)
    out = Image.new("RGBA", (432, 432), WHITE + (0,))
    out.putalpha(a)
    return out


def outputs() -> dict[str, Image.Image]:
    art = load_art()
    return {
        "main_192x192.png": make_main(art),
        "foreground_432x432.png": make_foreground(),
        "background_432x432.png": make_background(art),
        "monochrome_432x432.png": make_monochrome(),
    }


# ---- önizleme ----
def mask_shape(kind: str, n: int) -> Image.Image:
    m = Image.new("L", (n * 4, n * 4), 0)
    d = ImageDraw.Draw(m)
    b = (0, 0, n * 4 - 1, n * 4 - 1)
    if kind == "daire":
        d.ellipse(b, fill=255)
    elif kind == "squircle":
        d.rounded_rectangle(b, radius=int(n * 4 * 0.3), fill=255)
    else:
        d.rounded_rectangle(b, radius=int(n * 4 * 0.06), fill=255)
    return m.resize((n, n), Image.LANCZOS)


def adaptive(bg: Image.Image, fg: Image.Image, kind: str, n: int) -> Image.Image:
    comp = bg.convert("RGBA")
    comp.alpha_composite(fg)
    o = (432 - VISIBLE) // 2
    vis = comp.crop((o, o, o + VISIBLE, o + VISIBLE)).resize((n, n), Image.LANCZOS)
    vis.putalpha(mask_shape(kind, n))
    return vis


def preview(imgs: dict[str, Image.Image]) -> Image.Image:
    bg, fg = imgs["background_432x432.png"], imgs["foreground_432x432.png"]
    mono = imgs["monochrome_432x432.png"]
    main = imgs["main_192x192.png"]
    pad, W = 12, 192
    sheet = Image.new("RGBA", (pad + 4 * (W + pad), pad + (W + pad) * 2), (40, 40, 48, 255))
    x = pad
    for kind in ("daire", "squircle", "kare"):
        sheet.alpha_composite(adaptive(bg, fg, kind, W), (x, pad))
        x += W + pad
    # Android 13 temalı: açık arka plan + beyaz silüeti koyu renkle
    th = Image.new("RGBA", (432, 432), (208, 188, 255, 255))
    tint = Image.new("RGBA", (432, 432), (56, 30, 114, 255))
    tint.putalpha(mono.getchannel("A"))
    th.alpha_composite(tint)
    sheet.alpha_composite(adaptive(th, fg, "daire", W), (x, pad))
    y = pad + W + pad
    sheet.alpha_composite(main.convert("RGBA"), (pad, y))
    x = pad + W + pad
    for s in (72, 48):
        for kind in ("daire", "squircle"):
            sheet.alpha_composite(adaptive(bg, fg, kind, s), (x, y))
            x += s + pad
    # 48 px legacy
    sheet.alpha_composite(main.resize((48, 48), Image.LANCZOS).convert("RGBA"), (x, y))
    return sheet.convert("RGB")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true", help="docs/dev/icon-preview.png üretir")
    ap.add_argument("--verify", action="store_true", help="yazmadan, commit'li çıktılar taze mi?")
    a = ap.parse_args()
    imgs = outputs()
    if a.verify:
        bad = [n for n, im in imgs.items()
               if not (OUT / n).exists() or np.abs(np.asarray(Image.open(OUT / n)).astype(int) - np.asarray(im).astype(int)).max() > 0]
        print("eski/eksik:", bad or "yok")
        return 1 if bad else 0
    OUT.mkdir(parents=True, exist_ok=True)
    for n, im in imgs.items():
        im.save(OUT / n, optimize=True)
    if a.preview:
        PREVIEW.parent.mkdir(parents=True, exist_ok=True)
        preview(imgs).save(PREVIEW, optimize=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
