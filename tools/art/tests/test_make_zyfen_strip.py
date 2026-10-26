"""make_zyfen_strip.py (v2.0.2 U2): kare şeridi, ayak çapası hizası, kalite kapısı, depodaki çıktıların tutarlılığı."""
import glob
import json
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import make_zyfen_strip as mz  # noqa: E402

SRC = ROOT / "art" / "source" / "zyfen"


@pytest.fixture(scope="module")
def built():
    return mz.build(SRC, None, 130.0)


def test_layout_is_19_cells_with_computed_width(built):
    strip, body, m = built
    assert m["cells"] == 19 and (m["walk"]["frames"], m["cast"]["frames"], m["gather"]["frames"]) == (8, 6, 4)
    cw, ch = m["cell"]
    assert ch == 320 and strip.shape == (320, 19 * cw, 4)
    assert strip.shape[1] <= mz.MAX_STRIP_W
    assert m["idle"]["index"] == 8
    assert body.shape[0] == 320  # duruş gövdesi aynı piksel ölçeğinde (boy 320)


def test_every_cell_is_filled_and_feet_sit_on_the_bottom_edge(built):
    strip, _, m = built
    cw = m["cell"][0]
    for i in range(m["cells"]):
        a = strip[:, i * cw:(i + 1) * cw, 3]
        assert (a > 127).any(), f"hücre {i} boş"
        assert (a[-4:] > 127).any(), f"hücre {i}: ayak alt kenarda değil"
        assert (a[:, 0] == 0).all() and (a[:, -1] == 0).all(), f"hücre {i}: kenara taşıyor"


def test_gate_passes_with_feet_alignment_and_beats_torso_alignment(built):
    _, _, m = built
    q = mz.gate(m)
    assert q["pass"], q
    assert m["foot_slide"]["ok_pairs"] >= m["foot_slide"]["total_pairs"] - 2
    assert m["foot_slide"]["ok_pairs"] >= m["foot_slide_torso"]["ok_pairs"], "ayak çapası torsodan kötü olamaz"
    assert max(abs(s) for s in m["foot_shift_px"]) <= 24, "kaydırma payı aşılmadı"


def test_gate_goes_red_for_a_wrong_stride(built):
    # Aynı karelerle çevrim uzunluğu uyumsuzsa kapı kırmızı olmalı (sessiz geçmez).
    _, _, m = mz.build(SRC, None, 400.0)
    assert not mz.gate(m)["checks"]["foot_slide"]


def test_walk_cast_set_adds_cells(tmp_path):
    cast = sorted(glob.glob(str(SRC / "frames/cast/*.png")))[:5]
    _, _, m = mz.build(SRC, cast, 130.0)
    assert m["cells"] == 8 + 1 + 6 + 4 + 5
    assert m["walk_cast"]["frames"] == 5


def test_main_writes_outputs_and_exit_code(tmp_path):
    args = ["--src", str(SRC), "--out", str(tmp_path / "s.png"), "--body-out", str(tmp_path / "b.png"),
            "--manifest", str(tmp_path / "m.json"), "--quality", str(tmp_path / "q.json")]
    assert mz.main(args) == 0
    assert json.loads((tmp_path / "q.json").read_text())["pass"] is True
    assert mz.main(args + ["--stride", "400"]) == 1
    assert json.loads((tmp_path / "q.json").read_text())["pass"] is False


def test_tool_is_character_independent(tmp_path):
    """Başka kimlikli kaynak dizin (duruş `<kimlik>_idle.png`) Zyfen ile aynı çıktıyı verir; `--idle` ve `--display-height` geçerli."""
    import shutil

    other = tmp_path / "other"
    shutil.copytree(SRC / "frames", other / "frames")
    shutil.copy(SRC / "zyfen_idle.png", other / "other_idle.png")
    out = lambda n: ["--out", str(tmp_path / f"{n}_s.png"), "--body-out", str(tmp_path / f"{n}_b.png"),
                     "--manifest", str(tmp_path / f"{n}_m.json"), "--quality", str(tmp_path / f"{n}_q.json")]
    assert mz.main(["--src", str(SRC)] + out("z")) == 0
    assert mz.main(["--src", str(other)] + out("o")) == 0
    assert (tmp_path / "z_s.png").read_bytes() == (tmp_path / "o_s.png").read_bytes()
    assert json.loads((tmp_path / "z_m.json").read_text()) == json.loads((tmp_path / "o_m.json").read_text())
    (other / "other_idle.png").rename(other / "duruş.png")
    assert mz.main(["--src", str(other), "--idle", str(other / "duruş.png"), "--display-height", "200"] + out("i")) == 0
    # çizim boyu ayak kayması ölçeğini değiştirir (dünya px = hücre px x display_height/320)
    _, _, big = mz.build(other, None, 130.0, display_height=400.0, idle_path=other / "duruş.png")
    _, _, ref = mz.build(other, None, 130.0, idle_path=other / "duruş.png")
    assert big["foot_slide"]["pair_err_px"] != ref["foot_slide"]["pair_err_px"]


def test_align_feet_removes_error_on_a_synthetic_walk():
    # Gövde sabit, basan ayak dünyada sabit: torso hizalı kareler ayak kaydırır, ayak çapası düzeltir.
    n, step = 4, 20.0
    imgs = []
    for f in range(n):
        im = np.zeros((40, 80, 4), np.uint8)
        im[:30, 30:50] = 255  # gövde
        x = int(50 - step * f) % 80  # ayak her karede step kadar geriye
        im[36:, max(0, x - 3):x + 3] = 255
        imgs.append(im)
    base = [0] * n
    sh = mz.align_feet(imgs, base, step)
    assert len(sh) == n and all(abs(s) <= 24 for s in sh)


def test_committed_outputs_match_the_data_and_the_tool():
    q = json.loads((SRC / "quality.json").read_text())
    m = json.loads((SRC / "strip_manifest.json").read_text())
    z = json.loads((ROOT / "data/characters/zyfen.json").read_text())["rig"]
    assert q["pass"] is True, "kalite kapısı kırmızı: waiver olmadan gate geçmez"
    strip = Image.open(ROOT / "assets/gfx/char/zyfen_strip.png")
    cw, ch = m["cell"]
    assert strip.size == (m["cells"] * cw, ch)
    assert z["walk"]["cell"] == [cw, ch]
    assert z["walk"]["stride"] == m["stride"]
    assert z["walk"]["frames"] == m["walk"]["frames"]
    assert z["cast"]["frames"] == m["cast"]["frames"] and z["gather"]["frames"] == m["gather"]["frames"]
    body = Image.open(ROOT / "assets/gfx/char/zyfen_body.png")
    assert body.size[1] == 320


# --- v2.0.3 A: yalnız yürüme (bölünmüş rig, cast/gather yok) ---------------------------------------------------------

GS = ROOT / "art" / "source" / "gunslinger"


def test_walk_only_source_builds_walk_plus_idle_cells():
    strip, body, m = mz.build(GS, None, 110.0, idle_path=ROOT / "assets/gfx/char/gunslinger_body.png")
    assert m["cells"] == m["walk"]["frames"] + 1 and "cast" not in m and "gather" not in m
    cw, ch = m["cell"]
    assert strip.shape == (320, m["cells"] * cw, 4) and m["idle"]["index"] == m["walk"]["frames"]
    assert mz.gate(m)["pass"], "Gunslinger yürüme kalite kapısı"


def test_committed_gunslinger_quality_and_strip_match_character_json():
    q = json.loads((GS / "quality.json").read_text())
    assert q["pass"] is True and all(q["checks"].values())
    w = json.loads((ROOT / "data/characters/gunslinger.json").read_text())["rig"]["walk"]
    m = json.loads((GS / "strip_manifest.json").read_text())
    assert (w["frames"], w["stride"], w["cell"]) == (m["walk"]["frames"], m["stride"], m["cell"])
    assert Image.open(ROOT / "assets/gfx/char/gunslinger_body_walk.png").size == (m["strip_width"], 320)


def test_palm_px_without_cast_is_refused():
    with pytest.raises(SystemExit):
        mz.build(GS, None, 110.0, palm_px=(1.0, 1.0), idle_path=ROOT / "assets/gfx/char/gunslinger_body.png")
