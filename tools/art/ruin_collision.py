"""Katı harabeler için çarpışma dairelerini görselin taban izinden üretir (`data/ruins.json` -> `collision`).

    python3 tools/art/ruin_collision.py            # ruins.json'u günceller
    python3 tools/art/ruin_collision.py --check    # yazmaz; veri güncel değilse 1 ile çıkar
    python3 tools/art/ruin_collision.py --preview out.png   # daireler bindirilmiş kontakt sayfası

Kural: oyuncudan (200 px) uzun yapılar katıdır (`SOLID_MIN_HEIGHT`), alçak parçalar zemin dekorudur
(`solid: false`, çarpışması yok). Katı yapının taban izi, sprite'ın en alt opak kenarı (sütun başına en alçak
opak piksel) boyunca dizilen dairelerdir: daire merkezi bu kenarın `r` kadar üstündedir, böylece `2r` derinliğinde
bir şerit kaplanır. Koordinatlar `foot` noktasına göre, dünya pikseli (display_scale uygulanmış).
Bayrak/meşale gibi ince direkli yapılarda (`POLE`) yalnız direk tabanı daireleri alınır (kumaş ucu taban değildir).
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
RUINS = ROOT / "data" / "ruins.json"
SOLID_MIN_HEIGHT = 240.0  # dünya px; oyuncu ~200 px
ALPHA = 40
R_MIN, R_MAX = 28.0, 44.0
SPACING = 0.9  # daire aralığı / yarıçap
# direkli yapılar: tabandaki yatay aralık (sprite px, foot'a göre x) ve taban yüksekliği oranı
POLE = {
    "ruin_08": {"half_w": 22, "r": 26.0},
    "ruin_09": {"half_w": 14, "r": 24.0},
    "ruin_23": {"half_w": 20, "r": 28.0},
}


def load():
    return json.loads(RUINS.read_text())


def sprite(rec):
    return Image.open(ROOT / rec["sprite"].replace("res://", "")).convert("RGBA")


def world_height(rec, im):
    a = np.asarray(im.getchannel("A")) > ALPHA
    ys = np.where(a.any(axis=1))[0]
    return (ys.max() - ys.min() + 1) * rec["display_scale"]


def bottom_contour(im):
    """Sütun başına en alçak opak piksel (yok = -1), 7'li medyanla düzgünleştirilmiş."""
    a = np.asarray(im.getchannel("A")) > ALPHA
    h, w = a.shape
    yb = np.full(w, -1.0)
    for x in range(w):
        ys = np.where(a[:, x])[0]
        if ys.size:
            yb[x] = ys.max()
    out = yb.copy()
    for x in range(w):
        win = yb[max(0, x - 3) : x + 4]
        win = win[win >= 0]
        if win.size:
            out[x] = np.median(win)
    return out


def circles_for(rec, im):
    k = rec["display_scale"]
    fx = rec["foot"][0] * im.width
    fy = rec["foot"][1] * im.height
    pole = POLE.get(rec["id"])
    if pole:
        r = pole["r"]
        return [{"x": 0.0, "y": round(-r * 0.9, 1), "r": r}]
    r = min(R_MAX, max(R_MIN, rec["footprint"]["h"] * 0.5))
    yb = bottom_contour(im)
    xs = np.where(yb >= 0)[0]
    x0, x1 = xs.min() * k, xs.max() * k
    # uç daireler kenarı r kadar içeriden tutar: sprite kenarı ince/ucu sivri olabilir
    start, stop = x0 + r * 0.6, x1 - r * 0.6
    n = max(1, int(np.ceil((stop - start) / (r * SPACING))) + 1)
    out = []
    for i in range(n):
        xw = start if n == 1 else start + (stop - start) * i / (n - 1)
        col = int(np.clip(round(xw / k), 0, im.width - 1))
        # daire altındaki sütunların en alçağı (daireyi taban çizgisine oturtur)
        lo = max(0, col - int(r / k * 0.5))
        hi = min(im.width, col + int(r / k * 0.5) + 1)
        base = yb[lo:hi][yb[lo:hi] >= 0].max()
        out.append({"x": round(xw - fx * k, 1), "y": round((base - fy) * k - r * 0.9, 1), "r": r})
    return out


def build():
    recs = load()
    for rec in recs:
        im = sprite(rec)
        solid = bool(world_height(rec, im) >= SOLID_MIN_HEIGHT)
        rec["solid"] = solid
        if solid:
            rec["collision"] = circles_for(rec, im)
            rec["weight"] = 1
        else:
            rec.pop("collision", None)
            rec["weight"] = 3
    return recs


def preview(recs, path):
    W = 1900
    x = y = 10
    rowh = 0
    tiles = []
    for rec in recs:
        im = sprite(rec)
        s = 0.8
        k = rec["display_scale"] * s
        im = im.resize((int(im.width * rec["display_scale"] * s), int(im.height * rec["display_scale"] * s)))
        bg = Image.new("RGBA", im.size, (60, 60, 60, 255))
        bg.alpha_composite(im)
        d = ImageDraw.Draw(bg)
        fx = rec["foot"][0] * im.width
        fy = rec["foot"][1] * im.height
        for c in rec.get("collision", []):
            cx, cy, r = fx + c["x"] * s, fy + c["y"] * s, c["r"] * s
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 220, 0))
        d.ellipse([fx - 3, fy - 3, fx + 3, fy + 3], fill=(255, 0, 0))
        d.text((3, 3), rec["id"] + (" S" if rec["solid"] else " d"), fill=(255, 255, 255))
        tiles.append(bg)
    for bg in tiles:
        if x + bg.width > W:
            x, y, rowh = 10, y + rowh + 10, 0
        tiles_xy = (x, y)
        x += bg.width + 10
        rowh = max(rowh, bg.height)
        bg.info["xy"] = tiles_xy
    sheet = Image.new("RGB", (W, y + rowh + 10), (60, 60, 60))
    for bg in tiles:
        sheet.paste(bg.convert("RGB"), bg.info["xy"])
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--preview")
    a = ap.parse_args()
    recs = build()
    text = json.dumps(recs, indent=2) + "\n"
    if a.preview:
        preview(recs, a.preview)
    if a.check:
        if RUINS.read_text() != text:
            print("data/ruins.json güncel değil: python3 tools/art/ruin_collision.py", file=sys.stderr)
            return 1
        return 0
    RUINS.write_text(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
