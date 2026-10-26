#!/usr/bin/env python3
"""Maket kırpmaları: mevcut oyun sanatından (art/ref/harita) yeşil perde silinerek türetilir. Yeni görsel üretilmez."""
import numpy as np, pathlib
from PIL import Image, ImageFilter
R = pathlib.Path(__file__).resolve().parents[4]
OUT = pathlib.Path(__file__).parent / "assets"
def key(im):
    a = np.array(im.convert("RGBA")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    gr = g - np.maximum(r, b)
    alpha = np.clip(1 - (gr - 25) / 60, 0, 1)            # yeşil baskınsa saydam
    a[..., 3] = alpha * 255
    spill = gr > 0
    a[..., 1] = np.where(spill, np.maximum(r, b) + np.minimum(gr, 0), g)   # yeşil taşmasını bastır
    return Image.fromarray(a.astype("uint8"), "RGBA")
from scipy import ndimage
def keep_main(im):
    a = np.array(im); lab, n = ndimage.label(a[..., 3] > 20, structure=np.ones((3, 3)))
    if n == 0: return im
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.15 * sizes.max()]
    a[..., 3] = np.where(np.isin(lab, keep), a[..., 3], 0)
    return Image.fromarray(a, "RGBA")
def feather(im, side=36, bottom=0):
    a = np.array(im).astype(float); h, w = a.shape[:2]
    fy = np.ones(h); fx = np.ones(w)
    fx[:side] = np.linspace(0, 1, side); fx[-side:] = np.minimum(fx[-side:], np.linspace(1, 0, side))
    fy[:side] = np.linspace(0, 1, side)
    b = bottom or side
    fy[-b:] = np.minimum(fy[-b:], np.linspace(1, 0, b) ** 1.2)
    a[..., 3] *= fy[:, None] * fx[None, :]
    return Image.fromarray(a.astype("uint8"), "RGBA")
src = Image.open(R / "art/ref/harita/harabe-parcalari.png")
crops = {"kemer": (860, 0, 1300, 410), "kule": (500, 5, 900, 490), "sancak1": (1125, 435, 1255, 770),
         "sancak2": (1262, 425, 1412, 770), "mesale": (1196, 706, 1272, 796), "sur": (0, 30, 500, 400)}
for n, bx in crops.items():
    c = keep_main(key(src.crop(bx))); c = c.crop(c.getbbox())
    if n in ("kemer", "kule", "sur"): c = feather(c, 30, 150)
    elif n == "mesale": c = feather(c, 10, 10)
    c.save(OUT / f"{n}.png"); print(n, c.size)
# zemin yaması: zemin-doku'dan eliptik, kenarı yumuşak maske
z = Image.open(R / "art/ref/harita/zemin-doku.png").convert("RGB").crop((100, 300, 1100, 700)).resize((800, 320))
m = Image.new("L", (800, 320), 0)
yy, xx = np.mgrid[0:320, 0:800]
d = ((xx - 400) / 400) ** 2 + ((yy - 160) / 160) ** 2
mask = np.clip((1 - d) * 2.2, 0, 1)
Image.fromarray((mask * 255).astype("uint8")).save(OUT / "_mask.png")
zz = z.convert("RGBA"); zz.putalpha(Image.fromarray((mask * 255).astype("uint8")))
zz.save(OUT / "zemin-yama.png")
# karakter: yatay kenar eritme (namlu alevi kaynak kenarında kesik)
h = Image.open(R / "docs/ui/mockups/assets/gunslinger-atis-keyed.png").convert("RGBA")
a = np.array(h).astype(float); w = a.shape[1]
f = np.ones(w); n = 56
f[:n] = np.linspace(0, 1, n) ** 1.5; f[-n:] = np.linspace(1, 0, n) ** 1.5
a[..., 3] *= f[None, :]
Image.fromarray(a.astype("uint8"), "RGBA").save(OUT / "karakter-eritme.png")
(OUT / "_mask.png").unlink()
