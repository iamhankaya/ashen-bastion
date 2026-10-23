"""Veri sağlık testleri: GERÇEK art/ref görsellerine bağlı eşikler. Eşik ihlali = hata.

Hat bir kez geçici dizine çalıştırılır; sonuç hem eşiklere hem de commit'li assets/gfx'e karşı denetlenir.
"""
import json
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

import chroma_key as ck
import process_art as pa

REPO = pa.REPO


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    out = tmp_path_factory.mktemp("gfx")
    man = pa.load_manifest()
    res = pa.run(man, REPO, out, log=lambda *_: None)
    return man, out, res


def entry(man, i):
    return next(e for e in man["assets"] if e["id"] == i)


def test_targets(built):
    man, out, _ = built
    for e in man["assets"]:
        if e["kind"] == "sprite":
            im = Image.open(out / e["out"])
            assert max(im.size) == e["max_side"], e["id"]
    assert pa.verify(man, out) == []


def test_no_green_left(built):
    man, out, _ = built
    for e in man["assets"]:
        if e["kind"] == "tile":
            continue
        paths = sorted((out / e["out_dir"]).glob("*.png")) if e["kind"] == "components" else [out / e["out"]]
        for p in paths:
            a = np.asarray(Image.open(p).convert("RGBA"))
            vis = a[..., 3] > 0
            assert (ck.green_dominance(a[..., :3])[vis] <= pa.MAX_GREEN_D).all(), p.name


@pytest.mark.parametrize("src", ["art/ref/harita/harabe-parcalari.png", "art/ref/parca-govde-kolsuz.png",
                                 "art/ref/dusmanlar/curumus-piyade.png"])
def test_plant_tones_preserved(src):
    rgb = pa.load_rgb(REPO / src).astype(int)
    d = ck.green_dominance(rgb)
    olive = (d >= 4) & (d <= 25) & (rgb[..., 1] >= 50) & (rgb[..., 0] > 40)  # zeytin/yosun tonu
    if olive.sum() < 200:
        pytest.skip("anlamlı bitki ton sayısı yok")
    _, alpha = ck.key_image(rgb.astype(np.uint8))
    assert (alpha[olive] >= 0.95).mean() >= 0.95


def test_ruins_count(built):
    man, out, _ = built
    meta = json.loads((out / entry(man, "ruins")["manifest_out"]).read_text())
    assert 20 <= meta["count"] <= 30
    for it in meta["ruins"]:
        assert 0 <= it["foot"][0] <= 1 and 0 <= it["foot"][1] <= 1


def test_crows_three_frames(built):
    man, out, res = built
    e = entry(man, "les_kargasi")
    im = Image.open(out / e["out"])
    assert im.width == 3 * e["frame_width"]
    a = np.asarray(im)[..., 3]
    for i in range(3):
        assert (a[:, i * 192:(i + 1) * 192] > 128).sum() > 500


def test_ground_seam(built):
    man, out, _ = built
    a = np.asarray(Image.open(out / entry(man, "ground")["out"]))
    assert a.shape[:2] == (768, 768)
    m = pa.seam_metrics(a)
    assert m["mean"] < pa.SEAM_MEAN_MAX and m["col_max"] <= pa.SEAM_COL_MAX


def test_committed_assets_match_build(built):
    """Commit'li assets/gfx, mevcut art/ref + manifest ile aynı boyutlarda mı (bayat çıktı yakalanır)."""
    man, out, _ = built
    committed = json.loads((REPO / "assets/gfx/manifest.json").read_text())["files"]
    fresh = json.loads((out / "assets/gfx/manifest.json").read_text())["files"]
    assert committed == fresh
    for rel in fresh:
        assert (REPO / rel).exists(), rel
