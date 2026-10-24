#!/usr/bin/env python3
"""Zyfen kolsuz rig şeridi (v2.0.2 U2): ayrı şeffaf kareler -> tek yatay şerit + manifest + kalite kapısı.

Kullanım:
  python tools/art/make_zyfen_strip.py --src art/source/zyfen --out assets/gfx/char/zyfen_strip.png \
         --body-out assets/gfx/char/zyfen_body.png --manifest art/source/zyfen/strip_manifest.json \
         --quality art/source/zyfen/quality.json [--walk-cast 'glob'] [--stride 150] [--preview]

Girdi: `<src>/frames/{walk,cast,gather}/*.png` (RGBA, alfa zaten silinmiş), `<src>/zyfen_idle.png` (duruş), isteğe bağlı
`--walk-cast <glob>` (yürürken savuruş seti). Hücre sırası (RigFrames ile aynı): yürüme 0..W-1, duruş W, cast, gather,
walk_cast. Her klip kendi ortanca alfa boyuna göre 320 px yüksekliğe normalize edilir (ayak = hücre alt kenarı); hücre
genişliği HESAPLANIR: tüm klip alfa kutularının en genişi + 2·PAD. Yatay hiza: yürüme/duruş gövde üst yarısının, cast/gather
ayakların (planlı) ağırlık merkezi. `zyfen_body.png` (duruş) aynı piksel ölçeğinde (320 px boy) ayrıca yazılır.
Kalite kapısı (plan U2/2): foot_slide (yürüme, çift başına ≤3 px, ≥ N-2 çift), klip yükseklik sapması ≤ %6,
toplam hücre × genişlik ≤ 8192. Kapı kırmızıysa çıkış kodu 1 ve `quality.json` `pass: false`; sessiz yedek yoktur.
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_strip as ms  # noqa: E402

CELL_H = 320
PAD = 6
MAX_STRIP_W = 8192
HEIGHT_TOL_PCT = 6.0
SLIDE_TOL_PX = 3.0
DISPLAY_HEIGHT = 200.0  # zyfen.json rig.display_height


def _load_rgba(p: str | Path) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGBA"))


def _trim(img: np.ndarray) -> np.ndarray:
    a = img[..., 3]
    ys, xs = np.nonzero(a > 127)
    if len(ys) == 0:
        raise ValueError("kare boş: opak piksel yok")
    return img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def _scaled(img: np.ndarray, scale: float) -> np.ndarray:
    h, w = img.shape[:2]
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    pm = img.astype(np.float32)
    pm[..., :3] *= pm[..., 3:4] / 255.0  # premultiplied: kenar rengi sızmasın
    out = np.asarray(Image.fromarray(pm.astype(np.uint8), "RGBA").resize((nw, nh), Image.LANCZOS)).astype(np.float32)
    a = np.maximum(out[..., 3:4], 1.0)
    out[..., :3] = np.clip(out[..., :3] * 255.0 / a, 0, 255)
    return out.astype(np.uint8)


def _anchor_x(img: np.ndarray, mode: str) -> float:
    """Hücre merkezine oturacak x: 'upper' = üst yarı, 'feet' = alt %40 alfa ağırlık merkezi."""
    a = img[..., 3].astype(np.float64) / 255.0
    h = a.shape[0]
    y0, y1 = (0, max(1, h // 2)) if mode == "upper" else (int(h * 0.6), h)
    return ms._centroid_x(a, y0, y1)


class Clip:
    def __init__(self, name: str, files: list[str], anchor: str):
        self.name, self.anchor = name, anchor
        self.raw = [_trim(_load_rgba(f)) for f in files]
        heights = np.array([r.shape[0] for r in self.raw], dtype=np.float64)
        self.scale = CELL_H / float(heights.max())  # en uzun kare 320 px; ortancadan sapma height_dev_pct
        self.imgs = [_scaled(r, self.scale) for r in self.raw]
        self.height_dev_pct = [round(float((r.shape[0] - np.median(heights)) / np.median(heights) * 100.0), 2) for r in self.raw]
        # ölçekleme sonrası boy hedefi: kare, 320 px'i aşmasın (şapka/el kalkışı varsa kırp yerine uyar)
        self.over = [i.shape[0] for i in self.imgs if i.shape[0] > CELL_H]


def build(src: Path, walk_cast: list[str] | None, stride: float) -> tuple[np.ndarray, np.ndarray, dict]:
    walk_files = sorted(glob.glob(str(src / "frames/walk/*.png")))
    cast_files = sorted(glob.glob(str(src / "frames/cast/*.png")))
    gather_files = sorted(glob.glob(str(src / "frames/gather/*.png")))
    if not (walk_files and cast_files and gather_files):
        raise SystemExit("kare dosyaları eksik: %s/frames/{walk,cast,gather}" % src)
    clips = {
        "walk": Clip("walk", walk_files, "upper"),
        "cast": Clip("cast", cast_files, "feet"),
        "gather": Clip("gather", gather_files, "feet"),
    }
    if walk_cast:
        clips["walk_cast"] = Clip("walk_cast", sorted(walk_cast), "upper")
    idle_raw = _trim(_load_rgba(src / "zyfen_idle.png"))
    idle_scale = CELL_H / idle_raw.shape[0]
    idle = _scaled(idle_raw, idle_scale)
    order = ["walk", "idle", "cast", "gather"] + (["walk_cast"] if "walk_cast" in clips else [])
    seq: list[tuple[str, np.ndarray, str]] = []
    for k in order:
        if k == "idle":
            seq.append(("idle", idle, "upper"))
        else:
            seq += [(k, im, clips[k].anchor) for im in clips[k].imgs]
    ax = [_anchor_x(im, mode) for _, im, mode in seq]
    left = max(a for a in ax)
    right = max(im.shape[1] - a for (_, im, _), a in zip(seq, ax))
    # hücre genişliği: en geniş alfa kutusu + 2·PAD (merkezde ortalı), tek sayı yuvarlanır
    widest = max(im.shape[1] for _, im, _ in seq)
    cw = int(math.ceil(max(widest, 2 * max(left, right)))) + 2 * PAD
    cw += cw % 2
    strip = np.zeros((CELL_H, cw * len(seq), 4), np.uint8)
    for i, ((name, im, _), a) in enumerate(zip(seq, ax)):
        x = int(round(cw / 2.0 - a))
        x = min(max(x, 0), cw - im.shape[1])
        h = min(im.shape[0], CELL_H)
        strip[CELL_H - h:, i * cw + x:i * cw + x + im.shape[1]] = im[-h:]
    # duruş gövdesi: tek hücre genişliği değil, kendi alfa kutusu (PlayerView stand_px/k dünya ölçeği)
    body = idle
    n_walk = len(clips["walk"].imgs)
    res = ms.StripResult(
        strip[:, : n_walk * cw], {"cell": [cw, CELL_H], "frames": n_walk}, clips["walk"].scale, []
    )
    wpp = DISPLAY_HEIGHT / CELL_H
    fs = ms.foot_slide(res, stride, wpp, SLIDE_TOL_PX)
    manifest = {
        "cells": len(seq),
        "cell": [cw, CELL_H],
        "strip_width": int(strip.shape[1]),
        "walk": {"frames": n_walk, "scale": round(clips["walk"].scale, 5)},
        "cast": {"frames": len(clips["cast"].imgs), "scale": round(clips["cast"].scale, 5)},
        "gather": {"frames": len(clips["gather"].imgs), "scale": round(clips["gather"].scale, 5)},
        "idle": {"index": n_walk, "scale": round(idle_scale, 5)},
        "body_scale": round(idle_scale, 5),
        "stride": stride,
        "foot_slide": fs,
        "height_dev_pct": {k: c.height_dev_pct for k, c in clips.items()},
    }
    if "walk_cast" in clips:
        manifest["walk_cast"] = {"frames": len(clips["walk_cast"].imgs), "scale": round(clips["walk_cast"].scale, 5)}
    return strip, body, manifest


def gate(manifest: dict) -> dict:
    fs = manifest["foot_slide"]
    worst_h = max(abs(v) for devs in manifest["height_dev_pct"].values() for v in devs)
    checks = {
        "foot_slide": bool(fs["pass"]),
        "height_dev": worst_h <= HEIGHT_TOL_PCT,
        "strip_width": manifest["strip_width"] <= MAX_STRIP_W,
    }
    return {
        "pass": all(checks.values()),
        "checks": checks,
        "foot_slide_ok_pairs": fs["ok_pairs"],
        "foot_slide_total_pairs": fs["total_pairs"],
        "foot_slide_pair_err_px": fs["pair_err_px"],
        "worst_height_dev_pct": round(float(worst_h), 2),
        "strip_width": manifest["strip_width"],
    }


def write_preview(strip: np.ndarray, cw: int, labels: list[str], out: Path) -> None:
    from PIL import ImageDraw

    n = strip.shape[1] // cw
    sheet = Image.new("RGBA", (strip.shape[1], CELL_H * 2 + 36), (23, 16, 25, 255))
    for row, bg in enumerate(((3, 157, 8), (23, 16, 25))):
        y = row * (CELL_H + 18)
        sheet.paste(Image.new("RGBA", (strip.shape[1], CELL_H + 18), bg + (255,)), (0, y))
        sheet.alpha_composite(Image.fromarray(strip, "RGBA"), (0, y + 18))
        d = ImageDraw.Draw(sheet)
        for i in range(n):
            x = i * cw
            d.line([(x, y + 18 + CELL_H - 1), (x + cw, y + 18 + CELL_H - 1)], fill=(255, 40, 40, 255))
            d.line([(x + cw // 2, y + 18), (x + cw // 2, y + 18 + CELL_H)], fill=(40, 220, 220, 255))
            d.line([(x, y + 18), (x, y + 18 + CELL_H)], fill=(255, 255, 255, 90))
            d.text((x + 4, y + 3), labels[i], fill=(255, 255, 255, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default="art/source/zyfen")
    ap.add_argument("--out", required=True, help="şerit PNG")
    ap.add_argument("--body-out", required=True, help="duruş gövdesi PNG (aynı piksel ölçeği)")
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--quality", required=True, help="kalite kapısı sonucu (quality.json)")
    ap.add_argument("--walk-cast", help="isteğe bağlı walk_cast kareleri (glob)")
    ap.add_argument("--stride", type=float, default=150.0, help="yürüme çevrimi uzunluğu (dünya px; zyfen.json walk.stride)")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--preview-dir", default=str(Path(__file__).resolve().parent / "_preview"))
    args = ap.parse_args(argv)
    wc = sorted(glob.glob(args.walk_cast)) if args.walk_cast else None
    strip, body, manifest = build(Path(args.src), wc, args.stride)
    q = gate(manifest)
    for p, data in ((args.manifest, manifest), (args.quality, q)):
        Path(p).parent.mkdir(parents=True, exist_ok=True)
        Path(p).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(strip, "RGBA").save(args.out, optimize=True)
    Image.fromarray(body, "RGBA").save(args.body_out, optimize=True)
    if args.preview:
        labels = [f"w{i}" for i in range(manifest["walk"]["frames"])] + ["idle"]
        labels += [f"c{i}" for i in range(manifest["cast"]["frames"])] + [f"g{i}" for i in range(manifest["gather"]["frames"])]
        labels += [f"wc{i}" for i in range(manifest.get("walk_cast", {}).get("frames", 0))]
        pv = Path(args.preview_dir) / "zyfen_strip_preview.png"
        write_preview(strip, manifest["cell"][0], labels, pv)
        print("önizleme:", pv)
    fs = manifest["foot_slide"]
    print("hücre=%s toplam=%d genişlik=%d  ayak kayması %d/%d çift ≤%.0f px  boy sapması ≤%.2f%%  → %s" % (
        manifest["cell"], manifest["cells"], manifest["strip_width"], fs["ok_pairs"], fs["total_pairs"],
        SLIDE_TOL_PX, q["worst_height_dev_pct"], "GEÇTİ" if q["pass"] else "KALDI"))
    if not q["pass"]:
        print("KALITE KAPISI KIRMIZI:", {k: v for k, v in q["checks"].items() if not v}, "pair_err_px=", fs["pair_err_px"], file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
