"""Zyfen ikonları ve rüzgar efekt dokuları: art/source/zyfen/{icons,fx_v2} -> assets/.

python tools/art/process_zyfen_fx.py [--check]

- İkon: alfa kutusuna kırp, uzun kenar %80 olacak şekilde ortala, kare ICON_SIZE tuval.
  13 rüzgar becerisi assets/ui/icons/<id-tireli>.png, 7 ortak pasif varyantı assets/ui/icons/zyfen/<ortak-id-tireli>.png.
- Efekt (v2, 32 katmanlı parça): her kenarda en az MARGIN (%8) şeffaf pay (kenara ulaşan sönük pikseller silinir, tuval
  gerekirse büyür), uzun kenar FX_V2'deki tavanı aşmaz (mermi/bölge 512, küçük parça 128). `hortum_akis` döşenebilir
  dokudur: pay aranmaz, döşemeye uygun (dikiş çıkarmayan) küçültülür. Çıktı assets/gfx/fx/zyfen/fx_<ad>.png.
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
SRC_FX = ROOT / "art" / "source" / "zyfen" / "fx_v2"
OUT_ICONS = ROOT / "assets" / "ui" / "icons"
OUT_FX = ROOT / "assets" / "gfx" / "fx" / "zyfen"

ICON_SIZE = 256
ICON_FILL = 0.80
FX_MAX = 512
FX_SMALL = 128
FX_MID = 256
TILE_NAME = "hortum_akis"
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
# ad -> (kaynak alt dizini, uzun kenar tavanı). Çıktı adı: fx_<ad>.png
_P, _A, _V = "01_mermiler", "02_alanlar_ve_hortumlar", "03_atis_ve_isabet"
FX_V2 = {
    "kesik": (_P, FX_MAX), "kesik_iz": (_P, FX_MAX), "kesik_parca": (_P, FX_MAX), "kesik_kirilma": (_P, FX_MAX),
    "ay_oragi": (_P, FX_MAX), "ay_oragi_iz": (_P, FX_MAX), "parilti": (_P, FX_SMALL),
    "hava_bicagi": (_P, FX_MAX), "mizrak": (_P, FX_MAX), "mizrak_uc": (_P, FX_MAX),
    "gok_mizragi": (_P, FX_MAX), "gok_isik": (_P, FX_MID),
    "hortum_govde": (_A, FX_MAX), "hortum_akis": (_A, FX_MID), "hortum_taban": (_A, FX_MAX),
    "tas_1": (_A, FX_SMALL), "tas_2": (_A, FX_SMALL), "tas_3": (_A, FX_SMALL), "tas_4": (_A, FX_SMALL),
    "tufan_govde": (_A, FX_MAX), "tufan_taban": (_A, FX_MAX), "simsek_1": (_A, FX_MID), "simsek_2": (_A, FX_MID),
    "girdap": (_A, FX_MAX), "girdap_ic": (_A, FX_MAX), "hava_cebi": (_A, FX_MAX), "hava_cebi_patlama": (_A, FX_MAX),
    "dalga": (_A, FX_MAX), "kasirga": (_A, FX_MAX),
    "avuc": (_V, FX_MAX), "isabet": (_V, FX_MAX), "isabet_buyuk": (_V, FX_MAX),
}
FX_NAMES = list(FX_V2)
# v2 öncesi 13 doku (yerine yenileri geldi); bulunursa silinir.
FX_STALE = ["fx_hortum", "fx_tufan"]


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


def resize_premult(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Önceden çarpılmış alfa ile küçült: şeffaf piksellerin rengi kenara karanlık sızdırmaz."""
    a = np.asarray(im, dtype=np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    chans = [Image.fromarray(a[..., c]).resize(size, Image.LANCZOS) for c in range(4)]
    out = np.stack([np.asarray(c, dtype=np.float32) for c in chans], axis=-1)
    alpha = np.clip(out[..., 3:4], 0.0, 1.0)
    rgb = np.where(alpha > 1e-4, out[..., :3] / np.maximum(alpha, 1e-4), 0.0)
    res = np.concatenate([np.clip(rgb, 0, 1), alpha], axis=-1)
    return Image.fromarray((res * 255.0 + 0.5).astype(np.uint8), "RGBA")


def make_tile(src: Path, cap: int) -> Image.Image:
    """Döşenebilir doku (kaynak dikişsiz çizilmiş): 3x3 döşenip küçültülür ve ortası alınır; kenar pikselleri komşu kareden
    gelir, küçültme dikiş çıkarmaz."""
    im = Image.open(src).convert("RGBA")
    n = min(cap, max(im.size))
    big = Image.new("RGBA", (im.width * 3, im.height * 3))
    for i in range(3):
        for j in range(3):
            big.paste(im, (i * im.width, j * im.height))
    big = resize_premult(big, (n * 3, n * 3))
    return big.crop((n, n, 2 * n, 2 * n))


def make_fx(src: Path, cap: int = FX_MAX) -> Image.Image:
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
    s = min(1.0, cap / max(W, H))
    if s < 1.0:
        canvas = resize_premult(canvas, (max(1, round(W * s)), max(1, round(H * s))))
        arr = np.asarray(canvas).copy()
        arr[arr[..., 3] <= ALPHA_EPS] = 0  # küçültme halkalanması kenar payına sönük piksel sızdırmasın
        canvas = Image.fromarray(arr, "RGBA")
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
    for name, (sub, cap) in FX_V2.items():
        out = OUT_FX / f"fx_{name}.png"
        if name == TILE_NAME:
            im = make_tile(SRC_FX / sub / f"{name}.png", cap)
            ok = True
        else:
            im = make_fx(SRC_FX / sub / f"{name}.png", cap)
            ok = margin_ok(im)
        print(f"{name}: {im.size} pay {'OK' if ok else 'YETERSİZ'}")
        bad += int(not ok)
        if check:
            bad += int(not out.exists())
        else:
            out.parent.mkdir(parents=True, exist_ok=True)
            im.save(out, optimize=True)
    for stale in FX_STALE:
        for ext in ("", ".import"):
            f = OUT_FX / f"{stale}.png{ext}"
            if f.exists() and not check:
                f.unlink()
    return 1 if bad else 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    sys.exit(run(ap.parse_args().check))
