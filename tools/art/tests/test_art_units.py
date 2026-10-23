"""Sentetik fixture ile birim testleri (gerçek görsele bağlı değil)."""
import json

import numpy as np
from PIL import Image

import chroma_key as ck
import process_art as pa

BG = (3, 157, 8)
OLIVE = (95, 105, 35)


def canvas(h=60, w=80):
    a = np.zeros((h, w, 3), np.uint8)
    a[:] = BG
    return a


def test_olive_kept_pure_green_transparent():
    a = canvas()
    a[10:30, 10:30] = (120, 70, 50)       # nesne
    a[15:20, 15:20] = OLIVE               # nesne içinde zeytin bitki
    rgb, alpha = ck.key_image(a)
    assert alpha[17, 17] == 1.0
    assert alpha[2, 2] == 0.0
    assert alpha[20, 12] == 1.0
    assert tuple(np.rint(rgb[17, 17])) == OLIVE


def test_edge_green_spill_cleaned():
    a = canvas()
    a[10:30, 10:30] = (120, 70, 50)
    # kenarda yeşille karışmış piksel sütunu
    a[10:30, 30] = (60, 110, 30)
    a[10:30, 9] = (60, 120, 28)
    rgb, alpha = ck.key_image(a)
    vis = alpha > 0
    assert vis.any()
    assert (ck.green_dominance(rgb)[vis] <= 8).all()


def test_hole_transparent_and_speck_removed():
    a = canvas()
    a[10:40, 10:50] = (120, 70, 50)
    a[20:25, 20:25] = BG                  # delik
    a[2, 2] = (120, 70, 50)               # tek piksel gürültü
    _, alpha = ck.key_image(a)
    assert alpha[22, 22] == 0.0
    assert alpha[2, 2] == 0.0


def test_sprite_size_and_manifest(tmp_path):
    root = tmp_path / "r"
    (root / "art").mkdir(parents=True)
    a = canvas(100, 200)
    a[20:80, 30:170] = (120, 70, 50)
    Image.fromarray(a).save(root / "art" / "s.png")
    man = {"gfx_manifest": "assets/gfx/manifest.json", "assets": [
        {"id": "s", "kind": "sprite", "src": "art/s.png", "out": "assets/gfx/s.png", "max_side": 70}]}
    out = tmp_path / "o"
    pa.run(man, root, out, log=lambda *_: None)
    im = Image.open(out / "assets/gfx/s.png")
    assert im.mode == "RGBA" and max(im.size) == 70 and im.size == (70, 30)
    g = json.loads((out / "assets/gfx/manifest.json").read_text())
    assert g["files"]["assets/gfx/s.png"] == {"source": "art/s.png", "size": [70, 30], "frames": 1}
    assert pa.verify(man, out) == []


def blobs(positions, size=(300, 400), r=25):
    a = canvas(*size)
    for cx, cy in positions:
        a[cy - r:cy + r, cx - r:cx + r] = (120, 70, 50)
    return a


def test_component_split(tmp_path):
    root = tmp_path / "r"
    (root / "art").mkdir(parents=True)
    pos = [(60 + 70 * (i % 5), 60 + 90 * (i // 5)) for i in range(10)]
    Image.fromarray(blobs(pos, (300, 400))).save(root / "art" / "c.png")
    man = {"assets": [{"id": "c", "kind": "components", "src": "art/c.png", "out_dir": "assets/gfx/map/ruins",
                       "manifest_out": "assets/gfx/map/ruins_manifest.json", "scale": 0.5,
                       "min_area": 100, "count": [5, 12]}]}
    out = tmp_path / "o"
    pa.run(man, root, out, log=lambda *_: None)
    meta = json.loads((out / "assets/gfx/map/ruins_manifest.json").read_text())
    assert meta["count"] == 10 == len(meta["ruins"])
    for it in meta["ruins"]:
        assert it["size"] == [25, 25]
        assert 0 < it["foot"][0] < 1 and 0.5 < it["foot"][1] <= 1
        assert (out / it["file"].replace("res://", "")).exists()
    assert pa.verify(man, out) == []


def test_three_poses_atlas(tmp_path):
    root = tmp_path / "r"
    (root / "art").mkdir(parents=True)
    a = canvas(200, 400)
    a[20:60, 20:140] = (120, 70, 50)
    a[120:190, 150:250] = (50, 70, 120)
    a[30:90, 280:380] = (120, 120, 50)
    Image.fromarray(a).save(root / "art" / "p.png")
    man = {"assets": [{"id": "p", "kind": "three_poses", "src": "art/p.png", "out": "assets/gfx/p.png",
                       "frame_width": 60, "frames": 3, "min_area": 500}]}
    out = tmp_path / "o"
    pa.run(man, root, out, log=lambda *_: None)
    im = Image.open(out / "assets/gfx/p.png")
    assert im.width == 180 and im.height % 1 == 0
    g = json.loads((out / "assets/gfx/manifest.json").read_text())["files"]["assets/gfx/p.png"]
    assert g["frames"] == 3
    alpha = np.asarray(im)[..., 3]
    fw = 60
    for i in range(3):
        assert (alpha[:, i * fw:(i + 1) * fw] > 0).any()
    # soldan sağa: sol poz kırmızımsı, orta mavimsi, sağ sarımsı
    px = np.asarray(im)
    mid = lambda i: px[:, i * fw:(i + 1) * fw][alpha[:, i * fw:(i + 1) * fw] > 200][:, :3].mean(0)
    assert mid(0)[0] > mid(0)[2] and mid(1)[2] > mid(1)[0] and mid(2)[1] > mid(2)[2]


def test_wrap_resize_is_wrap_aware():
    """Dönme eşdeğerliği: kaynağı bir adım kaydırıp küçültmek = küçültüp kaydırmak (yalnız wrap-aware'de)."""
    rng = np.random.default_rng(0)
    n, out = 120, 48            # gcd 24 -> kaynak adımı 5, çıktı adımı 2
    img = rng.integers(0, 255, (n, n, 3)).astype(np.float32)
    rolled = np.roll(img, 5, axis=(0, 1))
    good = np.roll(pa.wrap_resize(img, out), 2, axis=(0, 1))
    assert good.shape == (out, out, 3)
    assert np.abs(good - pa.wrap_resize(rolled, out)).max() < 1e-2

    def naive(a):
        return np.stack([np.asarray(Image.fromarray(a[..., c], "F").resize((out, out), Image.LANCZOS))
                         for c in range(3)], -1)
    assert np.abs(np.roll(naive(img), 2, axis=(0, 1)) - naive(rolled)).max() > 1.0


def test_seam_blend_closes_seam():
    rng = np.random.default_rng(1)
    img = rng.integers(0, 255, (64, 64, 3)).astype(np.float32)
    assert not pa.seam_ok(img)
    b = pa.seam_blend(img, 8)
    assert pa.seam_ok(b)
    assert np.allclose(b[10:54, 20:44], img[10:54, 20:44])  # orta bölge dokunulmaz
