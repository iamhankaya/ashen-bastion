"""process_zyfen_fx.py (v2.0.2 A2a): ikon %80 kare tuval, efekt >= %8 şeffaf pay ve <= 512 px, depodaki çıktılar kaynaktan türer."""
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import process_zyfen_fx as pz  # noqa: E402

pytestmark = pytest.mark.skipif(not pz.SRC_ICONS.exists(), reason="art/ kaynakları yok")


def test_lists_cover_20_icons_and_13_effects():
    assert len(pz.WIND_SKILLS) == 13 and len(pz.PASSIVE_VARIANTS) == 7 and len(pz.FX_NAMES) == 13
    for n in [*pz.WIND_SKILLS, *pz.PASSIVE_VARIANTS]:
        assert (pz.SRC_ICONS / f"{n}.png").exists(), n
    for n in pz.FX_NAMES:
        assert (pz.SRC_FX / f"{n}.png").exists(), n


@pytest.mark.parametrize("name", pz.WIND_SKILLS + list(pz.PASSIVE_VARIANTS))
def test_icon_is_square_centered_at_80_percent(name):
    im = pz.make_icon(pz.SRC_ICONS / f"{name}.png")
    assert im.size == (pz.ICON_SIZE, pz.ICON_SIZE)
    box = im.getchannel("A").point(lambda v: 255 if v > pz.ALPHA_EPS else 0).getbbox()
    side = max(box[2] - box[0], box[3] - box[1])
    assert abs(side / pz.ICON_SIZE - pz.ICON_FILL) < 0.02
    assert abs((box[0] + box[2]) / 2 - pz.ICON_SIZE / 2) < 3 and abs((box[1] + box[3]) / 2 - pz.ICON_SIZE / 2) < 3


@pytest.mark.parametrize("name", pz.FX_NAMES)
def test_fx_has_clear_margin_and_size_cap_and_keeps_aspect(name):
    src = Image.open(pz.SRC_FX / f"{name}.png")
    im = pz.make_fx(pz.SRC_FX / f"{name}.png")
    assert max(im.size) <= pz.FX_MAX
    assert pz.margin_ok(im, pz.MARGIN - 0.005)
    assert abs(im.width / im.height - src.width / src.height) < 0.02


def test_repository_outputs_exist_and_match_a_fresh_build():
    assert pz.run(check=True) == 0
    for name in pz.FX_NAMES:
        out = Image.open(pz.OUT_FX / f"{name}.png")
        fresh = pz.make_fx(pz.SRC_FX / f"{name}.png")
        assert out.size == fresh.size
        assert np.abs(np.asarray(out, dtype=int) - np.asarray(fresh, dtype=int)).max() <= 2
