#!/usr/bin/env python3
"""Kolsuz (tek parça gövde, `rig.armless`) rig şeridi: ayrı şeffaf kareler -> tek yatay şerit + manifest + kalite kapısı.

İlk karakter Zyfen'dir (v2.0.2 U2; dosya adı o dönemden kalmadır); araç karakterden bağımsızdır: karakter kimliği `--src` dizin adından,
çizim boyu `--display-height` ile gelir.

Kullanım:
  python tools/art/make_zyfen_strip.py --src art/source/zyfen --out assets/gfx/char/zyfen_strip.png \
         --body-out assets/gfx/char/zyfen_body.png --manifest art/source/zyfen/strip_manifest.json \
         --quality art/source/zyfen/quality.json [--display-height 200] [--idle <png>] [--walk-cast 'glob'] [--stride 150] [--palm-px 444,132] [--preview]

Girdi: `<src>/frames/{walk,cast,gather}/*.png` (RGBA, alfa zaten silinmiş), `<src>/<src dizin adı>_idle.png` (duruş; `--idle` ile değişir), isteğe bağlı
`--walk-cast <glob>` (yürürken savuruş seti). Hücre sırası (RigFrames ile aynı): yürüme 0..W-1, duruş W, cast, gather,
walk_cast. Her klip kendi ortanca alfa boyuna göre 320 px yüksekliğe normalize edilir (ayak = hücre alt kenarı); hücre
genişliği HESAPLANIR: tüm klip alfa kutularının en genişi + 2·PAD. Yatay hiza: yürüme/duruş gövde üst yarısının, cast/gather
ayakların (planlı) ağırlık merkezi. `--body-out` (duruş gövdesi) aynı piksel ölçeğinde (320 px boy) ayrıca yazılır.
Kalite kapısı (plan U2/2): foot_slide (yürüme, çift başına ≤3 px, ≥ N-2 çift), klip yükseklik sapması ≤ %6,
toplam hücre × genişlik ≤ 8192.
Manifest `palm` (--palm-px verilirse): atış karesindeki avuç, `cast_point` ile AYNI uzayda (dönüşüm: palm_to_cast_point). Kapı kırmızıysa çıkış kodu 1 ve `quality.json` `pass: false`; sessiz yedek yoktur.
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
DISPLAY_HEIGHT = 200.0  # varsayılan; karakter verisindeki rig.display_height (--display-height)


def _load_rgba(p: str | Path) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGBA"))


def _box(img: np.ndarray) -> tuple[int, int, int, int]:
    """Opak (alfa > 127) piksellerin kutusu: x0, y0, x1, y1 (son dahil)."""
    ys, xs = np.nonzero(img[..., 3] > 127)
    if len(ys) == 0:
        raise ValueError("kare boş: opak piksel yok")
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def _trim(img: np.ndarray) -> np.ndarray:
    x0, y0, x1, y1 = _box(img)
    return img[y0:y1 + 1, x0:x1 + 1]


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
        full = [_load_rgba(f) for f in files]
        self.boxes = [_box(f) for f in full]  # kaynak görseldeki alfa kutusu (palm dönüşümü için)
        self.raw = [_trim(f) for f in full]
        heights = np.array([r.shape[0] for r in self.raw], dtype=np.float64)
        self.scale = CELL_H / float(heights.max())  # en uzun kare 320 px; ortancadan sapma height_dev_pct
        self.imgs = [_scaled(r, self.scale) for r in self.raw]
        self.height_dev_pct = [round(float((r.shape[0] - np.median(heights)) / np.median(heights) * 100.0), 2) for r in self.raw]
        # ölçekleme sonrası boy hedefi: kare, 320 px'i aşmasın (şapka/el kalkışı varsa kırp yerine uyar)
        self.over = [i.shape[0] for i in self.imgs if i.shape[0] > CELL_H]


def _contacts(im: np.ndarray, band: int = 8) -> list[float]:
    """Karenin alt `band` pikselinde yere değen ayak parçalarının merkez x'leri (görüntü yerel, px)."""
    cols = (im[-band:, :, 3] > 127).any(axis=0)
    return [(a + b - 1) / 2.0 for a, b in ms._runs(np.nonzero(cols)[0])]


def align_feet(imgs: list[np.ndarray], base_x: list[int], step_px: float, reach: int = 24, rounds: int = 6) -> list[int]:
    """Yürüme karelerini basan ayağa göre kaydırır: gövde sabit hücrede, dünya zeminde ayak sabit => basan ayak her karede
    `step_px` (strip px) geriye gider. Her kareye ±`reach` px kaydırma; hedef: ardışık çiftlerin (döngü dahil) en iyi ayak
    eşleşmesi hatası toplamı + küçük gövde-kayma cezası. Eş. koordinat inişi, deterministik."""
    n = len(imgs)
    cont = [_contacts(im) for im in imgs]
    shift = [0] * n

    def pair_err(f: int, sf: int, sg: int) -> float:
        g = (f + 1) % n
        return min(
            (abs((base_x[g] + sg + b) - (base_x[f] + sf + a) + step_px) for a in cont[f] for b in cont[g]),
            default=1e6,
        )

    for _ in range(rounds):
        changed = False
        for f in range(n):
            best, best_s = None, shift[f]
            for s in range(-reach, reach + 1):
                cost = min(pair_err(f, s, shift[(f + 1) % n]), 12.0) + min(pair_err((f - 1) % n, shift[(f - 1) % n], s), 12.0)
                cost += 0.02 * abs(s)
                if best is None or cost < best - 1e-9:
                    best, best_s = cost, s
            if best_s != shift[f]:
                shift[f], changed = best_s, True
        if not changed:
            break
    return shift


def palm_to_cast_point(palm_px: tuple[float, float], box: tuple[int, int, int, int], scale: float, cell_x: float,
                       img_h: int, cell_w: int, native_facing: str = "right") -> list[float]:
    """Kaynak görseldeki avuç pikselini `cast_point` uzayına çevirir (docs/data-schema.md `cast_point`).

    Hücre pikseli = (palm - alfa kutusu başı) x klip ölçeği + karenin hücredeki konumu (x = cell_x, kare alt kenara oturur:
    üst = CELL_H - img_h). Oyun hücreyi duruş gövdesiyle AYNI dünya ölçeğiyle (320 hücre px = display_height) ve hücre
    merkezi = oyuncu gövde merkezi olacak biçimde çizer; bu yüzden kesir = (hücre px - hücre merkezi) / CELL_H.
    +x = native_facing yönü (sola bakan kaynakta x işareti çevrilir), +y aşağı."""
    px = cell_x + (palm_px[0] - box[0]) * scale
    py = (CELL_H - img_h) + (palm_px[1] - box[1]) * scale
    fx = (px - cell_w / 2.0) / CELL_H
    fy = (py - CELL_H / 2.0) / CELL_H
    return [round(fx * (-1.0 if native_facing == "left" else 1.0), 4), round(fy, 4)]


def build(src: Path, walk_cast: list[str] | None, stride: float, align: str = "feet", palm_px: tuple[float, float] | None = None,
          fire_frame: int = 3, native_facing: str = "right", display_height: float = DISPLAY_HEIGHT,
          idle_path: Path | None = None) -> tuple[np.ndarray, np.ndarray, dict]:
    walk_files = sorted(glob.glob(str(src / "frames/walk/*.png")))
    cast_files = sorted(glob.glob(str(src / "frames/cast/*.png")))
    gather_files = sorted(glob.glob(str(src / "frames/gather/*.png")))
    if not walk_files:
        raise SystemExit("kare dosyaları eksik: %s/frames/walk" % src)
    if bool(cast_files) != bool(gather_files):
        raise SystemExit("cast ve gather birlikte olmalı (ya da ikisi de yok: yalnız yürüme şeridi): %s/frames" % src)
    clips = {"walk": Clip("walk", walk_files, "upper")}
    if cast_files:  # cast/gather yoksa (bölünmüş rig: Gunslinger) şerit = N yürüme + 1 duruş
        clips["cast"] = Clip("cast", cast_files, "feet")
        clips["gather"] = Clip("gather", gather_files, "feet")
    if walk_cast:
        clips["walk_cast"] = Clip("walk_cast", sorted(walk_cast), "upper")
    idle_raw = _trim(_load_rgba(idle_path or src / f"{src.name}_idle.png"))
    idle_scale = CELL_H / idle_raw.shape[0]
    idle = _scaled(idle_raw, idle_scale)
    order = ["walk", "idle"] + [k for k in ("cast", "gather", "walk_cast") if k in clips]
    seq: list[tuple[str, np.ndarray, str]] = []
    for k in order:
        if k == "idle":
            seq.append(("idle", idle, "upper"))
        else:
            seq += [(k, im, clips[k].anchor) for im in clips[k].imgs]
    ax = [_anchor_x(im, mode) for _, im, mode in seq]
    n_w = len(clips["walk"].imgs)
    shift = [0] * len(seq)
    manifest_pre = None
    if align == "feet":
        ims_w = [seq[i][1] for i in range(n_w)]
        cw0 = int(math.ceil(max(im.shape[1] for _, im, _ in seq) * 1.3))  # yalnız taban x hesabı için geçici genişlik
        base_x = [int(round(cw0 / 2.0 - ax[i])) for i in range(n_w)]
        step_px = stride / n_w / (display_height / CELL_H)
        # önce/sonra tablosu için torso hizalı ölçüm
        manifest_pre = _slide(ims_w, base_x, [0] * n_w, cw0, stride, display_height)
        sh = align_feet(ims_w, base_x, step_px)
        shift[:n_w] = sh
        ax = [a - s for a, s in zip(ax, shift)]
    left = max(a for a in ax)
    right = max(im.shape[1] - a for (_, im, _), a in zip(seq, ax))
    # hücre genişliği: en geniş alfa kutusu + 2·PAD (merkezde ortalı), tek sayı yuvarlanır
    widest = max(im.shape[1] for _, im, _ in seq)
    cw = int(math.ceil(max(widest, 2 * max(left, right)))) + 2 * PAD
    cw += cw % 2
    strip = np.zeros((CELL_H, cw * len(seq), 4), np.uint8)
    xs_place: list[int] = []
    for i, ((name, im, _), a) in enumerate(zip(seq, ax)):
        x = int(round(cw / 2.0 - a))
        x = min(max(x, 0), cw - im.shape[1])
        xs_place.append(x)
        h = min(im.shape[0], CELL_H)
        strip[CELL_H - h:, i * cw + x:i * cw + x + im.shape[1]] = im[-h:]
    # duruş gövdesi: tek hücre genişliği değil, kendi alfa kutusu (PlayerView stand_px/k dünya ölçeği)
    body = idle
    n_walk = len(clips["walk"].imgs)
    res = ms.StripResult(
        strip[:, : n_walk * cw], {"cell": [cw, CELL_H], "frames": n_walk}, clips["walk"].scale, []
    )
    wpp = display_height / CELL_H
    fs = ms.foot_slide(res, stride, wpp, SLIDE_TOL_PX)
    manifest = {
        "align": align,
        "foot_shift_px": shift[:n_w],
        "foot_slide_torso": manifest_pre,
        "cells": len(seq),
        "cell": [cw, CELL_H],
        "strip_width": int(strip.shape[1]),
        "walk": {"frames": n_walk, "scale": round(clips["walk"].scale, 5)},
        "idle": {"index": n_walk, "scale": round(idle_scale, 5)},
        "body_scale": round(idle_scale, 5),
        "stride": stride,
        "foot_slide": fs,
        "height_dev_pct": {k: c.height_dev_pct for k, c in clips.items()},
    }
    for k in ("cast", "gather"):
        if k in clips:
            manifest[k] = {"frames": len(clips[k].imgs), "scale": round(clips[k].scale, 5)}
    if "walk_cast" in clips:
        manifest["walk_cast"] = {"frames": len(clips["walk_cast"].imgs), "scale": round(clips["walk_cast"].scale, 5)}
    if palm_px is not None:
        if "cast" not in clips:
            raise SystemExit("--palm-px için cast kareleri gerekir")
        c = clips["cast"]
        if not 0 <= fire_frame < len(c.imgs):
            raise SystemExit("fire_frame %d cast kare sayısı %d dışında" % (fire_frame, len(c.imgs)))
        idx = n_walk + 1 + fire_frame  # yürüme, duruş, cast...
        point = palm_to_cast_point(palm_px, c.boxes[fire_frame], c.scale, xs_place[idx], c.imgs[fire_frame].shape[0], cw, native_facing)
        manifest["palm"] = {"fire_frame": fire_frame, "point": point}
    return strip, body, manifest


def _slide(imgs: list[np.ndarray], base_x: list[int], shift: list[int], cw: int, stride: float,
           display_height: float = DISPLAY_HEIGHT) -> dict:
    w = max(base_x[i] + shift[i] + imgs[i].shape[1] for i in range(len(imgs))) + 40
    cw = max(cw, w + 40)
    st = np.zeros((CELL_H, cw * len(imgs), 4), np.uint8)
    for i, im in enumerate(imgs):
        x = max(base_x[i] + shift[i], 0)
        st[CELL_H - im.shape[0]:, i * cw + x:i * cw + x + im.shape[1]] = im
    r = ms.StripResult(st, {"cell": [cw, CELL_H], "frames": len(imgs)}, 1.0, [])
    f = ms.foot_slide(r, stride, display_height / CELL_H, SLIDE_TOL_PX)
    return {"ok_pairs": f["ok_pairs"], "total_pairs": f["total_pairs"], "pair_err_px": f["pair_err_px"]}


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
    ap.add_argument("--src", required=True, help="kaynak dizin art/source/<id> (kimlik = dizin adı)")
    ap.add_argument("--out", required=True, help="şerit PNG")
    ap.add_argument("--body-out", required=True, help="duruş gövdesi PNG (aynı piksel ölçeği)")
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--quality", required=True, help="kalite kapısı sonucu (quality.json)")
    ap.add_argument("--walk-cast", help="isteğe bağlı walk_cast kareleri (glob)")
    ap.add_argument("--stride", type=float, default=130.0, help="yürüme çevrimi uzunluğu (dünya px; <id>.json walk.stride). 150 ile ayak çapası 5/8, 130 ile 8/8 (videonun gerçek adım uzunluğu)")
    ap.add_argument("--align", choices=["feet", "torso"], default="feet", help="yürüme hizası: basan ayak çapası (varsayılan) ya da üst gövde ağırlık merkezi")
    ap.add_argument("--palm-px", help="X,Y: cast karesinin (fire_frame) KAYNAK görselindeki avuç pikseli; manifest `palm` (cast_point uzayı) yazılır")
    ap.add_argument("--fire-frame", type=int, default=3, help="atış karesi indeksi (<id>.json cast.fire_frame)")
    ap.add_argument("--display-height", type=float, default=DISPLAY_HEIGHT, help="çizim boyu, dünya px (<id>.json rig.display_height)")
    ap.add_argument("--idle", help="duruş PNG (varsayılan <src>/<kimlik>_idle.png)")
    ap.add_argument("--native-facing", choices=["right", "left"], default="right")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--preview-dir", default=str(Path(__file__).resolve().parent / "_preview"))
    args = ap.parse_args(argv)
    wc = sorted(glob.glob(args.walk_cast)) if args.walk_cast else None
    palm = tuple(float(v) for v in args.palm_px.split(",")) if args.palm_px else None
    strip, body, manifest = build(Path(args.src), wc, args.stride, args.align, palm, args.fire_frame, args.native_facing,
                                  args.display_height, Path(args.idle) if args.idle else None)
    q = gate(manifest)
    for p, data in ((args.manifest, manifest), (args.quality, q)):
        Path(p).parent.mkdir(parents=True, exist_ok=True)
        Path(p).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(strip, "RGBA").save(args.out, optimize=True)
    Image.fromarray(body, "RGBA").save(args.body_out, optimize=True)
    if args.preview:
        labels = [f"w{i}" for i in range(manifest["walk"]["frames"])] + ["idle"]
        labels += [f"c{i}" for i in range(manifest.get("cast", {}).get("frames", 0))] + [f"g{i}" for i in range(manifest.get("gather", {}).get("frames", 0))]
        labels += [f"wc{i}" for i in range(manifest.get("walk_cast", {}).get("frames", 0))]
        pv = Path(args.preview_dir) / f"{Path(args.src).name}_strip_preview.png"
        write_preview(strip, manifest["cell"][0], labels, pv)
        print("önizleme:", pv)
    fs = manifest["foot_slide"]
    pre = manifest.get("foot_slide_torso")
    if pre:
        print("foot_slide önce (torso): %d/%d %s | sonra (ayak çapası, kaydırma %s): %d/%d %s" % (
            pre["ok_pairs"], pre["total_pairs"], pre["pair_err_px"], manifest["foot_shift_px"], fs["ok_pairs"], fs["total_pairs"], fs["pair_err_px"]))
    print("hücre=%s toplam=%d genişlik=%d  ayak kayması %d/%d çift ≤%.0f px  boy sapması ≤%.2f%%  → %s" % (
        manifest["cell"], manifest["cells"], manifest["strip_width"], fs["ok_pairs"], fs["total_pairs"],
        SLIDE_TOL_PX, q["worst_height_dev_pct"], "GEÇTİ" if q["pass"] else "KALDI"))
    if not q["pass"]:
        print("KALITE KAPISI KIRMIZI:", {k: v for k, v in q["checks"].items() if not v}, "pair_err_px=", fs["pair_err_px"], file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
