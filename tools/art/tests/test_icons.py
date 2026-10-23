"""Uygulama ikonu setinin boyut/kanal/içerik testleri (commit'li çıktılar + taze üretim)."""
import numpy as np
from PIL import Image

import make_icons as mi


def load(name):
    return Image.open(mi.OUT / name)


def test_sizes_and_modes():
    assert load("main_192x192.png").size == (192, 192)
    for n in ("foreground", "background", "monochrome"):
        im = load(f"{n}_432x432.png")
        assert im.size == (432, 432)
    assert load("foreground_432x432.png").mode == "RGBA"
    assert load("monochrome_432x432.png").mode == "RGBA"


def test_background_opaque_foreground_empty():
    bg = load("background_432x432.png").convert("RGBA")
    assert np.asarray(bg)[..., 3].min() == 255
    assert np.asarray(load("foreground_432x432.png"))[..., 3].max() == 0


def test_monochrome_white_in_safe_zone():
    a = np.asarray(load("monochrome_432x432.png"))
    vis = a[..., 3] > 0
    assert vis.sum() > 5000
    ys, xs = np.where(vis)
    lo, hi = (432 - mi.SAFE) // 2 - 2, (432 + mi.SAFE) // 2 + 2
    assert xs.min() >= lo and xs.max() <= hi and ys.min() >= lo and ys.max() <= hi
    assert (a[vis][:, :3] == 255).all()


def test_committed_icons_match_fresh_output():
    for name, im in mi.outputs().items():
        got = np.asarray(load(name)).astype(int)
        assert got.shape == np.asarray(im).shape and np.abs(got - np.asarray(im).astype(int)).max() == 0, name


def test_frame_cropped_out():
    # köşe pikselleri çerçeve gri/parlak değil: koyu sanat
    m = np.asarray(mi.load_art()).astype(int)
    for y, x in ((0, 0), (0, -1), (-1, 0), (-1, -1)):
        assert m[y, x].max() < 140
