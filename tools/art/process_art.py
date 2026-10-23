#!/usr/bin/env python3
"""Ashen Bastion sanat işleme hattı: art/ref/** (düz yeşil zeminli PNG) -> assets/gfx/**.

Kullanım:
  python tools/art/process_art.py [--only <id>] [--preview] [--verify]

  --only <id>   yalnız o varlığı işler (art_manifest.json'daki id)
  --preview     yeşil ve koyu mor (#171019) zemin üstünde kontakt sayfası üretir
                (tools/art/_preview/, commit'lenmez)
  --verify      yazmadan, mevcut çıktıları art_manifest.json'a göre denetler (çıkış kodu 1 = hata)

Ayrıntılar: tools/art/README.md
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chroma_key as ck  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).resolve().parent / "art_manifest.json"
PREVIEW_DIR = Path(__file__).resolve().parent / "_preview"
PREVIEW_BGS = {"yesil": (3, 157, 8), "mor": (0x17, 0x10, 0x19)}

# Sağlık eşikleri (health testleri ve --verify aynı değerleri kullanır)
MAX_GREEN_D = 40            # alpha>0 pikselde G-max(R,B) bunu aşamaz
SEAM_MEAN_MAX = 6.0         # kenar sütunları ortalama fark (/255)
SEAM_COL_MAX = 40.0         # tek kenar sütun çifti için maks fark (/255)


# ---------------------------------------------------------------- yardımcılar
def load_rgb(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"))


def resize_premultiplied(rgb: np.ndarray, alpha: np.ndarray, size: tuple[int, int]) -> tuple[np.ndarray, np.ndarray]:
    """Premultiplied LANCZOS küçültme. rgb float32 (H,W,3), alpha float32 0..1 -> aynı türde, size=(w,h)."""
    pm = rgb.astype(np.float32) * alpha[..., None]
    chans = [pm[..., i] for i in range(3)] + [alpha]
    out = [np.asarray(Image.fromarray(c.astype(np.float32), "F").resize(size, Image.LANCZOS)) for c in chans]
    a = np.clip(out[3], 0.0, 1.0)
    pm_o = np.stack(out[:3], axis=-1)
    safe = np.maximum(a, 1e-4)[..., None]
    rgb_o = np.clip(pm_o / safe, 0, 255)
    return rgb_o.astype(np.float32), a.astype(np.float32)


def to_rgba_u8(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Saydam/zayıf piksellerin rengini en yakın opak pikselden doldurup uint8 RGBA üretir."""
    a8 = np.clip(np.rint(alpha * 255.0), 0, 255).astype(np.uint8)
    filled = ck.nearest_fill(rgb, alpha > 0.5)
    out = np.dstack([np.clip(np.rint(filled), 0, 255).astype(np.uint8), a8])
    return out


def alpha_bbox(alpha: np.ndarray, thr: float = 0.05) -> tuple[int, int, int, int]:
    """(x0,y0,x1,y1) yarı açık."""
    ys, xs = np.nonzero(alpha > thr)
    if len(xs) == 0:
        raise ValueError("boş görsel: opak piksel yok")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def crop(rgb, alpha, box):
    x0, y0, x1, y1 = box
    return rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1]


def fit_size(w: int, h: int, max_side: int) -> tuple[int, int]:
    s = max_side / max(w, h)
    if max(w, h) == w:
        return max_side, max(1, round(h * s))
    return max(1, round(w * s)), max_side


def scaled_size(w: int, h: int, scale: float) -> tuple[int, int]:
    return max(1, round(w * scale)), max(1, round(h * scale))


# ---------------------------------------------------------------- bölme
def split_components(alpha: np.ndarray, merge_r: int = 1, min_area: int = 1500, thr: float = 0.1,
                     attach_dist: float = 60.0):
    """Bağlı bileşenler (merge_r px genişletilmiş maske üstünde). [{mask,bbox,area,cx,cy}] okuma sırasıyla.

    min_area'dan küçük parçalar (tek taş, kıymık) silinmez: en yakın büyük bileşene
    `attach_dist` px içindeyse ona eklenir, değilse atılır."""
    mask = alpha > thr
    grown = ndimage.binary_dilation(mask, structure=ck.disk(merge_r)) if merge_r > 0 else mask
    lab, n = ndimage.label(grown, structure=np.ones((3, 3)))
    if n == 0:
        return []
    area = ndimage.sum(mask, lab, index=np.arange(1, n + 1))
    big = np.concatenate([[False], area >= min_area])
    big_lab = np.where(big[lab], lab, 0)
    if big_lab.any():
        dist, idx = ndimage.distance_transform_edt(big_lab == 0, return_indices=True)
        near = big_lab[idx[0], idx[1]]
        final = np.where(big_lab > 0, big_lab, np.where(dist <= attach_dist, near, 0))
    else:
        final = big_lab
    final = np.where(mask, final, 0)
    comps = []
    for i in np.unique(final):
        if i == 0:
            continue
        region = final == i
        ys, xs = np.nonzero(region)
        comps.append({"mask": region, "bbox": (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1),
                      "area": int(region.sum()), "cx": float(xs.mean()), "cy": float(ys.mean())})
    h = alpha.shape[0]
    comps.sort(key=lambda c: (int(c["cy"] // (h / 3.0)), c["cx"]))
    return comps


def split_three_poses(alpha: np.ndarray, merge_r: int = 1, thr: float = 0.1, count: int = 3,
                      min_area: int = 20000):
    """Yan yana/üst üste `count` pozu bağlı bileşen olarak ayırır; soldan sağa sıralı döndürür."""
    comps = split_components(alpha, merge_r=merge_r, min_area=min_area, thr=thr, attach_dist=80.0)
    if len(comps) != count:
        raise ValueError(f"{count} poz bekleniyordu, {len(comps)} bulundu")
    comps.sort(key=lambda c: c["cx"])
    return comps


def foot_point(alpha: np.ndarray, band: float = 0.12) -> tuple[float, float]:
    """Ayak noktası (normalize 0..1): en alttaki %band yükseklik şeridinin alpha ağırlıklı merkezi."""
    h, w = alpha.shape
    ys, xs = np.nonzero(alpha > 0.1)
    y_max = ys.max()
    y_min = max(ys.min(), int(y_max - band * (y_max - ys.min() + 1)))
    sub = alpha[y_min:y_max + 1]
    wy, wx = np.nonzero(sub > 0.1)
    wgt = sub[wy, wx]
    fx = float((wx * wgt).sum() / wgt.sum() + 0.5) / w
    fy = float(((wy + y_min) * wgt).sum() / wgt.sum() + 0.5) / h
    return round(fx, 4), round(fy, 4)


# ---------------------------------------------------------------- zemin
def wrap_resize(img: np.ndarray, out_size: int) -> np.ndarray:
    """Döşenebilir doku için wrap-aware küçültme: kenarlardan karşı yüzün pikselleri taşınarak
    (np.pad 'wrap') küçültülür, ortası kırpılır; böylece Lanczos çekirdeği kenarda dokuyu sarar.
    img (N,N,C) uint8/float -> (out,out,C) float32."""
    n = img.shape[0]
    g = math.gcd(n, out_size)
    step, out_step = n // g, out_size // g
    k = max(1, math.ceil(0.08 * n / step))
    m_src, m_out = k * step, k * out_step
    padded = np.pad(img.astype(np.float32), ((m_src, m_src), (m_src, m_src), (0, 0)), mode="wrap")
    size = out_size + 2 * m_out
    chans = [np.asarray(Image.fromarray(padded[..., c], "F").resize((size, size), Image.LANCZOS))
             for c in range(img.shape[2])]
    res = np.stack(chans, axis=-1)
    return res[m_out:m_out + out_size, m_out:m_out + out_size].astype(np.float32)


def seam_metrics(img: np.ndarray) -> dict:
    """Kenar sütun/satır farkları (0..255). Her iki eksende: ilk ve son sütun çifti.
    mean = tüm çiftlerin kanal ortalama |fark| ortalaması; col_max = tek çiftin (kanal ortalaması) maks farkı."""
    a = img[..., :3].astype(np.float32)
    dx = np.abs(a[:, 0] - a[:, -1]).mean(axis=1)
    dy = np.abs(a[0] - a[-1]).mean(axis=1)
    return {"mean": float(max(dx.mean(), dy.mean())), "col_max": float(max(dx.max(), dy.max()))}


def seam_ok(img: np.ndarray) -> bool:
    m = seam_metrics(img)
    return m["mean"] < SEAM_MEAN_MAX and m["col_max"] <= SEAM_COL_MAX


def seam_blend(img: np.ndarray, band: int = 24) -> np.ndarray:
    """Seamless'a yaklaştırıcı kenar harmanlama (her iki eksen).

    Kenardan t piksel içerideki x için: out(x) = (1-w) I(x) + w I(W-1-x), w = 0.5 (1 - t/band) (t<band).
    Zıt kenardaki eş piksel aynı karışımı alır, bu yüzden ilk/son sütun eşitlenir. Etki yalnız kenardan
    `band` px içeride; bant içinde karşı kenarın aynalı bir izi (hafif hayalet) görünür."""
    a = img.astype(np.float32)
    n = a.shape[0]
    t = np.minimum(np.arange(n), np.arange(n)[::-1]).astype(np.float32)
    w = np.where(t < band, 0.5 * (1.0 - t / band), 0.0)
    wx = w[None, :, None]
    a = (1 - wx) * a + wx * a[:, ::-1]
    wy = w[:, None, None]
    a = (1 - wy) * a + wy * a[::-1]
    return a


def process_ground(src: np.ndarray, size: int, blend_band: int = 24):
    """-> (RGB uint8 (size,size,3), info). Önce wrap-aware küçültme; dikiş eşiği aşılırsa kenar harmanlama."""
    small = wrap_resize(src, size)
    info = {"seam_before": seam_metrics(small), "blended": False}
    if not seam_ok(small):
        small = seam_blend(small, blend_band)
        info["blended"] = True
    info["seam_after"] = seam_metrics(small)
    return np.clip(np.rint(small), 0, 255).astype(np.uint8), info


# ---------------------------------------------------------------- varlık işleme
def key_source(entry: dict, root: Path):
    rgb_u8 = load_rgb(root / entry["src"])
    p = entry.get("key", {})
    return ck.key_image(rgb_u8, d_lo=p.get("d_lo", ck.D_LO), d_hi=p.get("d_hi", ck.D_HI),
                        smoke=entry.get("smoke_cleanup"), min_speck=p.get("min_speck", 30))


def process_sprite(entry: dict, root: Path):
    rgb, alpha = key_source(entry, root)
    box = alpha_bbox(alpha)
    rgb, alpha = crop(rgb, alpha, box)
    h, w = alpha.shape
    size = fit_size(w, h, entry["max_side"])
    rgb, alpha = resize_premultiplied(rgb, alpha, size)
    return [(entry["out"], to_rgba_u8(rgb, alpha), 1)], {}


def process_poses(entry: dict, root: Path):
    rgb, alpha = key_source(entry, root)
    n = entry.get("frames", 3)
    comps = split_three_poses(alpha, merge_r=entry.get("merge_r", 1), count=n, min_area=entry.get("min_area", 20000))
    crops = []
    for c in comps:
        a = np.where(c["mask"], alpha, 0.0).astype(np.float32)
        box = c["bbox"]
        crops.append(crop(rgb, a, box))
    mw = max(a.shape[1] for _, a in crops)
    mh = max(a.shape[0] for _, a in crops)
    fw = entry["frame_width"]
    s = fw / mw
    fh = max(1, math.ceil(mh * s))
    atlas = np.zeros((fh, fw * n, 4), np.uint8)
    for i, (r, a) in enumerate(crops):
        w = max(1, min(fw, round(a.shape[1] * s)))
        h = max(1, min(fh, round(a.shape[0] * s)))
        ro, ao = resize_premultiplied(r, a, (w, h))
        tile = to_rgba_u8(ro, ao)
        ox = i * fw + (fw - w) // 2
        oy = (fh - h) // 2
        atlas[oy:oy + h, ox:ox + w] = tile
    return [(entry["out"], atlas, n)], {"frame_size": [fw, fh]}


def process_components(entry: dict, root: Path):
    rgb, alpha = key_source(entry, root)
    comps = split_components(alpha, merge_r=entry.get("merge_r", 1), min_area=entry.get("min_area", 1500))
    scale = entry["scale"]
    out_dir = entry["out_dir"]
    files, items = [], []
    for i, c in enumerate(comps, 1):
        a = np.where(c["mask"], alpha, 0.0).astype(np.float32)
        r, a = crop(rgb, a, c["bbox"])
        w, h = scaled_size(a.shape[1], a.shape[0], scale)
        ro, ao = resize_premultiplied(r, a, (w, h))
        cid = f"{entry.get('id_prefix', 'ruin')}_{i:02d}"
        rel = f"{out_dir}/{cid}.png"
        files.append((rel, to_rgba_u8(ro, ao), 1))
        items.append({"id": cid, "file": "res://" + rel, "size": [w, h], "foot": list(foot_point(ao)),
                      "src_bbox": list(c["bbox"])})
    lo, hi = entry.get("count", [20, 30])
    if not lo <= len(items) <= hi:
        raise ValueError(f"{entry['id']}: bileşen sayısı {len(items)}, beklenen {lo}-{hi}")
    meta = {"scale": scale, "source": entry["src"], "count": len(items), "ruins": items}
    return files, {"ruins_manifest": (entry["manifest_out"], meta)}


def process_tile(entry: dict, root: Path):
    src = load_rgb(root / entry["src"])
    img, info = process_ground(src, entry["size"], entry.get("blend_band", 24))
    rgba = np.dstack([img, np.full(img.shape[:2], 255, np.uint8)])
    return [(entry["out"], rgba, 1)], {"seam": info}


KINDS = {"sprite": process_sprite, "three_poses": process_poses, "components": process_components,
         "tile": process_tile}


def load_manifest(path: Path = MANIFEST) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_png(path: Path, arr: np.ndarray):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(path, optimize=True)


def run(manifest: dict, root: Path, out_root: Path, only: str | None = None, log=print) -> dict:
    """Varlıkları işler; çıktıları out_root altına yazar; gfx manifest sözlüğünü döndürür."""
    entries = [e for e in manifest["assets"] if only in (None, e["id"])]
    if only and not entries:
        raise SystemExit(f"bilinmeyen id: {only}")
    gfx_path = out_root / manifest.get("gfx_manifest", "assets/gfx/manifest.json")
    gfx = {"version": 1, "files": {}}
    if gfx_path.exists():
        gfx = json.loads(gfx_path.read_text(encoding="utf-8"))
    results = {}
    for e in entries:
        files, extra = KINDS[e["kind"]](e, root)
        if "ruins_manifest" in extra:  # eski bileşen dosyalarını temizle
            d = out_root / e["out_dir"]
            for old in d.glob("*.png"):
                old.unlink()
            for k in [k for k in gfx["files"] if k.startswith(e["out_dir"] + "/")]:
                del gfx["files"][k]
        for rel, arr, frames in files:
            write_png(out_root / rel, arr)
            gfx["files"][rel] = {"source": e["src"], "size": [int(arr.shape[1]), int(arr.shape[0])], "frames": frames}
        if "ruins_manifest" in extra:
            rel, meta = extra["ruins_manifest"]
            p = out_root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(json.dumps(meta, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        results[e["id"]] = {"files": [(r, a.shape[1], a.shape[0], f) for r, a, f in files], "extra": extra}
        log(f"[{e['id']}] " + ", ".join(f"{r.split('/')[-1]} {w}x{h}" for r, w, h, _ in results[e['id']]["files"][:3])
            + (f" (+{len(files) - 3} dosya)" if len(files) > 3 else ""))
        if "seam" in extra:
            log(f"    dikis: {extra['seam']}")
    gfx["files"] = dict(sorted(gfx["files"].items()))
    gfx_path.parent.mkdir(parents=True, exist_ok=True)
    gfx_path.write_text(json.dumps(gfx, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    return results


# ---------------------------------------------------------------- önizleme / doğrulama
def preview(manifest: dict, out_root: Path, only: str | None = None, log=print):
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    gfx = json.loads((out_root / manifest.get("gfx_manifest", "assets/gfx/manifest.json")).read_text(encoding="utf-8"))
    for e in manifest["assets"]:
        if only not in (None, e["id"]):
            continue
        rels = [r for r in gfx["files"] if (r == e.get("out")) or (e.get("out_dir") and r.startswith(e["out_dir"] + "/"))]
        tiles = [Image.open(out_root / r).convert("RGBA") for r in rels]
        if not tiles:
            continue
        cols = 1 if len(tiles) == 1 else 6
        pad = 8
        cw = max(t.width for t in tiles) + pad
        ch = max(t.height for t in tiles) + pad
        rows = math.ceil(len(tiles) / cols)
        sheets = []
        for name, col in PREVIEW_BGS.items():
            sheet = Image.new("RGBA", (cols * cw + pad, rows * ch + pad), col + (255,))
            for i, t in enumerate(tiles):
                sheet.alpha_composite(t, (pad + (i % cols) * cw, pad + (i // cols) * ch))
            sheets.append(sheet)
        both = Image.new("RGBA", (sheets[0].width * 2, sheets[0].height), (0, 0, 0, 255))
        both.paste(sheets[0], (0, 0))
        both.paste(sheets[1], (sheets[0].width, 0))
        out = PREVIEW_DIR / f"{e['id']}.png"
        both.convert("RGB").save(out)
        log(f"onizleme: {out}")


def verify(manifest: dict, out_root: Path, only: str | None = None) -> list[str]:
    """Mevcut çıktıları denetler; hata mesajları listesi döndürür (boş = tamam)."""
    errs = []
    gfx_path = out_root / manifest.get("gfx_manifest", "assets/gfx/manifest.json")
    if not gfx_path.exists():
        return [f"eksik: {gfx_path}"]
    gfx = json.loads(gfx_path.read_text(encoding="utf-8"))["files"]
    for e in manifest["assets"]:
        if only not in (None, e["id"]):
            continue
        if e["kind"] == "components":
            mp = out_root / e["manifest_out"]
            if not mp.exists():
                errs.append(f"{e['id']}: eksik {e['manifest_out']}")
                continue
            meta = json.loads(mp.read_text(encoding="utf-8"))
            lo, hi = e.get("count", [20, 30])
            if not lo <= meta["count"] <= hi or meta["count"] != len(meta["ruins"]):
                errs.append(f"{e['id']}: bilesen sayisi {meta['count']}")
            rels = [it["file"].replace("res://", "") for it in meta["ruins"]]
        else:
            rels = [e["out"]]
        for rel in rels:
            p = out_root / rel
            if not p.exists():
                errs.append(f"eksik: {rel}")
                continue
            im = Image.open(p)
            if im.mode != "RGBA":
                errs.append(f"{rel}: RGBA degil")
            rec = gfx.get(rel)
            if not rec or rec["size"] != [im.width, im.height]:
                errs.append(f"{rel}: gfx manifest boyutu uyusmuyor ({rec and rec['size']} != {im.size})")
            a = np.asarray(im.convert("RGBA"))
            vis = a[..., 3] > 0
            if e["kind"] != "tile" and vis.any():
                d = ck.green_dominance(a[..., :3])
                if (d[vis] > MAX_GREEN_D).any():
                    errs.append(f"{rel}: yesil kalinti (G-max(R,B) > {MAX_GREEN_D})")
            if e["kind"] == "sprite":
                if max(im.size) != e["max_side"]:
                    errs.append(f"{rel}: hedef boy {e['max_side']}, bulunan {im.size}")
            if e["kind"] == "three_poses":
                if im.width != e["frame_width"] * rec["frames"] or rec["frames"] != e.get("frames", 3):
                    errs.append(f"{rel}: atlas kare uyumsuz")
            if e["kind"] == "tile":
                if im.size != (e["size"], e["size"]):
                    errs.append(f"{rel}: boyut {im.size}")
                if not seam_ok(a):
                    errs.append(f"{rel}: dikis esigi asildi {seam_metrics(a)}")
    return errs


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="yalnız bu id'yi işle")
    ap.add_argument("--preview", action="store_true", help="kontakt sayfası üret (tools/art/_preview/)")
    ap.add_argument("--verify", action="store_true", help="yazmadan mevcut çıktıları denetle")
    args = ap.parse_args(argv)
    manifest = load_manifest()
    if args.verify:
        errs = verify(manifest, REPO, args.only)
        for m in errs:
            print("HATA:", m)
        print("dogrulama:", "BASARISIZ" if errs else "tamam")
        return 1 if errs else 0
    run(manifest, REPO, REPO, args.only)
    if args.preview:
        preview(manifest, REPO, args.only)
    return 0


if __name__ == "__main__":
    sys.exit(main())
