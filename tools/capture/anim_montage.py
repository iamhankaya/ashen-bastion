#!/usr/bin/env python3
"""shots_anim.gd çıktısından küçültülmüş PNG şerit: python tools/capture/anim_montage.py <dizin> <senaryo> <çıktı.png> [her_n_kare=2]

Oyuncunun çevresi kırpılır (kamera oyuncuyu izler), her n. kare yan yana dizilir, üstüne kare no + etiket yazılır."""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

d, scen, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
step = int(sys.argv[4]) if len(sys.argv) > 4 else 2
rows = json.loads((d / (scen + ".json")).read_text())
CROP = (200, 110, 520, 440)
SCALE = 0.5
tiles = []
for r in rows[::step]:
    im = Image.open(d / ("%s_%02d.png" % (scen, r["i"]))).convert("RGB").crop(CROP)
    dr = ImageDraw.Draw(im)
    dr.rectangle([0, 0, im.width, 14], fill=(0, 0, 0))
    dr.text((3, 2), "k%d %s a0=%.0f" % (r["i"], r["label"], r["arm0_world_deg"]), fill=(255, 255, 255))
    tiles.append(im.resize((int(im.width * SCALE), int(im.height * SCALE)), Image.LANCZOS))
w, h = tiles[0].size
cols = 6
nrows = (len(tiles) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * nrows))
for i, t in enumerate(tiles):
    sheet.paste(t, ((i % cols) * w, (i // cols) * h))
sheet.save(out, optimize=True)
print("yazıldı:", out, sheet.size)
