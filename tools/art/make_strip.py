#!/usr/bin/env python3
"""Yürüme şeridi aracı (v1.1 D4-1): temas sayfası / kare dosyaları -> tek yatay şerit + manifest.

Kullanım:
  python tools/art/make_strip.py --sheet <png> --rows <satır no | y0:y1> --cells N [--drop-dup-last]
         --kind player|enemy --stand <png> --out <şerit.png> --manifest <json> [--preview [--preview-dir D]]
  python tools/art/make_strip.py --grid 3x2 --sheet <img> ...       # ham kareler tek görselde (sütun x satır)
  python tools/art/make_strip.py --frames a.png b.png ... ...       # ayrı kare dosyaları (yeşil zeminli)

Hat: yeşil zemin (`chroma_key.py`) -> başlık şeridi / ayırıcı çizgi atılır, hücreler bölünür -> her kare alfa
sınırına kırpılır -> **ortak ölçek** (duruş görselinin alfa boyu / karelerin ortanca boyu) -> ayak çizgisi hücrenin alt
kenarına, yatay hiza gövde üst yarısının alfa ağırlık merkezine göre. Oyuncu şeridi: N yürüme hücresi + 1 duruş hücresi
(indeks N; ortalı, alt hizalı, ölçeksiz). Düşman şeridi: yalnız N hücre.
Manifest: frames, cell [w,h], display_scale_hint, scale, quality{...}, (oyuncu) shoulder_dev (N+1 adet [dx,dy],
display_height kesri; duruş = [0,0]; omuz dikişi güvenilir ölçülemezse boş + uyarı).
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chroma_key as ck  # noqa: E402
import process_art as pa  # noqa: E402

PREVIEW_DIR = Path(__file__).resolve().parent / "_preview"
GREEN_D = 60  # başlık/ayırıcı tespitinde "yeşil" eşiği (G - max(R,B))
DARK_LUMA = 70
MIN_CELL_W = 40
DUP_IOU = 0.97
SHOULDER_BAND = (0.10, 0.30)  # kare boyunun üstünden: yaka/göğüs/atkı bandı
SHOULDER_MAX = 0.2
CANVAS_1536 = 1536.0  # prompts.md C1: 1024x1536 tuval; hizalama toleransı bu tuvalde px


@dataclass
class StripResult:
    strip: np.ndarray  # (H, W, 4) uint8
    manifest: dict
    scale: float
    frames_rgba: list  # yerleştirilmiş kareler (önizleme için): (x_anchor, h) bilgisiyle birlikte


# ---------------------------------------------------------------- sayfa bölme
def _runs(idx) -> list[tuple[int, int]]:
    out, start, prev = [], None, None
    for i in idx:
        i = int(i)
        if start is None:
            start = i
        elif i != prev + 1:
            out.append((start, prev + 1))
            start = i
        prev = i
    if start is not None:
        out.append((start, prev + 1))
    return out


def _masks(rgb: np.ndarray):
    c = rgb.astype(np.int32)
    green = (c[..., 1] - np.maximum(c[..., 0], c[..., 2])) > GREEN_D
    luma = c @ np.array([0.299, 0.587, 0.114])
    return green, luma


def row_bands(rgb: np.ndarray) -> list[tuple[int, int]]:
    """Başlık şeritleri (satırların >%90'ı yeşil değil) arasındaki hücre satırı aralıkları [y0, y1)."""
    green, _ = _masks(rgb)
    header = (~green).mean(axis=1) > 0.9
    body = np.nonzero(~header)[0]
    return [(a, b) for a, b in _runs(body) if b - a >= MIN_CELL_W]


def split_sheet(rgb: np.ndarray, row=0, cells: int | None = None) -> list[np.ndarray]:
    """Temas sayfasından bir satırın hücreleri (RGB uint8 kırpımları, soldan sağa).

    Hücre ayırıcıları ince koyu dikey çizgilerdir; bazıları eksik olabilir: iki ayırıcı arası genişlik, en dar
    aralığın katıysa eşit parçalara bölünür. Ayırıcı hiç yoksa (ya da `cells` karşılanmazsa) satır eşit bölünür."""
    if isinstance(row, tuple):
        y0, y1 = row
    else:
        bands = row_bands(rgb)
        if not bands or row >= len(bands):
            raise ValueError("satır bulunamadı: row=%s, bulunan %d satır" % (row, len(bands)))
        y0, y1 = bands[row]
    seg = rgb[y0:y1]
    green, luma = _masks(seg)
    dark = (~green) & (luma < DARK_LUMA)
    sep = _runs(np.nonzero(dark.mean(axis=0) > 0.85)[0])
    edges = [0]
    spans = []
    for a, b in sep:
        spans.append((edges[-1], a))
        edges.append(b)
    spans.append((edges[-1], seg.shape[1]))
    spans = [(a, b) for a, b in spans if b - a >= MIN_CELL_W]
    out: list[tuple[int, int]] = []
    if spans:
        w_ref = min(b - a for a, b in spans)
        for a, b in spans:
            k = max(1, round((b - a) / w_ref))
            step = (b - a) / k
            for j in range(k):
                out.append((a + round(j * step), a + round((j + 1) * step)))
    if cells is not None:
        if len(out) < cells:  # ayırıcı eksik/yetersiz: tüm satırı eşit böl
            step = seg.shape[1] / cells
            out = [(round(j * step), round((j + 1) * step)) for j in range(cells)]
        out = out[:cells]
    return [seg[:, a + 1:b - 1].copy() if (b - a) > 2 * MIN_CELL_W else seg[:, a:b].copy() for a, b in out]


def split_grid(rgb: np.ndarray, cols: int, rows: int, search: float = 0.12) -> list[np.ndarray]:
    """Izgara: beklenen sınırın ±search aralığında en az dolu sütun/satırdan kes (taşan palto uçları kesilmez)."""
    green, _ = _masks(rgb)
    fill = ~green
    h, w = fill.shape

    def cuts(profile: np.ndarray, n: int, size: int) -> list[int]:
        out = [0]
        for k in range(1, n):
            exp = round(k * size / n)
            r = max(2, int(size / n * search))
            lo, hi = max(out[-1] + 1, exp - r), min(size - 1, exp + r)
            out.append(lo + int(np.argmin(profile[lo:hi + 1])))
        out.append(size)
        return out

    xs = cuts(fill.sum(axis=0), cols, w)
    ys = cuts(fill.sum(axis=1), rows, h)
    return [rgb[ys[r]:ys[r + 1], xs[c]:xs[c + 1]].copy() for r in range(rows) for c in range(cols)]


# ---------------------------------------------------------------- şerit
def _centroid_x(alpha: np.ndarray, y0: int, y1: int) -> float:
    a = alpha[y0:y1]
    xs = np.arange(alpha.shape[1], dtype=np.float64)
    tot = float(a.sum())
    return float((a.sum(axis=0) * xs).sum() / tot) + 0.5 if tot > 0 else alpha.shape[1] / 2.0


def _iou(a: np.ndarray, b: np.ndarray) -> float:
    if a.shape != b.shape:
        b = np.asarray(Image.fromarray((b * 255).astype(np.uint8)).resize((a.shape[1], a.shape[0]), Image.NEAREST)) / 255.0
    m1, m2 = a > 0.5, b > 0.5
    union = int((m1 | m2).sum())
    return float((m1 & m2).sum()) / union if union else 1.0


def trim_edge_lines(rgb: np.ndarray, max_px: int = 4) -> np.ndarray:
    """Hücre kenarında kalan ayırıcı çizgi artıklarını (koyu, tüm boyu dolu sütunlar) atar."""
    green, _ = _masks(rgb)
    x0, x1 = 0, rgb.shape[1]
    for _ in range(max_px):
        if x1 - x0 > MIN_CELL_W and (~green[:, x0]).mean() > 0.5:
            x0 += 1
    for _ in range(max_px):
        if x1 - x0 > MIN_CELL_W and (~green[:, x1 - 1]).mean() > 0.5:
            x1 -= 1
    return rgb[:, x0:x1]


def keep_main_parts(alpha: np.ndarray, min_frac: float = 0.08) -> np.ndarray:
    """Komşu kareden taşan küçük parçaları (palto ucu, benek) siler: ana bileşenin %8'inden küçük bileşenler atılır."""
    from scipy import ndimage

    mask = alpha > 0.5
    grown = ndimage.binary_dilation(mask, iterations=3)
    lab, n = ndimage.label(grown, structure=np.ones((3, 3)))
    if n <= 1:
        return alpha
    area = ndimage.sum(mask, lab, index=np.arange(1, n + 1))
    keep = np.concatenate([[False], area >= min_frac * area.max()])
    return np.where(keep[lab], alpha, 0.0).astype(np.float32)


def build_strip(cells: list[np.ndarray], stand_rgba: np.ndarray | None = None, kind: str = "player",
                drop_dup_last: bool = False, target_height: float | None = None,
                group_size: int | None = None) -> StripResult:
    """cells: RGB uint8 hücre kırpımları. stand_rgba: duruş görseli (RGBA uint8, alfa sınırına kırpılmış olması gerekmez)."""
    if kind not in ("player", "enemy"):
        raise ValueError("kind player|enemy olmalı")
    warnings: list[str] = []
    keyed, boxes, raw_gap = [], [], []
    for i, c in enumerate(cells):
        c = trim_edge_lines(c)
        rgb, alpha = ck.key_image(c)
        alpha = keep_main_parts(alpha)
        if not (alpha > 0.5).any():
            raise ValueError("hücre %d boş: opak piksel yok" % i)
        box = pa.alpha_bbox(alpha, 0.5)
        keyed.append(pa.crop(rgb, alpha, box))
        boxes.append(box)
        raw_gap.append((c.shape[0] - box[3]) / c.shape[0] * CANVAS_1536)
    dropped = False
    if drop_dup_last and len(keyed) >= 3 and _iou(keyed[0][1], keyed[-1][1]) >= DUP_IOU:
        keyed.pop()
        boxes.pop()
        raw_gap.pop()
        dropped = True
    n = len(keyed)
    heights = np.array([k[1].shape[0] for k in keyed], dtype=np.float64)
    widths = np.array([k[1].shape[1] for k in keyed], dtype=np.float64)
    stand_img = None
    stand_h = None
    if stand_rgba is not None:
        sa = stand_rgba[..., 3].astype(np.float32) / 255.0
        sb = pa.alpha_bbox(sa, 0.5)
        stand_img = stand_rgba[sb[1]:sb[3], sb[0]:sb[2]]
        stand_h = stand_img.shape[0]
    ref_h = float(stand_h if stand_h else (target_height or np.median(heights)))
    scale = ref_h / float(np.median(heights))
    placed = []  # (rgb, alpha, anchor_x, h)
    for (rgb, alpha) in keyed:
        h, w = alpha.shape
        nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
        if (nw, nh) != (w, h):
            rgb, alpha = pa.resize_premultiplied(rgb, alpha, (nw, nh))
        ax = _centroid_x(alpha, 0, max(1, nh // 2))
        placed.append((rgb, alpha, ax, nh))
    left = max(p[2] for p in placed)
    right = max(p[1].shape[1] - p[2] for p in placed)
    half = max(left, right)
    if stand_img is not None:
        half = max(half, stand_img.shape[1] / 2.0)
    cw = 2 * int(math.ceil(half))
    ch = max(max(p[3] for p in placed), stand_h or 0)
    n_cells = n + (1 if kind == "player" else 0)
    strip = np.zeros((ch, cw * n_cells, 4), np.uint8)
    placed_alpha = []
    for i, (rgb, alpha, ax, nh) in enumerate(placed):
        x = int(round(cw / 2.0 - ax))
        x = min(max(x, 0), cw - alpha.shape[1])
        y = ch - nh
        tile = pa.to_rgba_u8(rgb, alpha)
        strip[y:y + nh, i * cw + x:i * cw + x + alpha.shape[1]] = tile
        a_full = np.zeros((ch, cw), np.float32)
        a_full[y:y + nh, x:x + alpha.shape[1]] = alpha
        placed_alpha.append((a_full, y, nh))
    shoulder_dev = None
    if kind == "player":
        if stand_img is None:
            warnings.append("duruş görseli yok: shoulder_dev boş")
        else:
            sh, sw = stand_img.shape[:2]
            sx = (cw - sw) // 2
            strip[ch - sh:ch, n * cw + sx:n * cw + sx + sw] = stand_img
            s_alpha = np.zeros((ch, cw), np.float32)
            s_alpha[ch - sh:ch, sx:sx + sw] = stand_img[..., 3] / 255.0
            lx_s = _band_x(s_alpha, ch - sh, sh)
            shoulder_dev = []
            for a_full, y, nh in placed_alpha:
                dx = (_band_x(a_full, y, nh) - lx_s) / ref_h
                dy = -(1.0 - sum(SHOULDER_BAND) / 2.0) * (nh - sh) / ref_h
                shoulder_dev.append([round(float(dx), 4), round(float(dy), 4)])
            shoulder_dev.append([0.0, 0.0])
            if any(abs(v) > SHOULDER_MAX for p in shoulder_dev for v in p):
                warnings.append("omuz sapması ±%.1f dışında: ölçüm güvenilmez, shoulder_dev boş" % SHOULDER_MAX)
                shoulder_dev = []
    med_h, med_w = float(np.median(heights)), float(np.median(widths))
    # ham ayak hizası: kaynak karelerin alt boşluğu; ızgara sayfasında satırlar ayrı değerlendirilir (satır sınırı keyfidir)
    gs = group_size or len(raw_gap)
    groups = [raw_gap[i:i + gs] for i in range(0, len(raw_gap), gs)]
    foot_dev = float(max(max(g) - min(g) for g in groups)) if raw_gap else 0.0
    manifest = {
        "kind": kind,
        "frames": n,
        "cell": [cw, ch],
        "scale": round(scale, 5),
        "display_scale_hint": round(ch / ref_h, 5),
        "dropped_duplicate_last": dropped,
        "quality": {
            "foot_dev_px_1536": round(foot_dev, 2),
            "height_dev_pct": [round(float((h - med_h) / med_h * 100.0), 2) for h in heights],
            "width_dev_pct": [round(float((w - med_w) / med_w * 100.0), 2) for w in widths],
        },
        "warnings": warnings,
    }
    if kind == "player":
        manifest["shoulder_dev"] = shoulder_dev if shoulder_dev is not None else []
    return StripResult(strip, manifest, scale, placed_alpha)


def _band_x(alpha_full: np.ndarray, top: int, h: int) -> float:
    y0 = top + int(h * SHOULDER_BAND[0])
    y1 = max(y0 + 1, top + int(h * SHOULDER_BAND[1]))
    return _centroid_x(alpha_full, y0, y1)


# ---------------------------------------------------------------- önizleme
def write_preview(res: StripResult, out_path: Path, kind: str) -> Path:
    """Şeridi yeşil ve koyu mor zeminde alt alta çizer; ayak çizgisi (kırmızı), merkez (turkuaz), kare numarası."""
    cw, ch = res.manifest["cell"]
    n_cells = res.strip.shape[1] // cw
    rows = []
    for bg in ((3, 157, 8), (0x17, 0x10, 0x19)):
        canvas = Image.new("RGBA", (cw * n_cells, ch + 18), bg + (255,))
        canvas.alpha_composite(Image.fromarray(res.strip, "RGBA"), (0, 18))
        d = ImageDraw.Draw(canvas)
        for i in range(n_cells):
            x = i * cw
            d.line([(x, 18 + ch - 1), (x + cw, 18 + ch - 1)], fill=(255, 40, 40, 255))
            d.line([(x + cw // 2, 18), (x + cw // 2, 18 + ch)], fill=(40, 220, 220, 255))
            d.line([(x, 18), (x, 18 + ch)], fill=(255, 255, 255, 90))
            label = "stand" if (kind == "player" and i == n_cells - 1) else str(i)
            d.text((x + 4, 3), label, fill=(255, 255, 255, 255))
        rows.append(canvas)
    sheet = Image.new("RGBA", (rows[0].width, sum(r.height for r in rows)))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out_path)
    return out_path


# ---------------------------------------------------------------- CLI
def _load_rgb(p: str) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGB"))


def _parse_rows(s: str):
    if ":" in s:
        a, b = s.split(":")
        return (int(a), int(b))
    return int(s)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sheet", help="temas sayfası ya da ızgara görseli")
    ap.add_argument("--frames", nargs="+", help="ayrı kare dosyaları (sheet yerine)")
    ap.add_argument("--rows", default="0", help="satır no (başlık şeritleri arasında) ya da y0:y1")
    ap.add_argument("--grid", help="CxR (ör. 3x2): sayfayı ızgara olarak böl")
    ap.add_argument("--cells", type=int, help="soldan alınacak hücre sayısı")
    ap.add_argument("--drop-dup-last", action="store_true", help="son kare ilkiyle benzerse (alfa IoU >= 0,97) at")
    ap.add_argument("--kind", choices=["player", "enemy"], default="player")
    ap.add_argument("--stand", help="duruş görseli (RGBA PNG): ölçek ve duruş hücresi")
    ap.add_argument("--target-height", type=float, help="duruş görseli yoksa hedef kare boyu (px)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--preview-dir", default=str(PREVIEW_DIR))
    args = ap.parse_args(argv)
    group_size = None
    if args.frames:
        cells = [_load_rgb(f) for f in args.frames]
    elif args.sheet and args.grid:
        c, r = (int(v) for v in args.grid.lower().split("x"))
        cells = split_grid(_load_rgb(args.sheet), c, r)
        group_size = c
    elif args.sheet:
        cells = split_sheet(_load_rgb(args.sheet), _parse_rows(args.rows), args.cells)
    else:
        ap.error("--sheet ya da --frames gerekli")
    stand = np.asarray(Image.open(args.stand).convert("RGBA")) if args.stand else None
    res = build_strip(cells, stand, args.kind, args.drop_dup_last, args.target_height, group_size)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(res.strip, "RGBA").save(out)
    Path(args.manifest).write_text(json.dumps(res.manifest, indent=2, ensure_ascii=False) + "\n")
    for w in res.manifest["warnings"]:
        print("UYARI:", w, file=sys.stderr)
    if args.preview:
        p = write_preview(res, Path(args.preview_dir) / (out.stem + "_preview.png"), args.kind)
        print("önizleme:", p)
    q = res.manifest["quality"]
    print("kare=%d hücre=%s ölçek=%.4f ayak_sapma@1536=%.1f px boy_sapma=%s%%" % (
        res.manifest["frames"], res.manifest["cell"], res.scale, q["foot_dev_px_1536"], [float(v) for v in q["height_dev_pct"]]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
