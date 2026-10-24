"""process_gunslinger_icons.py (v2.0.2 A2b): 19 Gunslinger ikonu %80 kare tuval, depodaki çıktılar kaynaktan türer."""
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import process_gunslinger_icons as pg  # noqa: E402

pytestmark = pytest.mark.skipif(not pg.SRC_ICONS.exists(), reason="art/ kaynakları yok")


def test_lists_cover_19_icons():
    assert len(pg.ACTIVES) == 7 and len(pg.EVOLUTIONS) == 4 and len(pg.PASSIVES) == 1 and len(pg.COMMON_PASSIVES) == 7
    assert len(set(pg.ALL)) == len(pg.ALL) == 19
    for n in pg.ALL:
        assert (pg.SRC_ICONS / f"{n}.png").exists(), n


@pytest.mark.parametrize("name", pg.ALL)
def test_icon_is_square_centered_at_80_percent(name):
    im = pg.make_icon(pg.SRC_ICONS / f"{name}.png")
    assert im.size == (pg.ICON_SIZE, pg.ICON_SIZE)
    box = im.getchannel("A").point(lambda v: 255 if v > 3 else 0).getbbox()
    side = max(box[2] - box[0], box[3] - box[1])
    assert abs(side / pg.ICON_SIZE - pg.ICON_FILL) < 0.02
    assert abs((box[0] + box[2]) / 2 - pg.ICON_SIZE / 2) < 3 and abs((box[1] + box[3]) / 2 - pg.ICON_SIZE / 2) < 3


def test_repository_outputs_match_a_fresh_build_and_zyfen_variants_stay():
    assert pg.run(check=True) == 0
    for name in pg.ALL:
        out = Image.open(pg.icon_out(name))
        fresh = pg.make_icon(pg.SRC_ICONS / f"{name}.png")
        assert np.abs(np.asarray(out, dtype=int) - np.asarray(fresh, dtype=int)).max() <= 2
    for name in pg.COMMON_PASSIVES:
        assert (pg.OUT_ICONS / "zyfen" / (name.replace("_", "-") + ".png")).exists(), name
