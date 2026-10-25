"""process_zyfen_fx.py (v2.0.2 A2a + fx v2): ikon %80 kare tuval, 32 efekt parçası >= %8 şeffaf pay ve boyut tavanı, akış dokusu dikişsiz, depodaki çıktılar kaynaktan türer."""
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import process_zyfen_fx as pz  # noqa: E402

pytestmark = pytest.mark.skipif(not pz.SRC_ICONS.exists(), reason="art/ kaynakları yok")


def src_fx(name):
    return pz.SRC_FX / pz.FX_V2[name][0] / f"{name}.png"


def test_lists_cover_20_icons_and_32_effect_parts():
    assert len(pz.WIND_SKILLS) == 13 and len(pz.PASSIVE_VARIANTS) == 7 and len(pz.FX_NAMES) == 32
    for n in [*pz.WIND_SKILLS, *pz.PASSIVE_VARIANTS]:
        assert (pz.SRC_ICONS / f"{n}.png").exists(), n
    for n in pz.FX_NAMES:
        assert src_fx(n).exists(), n


@pytest.mark.parametrize("name", pz.WIND_SKILLS + list(pz.PASSIVE_VARIANTS))
def test_icon_is_square_centered_at_80_percent(name):
    im = pz.make_icon(pz.SRC_ICONS / f"{name}.png")
    assert im.size == (pz.ICON_SIZE, pz.ICON_SIZE)
    box = im.getchannel("A").point(lambda v: 255 if v > pz.ALPHA_EPS else 0).getbbox()
    side = max(box[2] - box[0], box[3] - box[1])
    assert abs(side / pz.ICON_SIZE - pz.ICON_FILL) < 0.02
    assert abs((box[0] + box[2]) / 2 - pz.ICON_SIZE / 2) < 3 and abs((box[1] + box[3]) / 2 - pz.ICON_SIZE / 2) < 3


NON_TILE = [n for n in pz.FX_NAMES if n != pz.TILE_NAME]


@pytest.mark.parametrize("name", NON_TILE)
def test_fx_has_clear_margin_and_size_cap_and_keeps_aspect(name):
    src = Image.open(src_fx(name))
    cap = pz.FX_V2[name][1]
    im = pz.make_fx(src_fx(name), cap)
    assert max(im.size) <= cap
    assert pz.margin_ok(im, pz.MARGIN - 0.005)
    assert abs(im.width / im.height - src.width / src.height) < 0.02


def test_size_classes_projectiles_regions_and_small_parts():
    assert max(pz.make_fx(src_fx("kesik"), pz.FX_V2["kesik"][1]).size) == 512
    assert max(pz.make_fx(src_fx("dalga"), pz.FX_V2["dalga"][1]).size) == 512
    for n in ("tas_1", "tas_2", "tas_3", "tas_4", "parilti"):
        assert max(pz.make_fx(src_fx(n), pz.FX_V2[n][1]).size) <= 128, n


def _premult(im):
    a = np.asarray(im.convert("RGBA"), dtype=float) / 255.0
    a[..., :3] *= a[..., 3:4]
    return a


def test_flow_texture_is_square_and_tiles_without_a_visible_seam():
    im = pz.make_tile(src_fx(pz.TILE_NAME), pz.FX_V2[pz.TILE_NAME][1])
    assert im.width == im.height and im.width <= pz.FX_MID
    a = _premult(im)
    wrap = (np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0] - a[-1]).mean()) / 2
    inner = np.mean([np.abs(a[:, k] - a[:, k + 1]).mean() for k in range(50, 200, 10)])
    assert wrap < inner * 2.0, "döşeme kenarı iç komşuluktan belirgin kopuk"


def test_repository_outputs_exist_and_match_a_fresh_build():
    assert pz.run(check=True) == 0
    for name, (_, cap) in pz.FX_V2.items():
        out = Image.open(pz.OUT_FX / f"fx_{name}.png")
        fresh = pz.make_tile(src_fx(name), cap) if name == pz.TILE_NAME else pz.make_fx(src_fx(name), cap)
        assert out.size == fresh.size
        assert np.abs(np.asarray(out, dtype=int) - np.asarray(fresh, dtype=int)).max() <= 2
    for stale in pz.FX_STALE:
        assert not (pz.OUT_FX / f"{stale}.png").exists(), stale
