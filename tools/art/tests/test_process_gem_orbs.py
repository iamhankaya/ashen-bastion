"""process_gem_orbs.py (v2.0.3 B): 3 küre 128x128 RGBA, şeffaf köşe, depodaki çıktılar kaynaktan türer."""
import sys
from pathlib import Path

import pytest
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import process_gem_orbs as pg  # noqa: E402

pytestmark = pytest.mark.skipif(not pg.SRC.exists(), reason="art/ kaynakları yok")


def test_three_orbs_square_rgba_with_transparent_corners():
    assert pg.NAMES == ["normal", "elit", "ara_boss"]
    for n in pg.NAMES:
        img = Image.open(pg.OUT / f"{n}.png")
        assert img.size == (pg.SIZE, pg.SIZE) and img.mode == "RGBA", n
        assert img.getpixel((0, 0))[3] == 0 and img.getpixel((pg.SIZE - 1, pg.SIZE - 1))[3] == 0, n


def test_committed_outputs_match_sources():
    assert pg.main(["--check"]) == 0


def test_orbs_differ_in_mean_colour():
    def mean(n):
        px = [p for p in Image.open(pg.OUT / f"{n}.png").getdata() if p[3] > 200]
        return tuple(sum(c[i] for c in px) / len(px) for i in range(3))
    m = [mean(n) for n in pg.NAMES]
    for i in range(3):
        for j in range(i + 1, 3):
            assert sum(abs(a - b) for a, b in zip(m[i], m[j])) > 60, (i, j)


def test_normal_orb_is_visible_at_least_20px_wide_at_its_game_size():
    # F-075: boş pay normal küreyi 34 px kutuda ~14 px gösteriyordu; ORB_PX GemTiers.NORMAL = 44 (gem_tiers.gd).
    normal_px = 44
    alpha = Image.open(pg.OUT / "normal.png").getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    x0, _, x1, _ = alpha.getbbox()
    assert (x1 - x0) / pg.SIZE * normal_px >= 20
