#!/usr/bin/env python3
"""Zyfen şerit aracı (v2.0.2 S2): kolsuz, tek parça gövde kareleri -> tek yatay şerit + gövde görseli + manifest + kalite kapısı.

Kullanım (kareler RGBA PNG; yeşil zeminliyse --chroma):
  python tools/art/make_zyfen_strip.py --stand <png> --walk '<glob>' --cast '<glob>' --gather '<glob>' [--walk-cast '<glob>']
         --strip <şerit.png> --body <gövde.png> --manifest <json> [--quality <quality.json>] [--preview [--preview-dir D]]
         [--cell-height 320] [--stride 150] [--display-height 200] [--fire-frame 3] [--palm-px X,Y] [--native-facing right|left]
         [--chroma] [--no-gate]
  `--walk` verilmezse ya da boşsa yürüme 0 kare (prosedürel yürüme; cast/gather yine geçerli).

Hücre sırası (RigFrames ile aynı): yürüme 0..W-1, duruş W, cast, gather, walk_cast (isteğe bağlı). Toplam W+1+C+G+WC.

Hat: her kare alfa sınırına kırpılır (komşu karelerden taşan küçük parçalar atılır) -> **klip başına ölçek**: klibin karelerinin
ortanca alfa boyu `body_h` (= cell_height / 1,065, ≈ 300 px) olacak şekilde; duruş görseli aynı boya (`body_scale`; `--body`
çıktısı aynı piksel ölçeğinde, alfa sınırına kırpılmış) -> yatay hiza: gövdenin üst yarısının alfa ağırlık merkezi hücre
ortasında; ayak çizgisi hücrenin alt kenarında. **Hücre genişliği girdiden hesaplanır**: tüm karelerin hizalı alfa kutularının
gerektirdiği en geniş yarı genişlik, çift sayıya yuvarlanıp 2·PAD eklenir (sabit değil; cast ≈ 240 px beklenir).

Kalite kapısı (`quality.pass`; yalnız hepsi sağlanırsa true; yürüme kareleri için):
  - foot_slide: yürüme `N` çift (döngü kapanışı dahil) için basan ayak hatası <= 3 px olanlar >= N-2
  - klip yükseklik sapması: her karenin alfa boyu klip ortancasından <= %6 (tüm klipler)
  - toplam hücre x hücre genişliği <= 8192 (doku sınırı; Redmi Note 13 Pro varsayımı cihazda doğrulanır)
  - walk_cast varsa foot_slide ölçülür (N-1 ardışık çift, <= 1 hata; yürüme saati donmuş sayılır, adım stride/W)
Çıkış: 0 kapı geçti, 1 kapı kaldı (çıktılar yine yazılır; --no-gate ile 0), 2 kullanım/girdi hatası.

Manifest `palm` (--palm-px verilirse): cast karesinde (fire_frame) avuç noktası, `cast_point` ile AYNI uzayda: gövde (duruş) alfa kutusu
merkezine göre, `display_height` kesri, +x = native_facing, +y aşağı. K fazı bunu zyfen.json `cast_point` ile karşılaştırır.
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chroma_key as ck  # noqa: E402
import make_strip as ms  # noqa: E402
import process_art as pa  # noqa: E402

PREVIEW_DIR = Path(__file__).resolve().parent / "_preview"
PAD = 4  # hücre yan boşluğu (px)
HEIGHT_SLACK = 1.065  # klip boyu +%6 sapma hücreye sığar
MAX_HEIGHT_DEV_PCT = 6.0
MAX_STRIP_W = 8192
FOOT_TOL = 3.0
CLIPS = ("walk", "cast", "gather", "walk_cast")


def natural_key(s: str):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", s)]


def expand(pattern: str | None) -> list[str]:
    if not pattern:
        return []
    return sorted(glob.glob(pattern), key=natural_key)


def load_frame(path: str, chroma: bool = False):
    """(rgb float32, alpha float32 0..1, kaynak kutusu (x0,y0,x1,y1)) -- alfa sınırına kırpılmış, taşan küçük parçalar atılmış."""
    arr = np.asarray(Image.open(path).convert("RGBA"))
    if chroma:
        rgb, alpha = ck.key_image(arr[..., :3])
    else:
        rgb, alpha = arr[..., :3].astype(np.float32), arr[..., 3].astype(np.float32) / 255.0
    alpha = ms.keep_main_parts(alpha)
    if not (alpha > 0.5).any():
        raise ValueError(f"{path}: boş kare (opak piksel yok)")
    box = pa.alpha_bbox(alpha, 0.5)
    c_rgb, c_a = pa.crop(rgb.astype(np.float32), alpha, box)
    return c_rgb, c_a, box


def scale_frame(rgb, alpha, scale: float):
    h, w = alpha.shape
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    if (nw, nh) != (w, h):
        rgb, alpha = pa.resize_premultiplied(rgb, alpha, (nw, nh))
    return rgb, alpha


def foot_slide_cells(strip, cw: int, base: int, n: int, step_world: float, world_per_px: float, loop: bool,
                     tol: float = FOOT_TOL) -> dict:
    """Hücre `base..base+n-1` kümesinde basan ayak ölçümü (make_strip.foot_slide ile aynı mantık, kümeye genel)."""
    cont = [[c * world_per_px for c in ms.foot_contacts(strip[:, (base + f) * cw:(base + f + 1) * cw, 3] / 255.0)]
            for f in range(n)]
    errs = []
    for f in range(n if loop else n - 1):
        g = (f + 1) % n
        best = min((abs((b - a) + step_world) for a in cont[f] for b in cont[g]), default=float("inf"))
        errs.append(float(best))
    ok = sum(1 for e in errs if e <= tol)
    return {
        "step_px": round(step_world, 2),
        "contacts_world_px": [[round(c, 1) for c in row] for row in cont],
        "pair_err_px": [round(e, 1) if np.isfinite(e) else None for e in errs],
        "ok_pairs": ok,
        "total_pairs": len(errs),
        "allowed_failures": 2 if loop else 1,
    }


def build(stand_path: str, clips: dict[str, list[str]], cell_height: int = 320, stride: float = 150.0,
          display_height: float = 200.0, fire_frame: int = 3, palm_px: tuple[float, float] | None = None,
          native_facing: str = "right", chroma: bool = False) -> dict:
    """Şeridi kurar. Dönüş: {"strip", "body", "manifest"} (strip/body uint8 RGBA)."""
    warnings: list[str] = []
    body_h = int(cell_height / HEIGHT_SLACK)
    stand = load_frame(stand_path, chroma)
    body_scale = body_h / stand[1].shape[0]
    frames: dict[str, list] = {}
    clip_scale: dict[str, float] = {}
    height_dev: dict[str, list[float]] = {}
    for name in CLIPS:
        paths = clips.get(name) or []
        if not paths:
            continue
        loaded = [load_frame(p, chroma) for p in paths]
        heights = np.array([f[1].shape[0] for f in loaded], dtype=np.float64)
        med = float(np.median(heights))
        s = body_h / med
        clip_scale[name] = round(s, 5)
        height_dev[name] = [round(float((h - med) / med * 100.0), 2) for h in heights]
        frames[name] = [(*scale_frame(f[0], f[1], s), f[2]) for f in loaded]
    s_rgb, s_alpha = scale_frame(stand[0], stand[1], body_scale)
    order: list[tuple[str, int, object]] = []  # (klip, kare, (rgb, alpha, kutu))
    for i, f in enumerate(frames.get("walk", [])):
        order.append(("walk", i, f))
    order.append(("stand", 0, (s_rgb, s_alpha, stand[2])))
    for name in ("cast", "gather", "walk_cast"):
        for i, f in enumerate(frames.get(name, [])):
            order.append((name, i, f))
    anchors = []
    half = 0.0
    for _, _, (rgb, alpha, _box) in order:
        ax = ms._centroid_x(alpha, 0, max(1, alpha.shape[0] // 2))
        anchors.append(ax)
        half = max(half, ax, alpha.shape[1] - ax)
    cw = 2 * int(math.ceil(half)) + 2 * PAD
    ch = cell_height
    n_cells = len(order)
    strip = np.zeros((ch, cw * n_cells, 4), np.uint8)
    place = []  # (x, y) hücre içi sol-üst
    overflow: list[int] = []
    for i, ((_, _, (rgb, alpha, _box)), ax) in enumerate(zip(order, anchors)):
        nh, nw = alpha.shape
        if nh > ch:  # ortancadan >%6,5 uzun kare: üstü kırpılır, kapı kalır (yükseklik sapması da bunu yakalar)
            rgb, alpha = rgb[nh - ch:], alpha[nh - ch:]
            nh = ch
            overflow.append(i)
        x = min(max(int(round(cw / 2.0 - ax)), 0), cw - nw)
        y = ch - nh
        strip[y:y + nh, i * cw + x:i * cw + x + nw] = pa.to_rgba_u8(rgb, alpha)
        place.append((x, y))
    # gövde görseli: duruş, aynı ölçekte, alfa sınırına kırpılmış
    body_rgba = pa.to_rgba_u8(s_rgb, s_alpha)
    w_n = len(frames.get("walk", []))
    c_n, g_n, wc_n = (len(frames.get(k, [])) for k in ("cast", "gather", "walk_cast"))
    idle = w_n
    bases = {"cast": idle + 1 if c_n else -1, "gather": idle + 1 + c_n if g_n else -1,
             "walk_cast": idle + 1 + c_n + g_n if wc_n else -1}
    world_per_px = display_height / float(s_alpha.shape[0])
    failures: list[str] = []
    q: dict = {"height_dev_pct": height_dev}
    max_dev = max((abs(v) for d in height_dev.values() for v in d), default=0.0)
    q["max_height_dev_pct"] = round(max_dev, 2)
    if max_dev > MAX_HEIGHT_DEV_PCT:
        failures.append("klip yükseklik sapması %.1f%% > %.0f%%" % (max_dev, MAX_HEIGHT_DEV_PCT))
    if w_n >= 3:
        fs = foot_slide_cells(strip, cw, 0, w_n, stride / w_n, world_per_px, loop=True)
        fs["pass"] = fs["ok_pairs"] >= fs["total_pairs"] - fs["allowed_failures"]
        q["foot_slide"] = fs
        if not fs["pass"]:
            failures.append("foot_slide: %d/%d çift <= %g px (>= %d gerekli)" % (
                fs["ok_pairs"], fs["total_pairs"], FOOT_TOL, fs["total_pairs"] - fs["allowed_failures"]))
    elif w_n:
        warnings.append("yürüme %d kare: foot_slide ölçülmedi (>= 3 kare gerekir)" % w_n)
    if wc_n >= 2:
        step = stride / w_n if w_n else stride / 8.0
        fs = foot_slide_cells(strip, cw, bases["walk_cast"], wc_n, step, world_per_px, loop=False)
        fs["pass"] = fs["ok_pairs"] >= fs["total_pairs"] - fs["allowed_failures"]
        q["walk_cast_foot_slide"] = fs
        if not fs["pass"]:
            failures.append("walk_cast foot_slide: %d/%d çift <= %g px" % (fs["ok_pairs"], fs["total_pairs"], FOOT_TOL))
    q["strip_width"] = cw * n_cells
    q["strip_width_ok"] = cw * n_cells <= MAX_STRIP_W
    if not q["strip_width_ok"]:
        failures.append("şerit genişliği %d > %d" % (cw * n_cells, MAX_STRIP_W))
    if overflow:
        failures.append("%d kare hücre yüksekliğini aşıyor (üstü kırpıldı): hücre %s" % (len(overflow), overflow))
    q["failures"] = failures
    q["pass"] = not failures
    manifest = {
        "kind": "zyfen",
        "cell": [cw, ch],
        "cells": n_cells,
        "frames": {"walk": w_n, "cast": c_n, "gather": g_n, "walk_cast": wc_n},
        "idle_index": idle,
        "cast_base": bases["cast"],
        "gather_base": bases["gather"],
        "walk_cast_base": bases["walk_cast"],
        "body_scale": round(body_scale, 5),
        "clip_scale": clip_scale,
        "body_px": [int(s_alpha.shape[1]), int(s_alpha.shape[0])],
        "display_scale_hint": round(ch / float(s_alpha.shape[0]), 5),
        "stride": stride,
        "display_height": display_height,
        "palm": None,
        "quality": q,
        "warnings": warnings,
    }
    if palm_px is not None:
        if not c_n:
            warnings.append("--palm-px verildi ama cast klibi yok: palm hesaplanmadı")
        elif not 0 <= fire_frame < c_n:
            raise ValueError("fire_frame %d cast kare sayısı %d dışında" % (fire_frame, c_n))
        else:
            idx = bases["cast"] + fire_frame
            _, _, (_rgb, a_f, box) = order[idx]
            s = clip_scale["cast"]
            px = place[idx][0] + (palm_px[0] - box[0]) * s
            py = place[idx][1] + (palm_px[1] - box[1]) * s
            sx, sy = place[idle]
            scx, scy = sx + s_alpha.shape[1] / 2.0, sy + s_alpha.shape[0] / 2.0
            fx = (px - scx) / float(s_alpha.shape[0])
            fy = (py - scy) / float(s_alpha.shape[0])
            if native_facing == "left":
                fx = -fx
            manifest["palm"] = {"fire_frame": fire_frame, "point": [round(float(fx), 4), round(float(fy), 4)]}
            if abs(fx) > 0.5 or abs(fy) > 0.5:
                warnings.append("palm ±0,5 dışında: %s (cast_point sınırı)" % manifest["palm"]["point"])
    return {"strip": strip, "body": body_rgba, "manifest": manifest, "order": [(n, i) for n, i, _ in order]}


def write_preview(res: dict, out_path: Path) -> Path:
    strip, m = res["strip"], res["manifest"]
    cw, ch = m["cell"]
    n = m["cells"]
    rows = []
    for bg in ((3, 157, 8), (0x17, 0x10, 0x19)):
        canvas = Image.new("RGBA", (cw * n, ch + 18), bg + (255,))
        canvas.alpha_composite(Image.fromarray(strip, "RGBA"), (0, 18))
        d = ImageDraw.Draw(canvas)
        for i, (name, k) in enumerate(res["order"]):
            x = i * cw
            d.line([(x, 18 + ch - 1), (x + cw, 18 + ch - 1)], fill=(255, 40, 40, 255))
            d.line([(x + cw // 2, 18), (x + cw // 2, 18 + ch)], fill=(40, 220, 220, 255))
            d.line([(x, 18), (x, 18 + ch)], fill=(255, 255, 255, 90))
            d.text((x + 4, 3), "%s %d" % (name, k), fill=(255, 255, 255, 255))
        rows.append(canvas)
    sheet = Image.new("RGBA", (rows[0].width, sum(r.height for r in rows)))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out_path)
    return out_path


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--stand", required=True, help="duruş görseli (RGBA PNG)")
    ap.add_argument("--walk", help="yürüme kareleri glob (doğal sıra; boş = 0 kare)")
    ap.add_argument("--cast", help="cast kareleri glob")
    ap.add_argument("--gather", help="rüzgar toplama kareleri glob")
    ap.add_argument("--walk-cast", dest="walk_cast", help="yürürken savuruş kareleri glob (isteğe bağlı)")
    ap.add_argument("--strip", required=True)
    ap.add_argument("--body", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--quality", help="kalite raporu (art/source/zyfen/quality.json)")
    ap.add_argument("--cell-height", type=int, default=320)
    ap.add_argument("--stride", type=float, default=150.0, help="yürüme çevrim uzunluğu (dünya px)")
    ap.add_argument("--display-height", type=float, default=200.0)
    ap.add_argument("--fire-frame", type=int, default=3)
    ap.add_argument("--palm-px", help="X,Y: cast karesinin (fire_frame) KAYNAK görselindeki avuç pikseli")
    ap.add_argument("--native-facing", choices=["right", "left"], default="right")
    ap.add_argument("--chroma", action="store_true", help="kareler düz yeşil zeminli (anahtarla)")
    ap.add_argument("--no-gate", action="store_true", help="kalite kapısı kalsa da çıkış 0")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--preview-dir", default=str(PREVIEW_DIR))
    a = ap.parse_args(argv)
    clips = {"walk": expand(a.walk), "cast": expand(a.cast), "gather": expand(a.gather), "walk_cast": expand(a.walk_cast)}
    for name, pat in (("walk", a.walk), ("cast", a.cast), ("gather", a.gather), ("walk_cast", a.walk_cast)):
        if pat and not clips[name]:
            print(f"girdi hatası: --{name.replace('_', '-')} deseni dosya bulamadı: {pat}", file=sys.stderr)
            return 2
    if not Path(a.stand).is_file():
        print(f"girdi hatası: duruş görseli yok: {a.stand}", file=sys.stderr)
        return 2
    palm = tuple(float(v) for v in a.palm_px.split(",")) if a.palm_px else None
    try:
        res = build(a.stand, clips, a.cell_height, a.stride, a.display_height, a.fire_frame, palm, a.native_facing, a.chroma)
    except ValueError as e:
        print(f"girdi hatası: {e}", file=sys.stderr)
        return 2
    for path in (a.strip, a.body, a.manifest):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(res["strip"], "RGBA").save(a.strip)
    Image.fromarray(res["body"], "RGBA").save(a.body)
    Path(a.manifest).write_text(json.dumps(res["manifest"], indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    q = res["manifest"]["quality"]
    if a.quality:
        Path(a.quality).parent.mkdir(parents=True, exist_ok=True)
        Path(a.quality).write_text(json.dumps(q, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for w in res["manifest"]["warnings"]:
        print("UYARI:", w, file=sys.stderr)
    if a.preview:
        print("önizleme:", write_preview(res, Path(a.preview_dir) / (Path(a.strip).stem + "_preview.png")))
    m = res["manifest"]
    print("hücre=%s x %d = %d px (sınır %d) gövde_ölçek=%.4f maks_boy_sapma=%.1f%%" % (
        m["cell"], m["cells"], q["strip_width"], MAX_STRIP_W, m["body_scale"], q["max_height_dev_pct"]))
    if "foot_slide" in q:
        fs = q["foot_slide"]
        print("ayak kayması: %d/%d çift <= %g px (adım %.1f px)" % (fs["ok_pairs"], fs["total_pairs"], FOOT_TOL, fs["step_px"]))
    print("KAPI:", "GEÇTİ" if q["pass"] else "KALDI: " + "; ".join(q["failures"]))
    return 0 if (q["pass"] or a.no_gate) else 1


if __name__ == "__main__":
    sys.exit(main())
