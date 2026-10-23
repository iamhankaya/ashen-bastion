#!/usr/bin/env python3
"""shots_walk.gd çıktısından montaj + tablo: python tools/capture/walk_montage.py <shots_dizini> <çıktı.png> [kare_sayısı]

Her ekran görüntüsünden oyuncunun çevresi kırpılır (kamera oyuncuyu izler: zemin cetveli geriye akar), kareler yan yana
dizilir; altlarına ölçülen basan ayak x'i (synthetic modda) yazılır."""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

d = Path(sys.argv[1])
out = Path(sys.argv[2])
n = int(sys.argv[3]) if len(sys.argv) > 3 else 8
rows = json.loads((d / "walk.json").read_text())[:n]
CROP = (180, 105, 540, 450)  # ekran: oyuncunun boyu (kamera zoom 1,5; ayak çizgisi altta)
tiles = []
for r in rows:
    im = Image.open(d / ("walk_%02d.png" % r["i"])).convert("RGB").crop(CROP)
    dr = ImageDraw.Draw(im)
    m = r.get("magenta_x") or r.get("cyan_x")
    label = "k%d" % r["frame"] + ("  ayak x=%.1f" % m if m else "")
    dr.rectangle([0, 0, im.width, 14], fill=(0, 0, 0))
    dr.text((3, 2), label, fill=(255, 255, 255))
    tiles.append(im)
sheet = Image.new("RGB", ((CROP[2] - CROP[0]) * len(tiles), CROP[3] - CROP[1]))
for i, t in enumerate(tiles):
    sheet.paste(t, (i * (CROP[2] - CROP[0]), 0))
sheet.save(out)
print("yazıldı:", out, sheet.size)
