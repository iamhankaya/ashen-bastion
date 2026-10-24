"""make_zyfen_strip: sentetik RGBA klipler (şeffaf zemin; gövde + basan ayak bloğu). body_h = 300 (cell_height 320 / 1,065)."""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

import make_zyfen_strip as mz

TOOL = Path(mz.__file__)
BODY_H = 300
STRIDE, DISPLAY = 150.0, 200.0
STEP_PX = (STRIDE / 8) / (DISPLAY / BODY_H)  # 8 kare: kare başına geriye giden ayak (şerit px)


def write_frame(path, h=BODY_H, torso_w=12, foot_off=0, arm=0, margin=(30, 20)):
    """Şeffaf tuval: gövde (üst), basan ayak bloğu (alt 10 satır, merkeze göre foot_off) ve isteğe bağlı yana uzanan kol bloğu.
    Ayak bloğu gövdeden kopuk ama alanı keep_main_parts eşiğinin (%8) üstünde kalacak kadar büyük (torso ince)."""
    mx, my = margin
    half = 60 + max(abs(foot_off), arm) + 20
    w = 2 * half
    img = np.zeros((h + 2 * my, w + 2 * mx, 4), np.uint8)
    cx = mx + half
    top = my
    col = (150, 60, 90, 255)
    img[top:top + h - 60, cx - torso_w // 2:cx + torso_w // 2] = col
    img[top + h - 10:top + h, cx + foot_off - 20:cx + foot_off + 20] = (60, 40, 20, 255)
    if arm:
        img[top + 40:top + 60, cx:cx + arm] = (200, 200, 120, 255)  # üst yarıda: merkez kaymasın diye ince
    Image.fromarray(img, "RGBA").save(path)


def walk_clip(tmp_path, n=8, name="walk", static=False, step=STEP_PX):
    paths = []
    for i in range(n):
        p = tmp_path / f"{name}_{i}.png"
        write_frame(p, foot_off=0 if static else int(round(100 - step * i)))
        paths.append(str(p))
    return paths


def clip(tmp_path, name, n, **kw):
    paths = []
    for i in range(n):
        p = tmp_path / f"{name}_{i}.png"
        write_frame(p, **kw)
        paths.append(str(p))
    return paths


@pytest.fixture
def stand(tmp_path):
    p = tmp_path / "stand.png"
    write_frame(p)
    return str(p)


def build(stand, clips, **kw):
    return mz.build(stand, clips, stride=STRIDE, display_height=DISPLAY, **kw)


def full_clips(tmp_path, **cast_kw):
    return {
        "walk": walk_clip(tmp_path),
        "cast": clip(tmp_path, "cast", 6, **cast_kw),
        "gather": clip(tmp_path, "gather", 4),
    }


def test_layout_19_cells_and_bases(tmp_path, stand):
    r = build(stand, full_clips(tmp_path))
    m = r["manifest"]
    assert m["cells"] == 19 and m["frames"] == {"walk": 8, "cast": 6, "gather": 4, "walk_cast": 0}
    assert (m["idle_index"], m["cast_base"], m["gather_base"], m["walk_cast_base"]) == (8, 9, 15, -1)
    cw, ch = m["cell"]
    assert ch == 320 and r["strip"].shape == (320, cw * 19, 4)
    assert m["body_scale"] == 1.0 and m["clip_scale"]["walk"] == 1.0
    assert m["body_px"][1] == BODY_H
    assert m["quality"]["pass"], m["quality"]["failures"]
    assert m["quality"]["strip_width"] == cw * 19 <= 8192
    assert r["body"].shape[0] == BODY_H  # alfa sınırına kırpılmış, aynı ölçek


def test_cell_width_is_computed_from_input_not_constant(tmp_path, stand):
    narrow = build(stand, full_clips(tmp_path))["manifest"]["cell"][0]
    sub = tmp_path / "wide"
    sub.mkdir()
    wide_clips = {"walk": walk_clip(tmp_path), "cast": clip(sub, "cast", 6, arm=230), "gather": clip(tmp_path, "gather", 4)}
    wide = build(stand, wide_clips)["manifest"]["cell"][0]
    assert wide > narrow + 100, (narrow, wide)
    # hücre = en geniş hizalı yarı genişlik*2 + 2*PAD, çift sayı
    assert wide % 2 == 0 and narrow % 2 == 0
    # tüm kareler hücreye sığar: şeritte hücre sınırını aşan opak piksel yok
    r = build(stand, wide_clips)
    cw = r["manifest"]["cell"][0]
    a = r["strip"][..., 3] > 0
    for i in range(r["manifest"]["cells"]):
        assert a[:, i * cw:i * cw + 1].sum() == 0 and a[:, (i + 1) * cw - 1:(i + 1) * cw].sum() == 0, f"hücre {i} kenara değiyor"


def test_static_feet_fail_foot_slide_gate(tmp_path, stand):
    clips = full_clips(tmp_path)
    clips["walk"] = walk_clip(tmp_path, static=True)
    q = build(stand, clips)["manifest"]["quality"]
    assert not q["pass"] and not q["foot_slide"]["pass"]
    assert any("foot_slide" in f for f in q["failures"])


def test_two_bad_pairs_are_tolerated_three_are_not(tmp_path, stand):
    base = walk_clip(tmp_path)
    q = build(stand, {"walk": base, "cast": [], "gather": []})["manifest"]["quality"]["foot_slide"]
    assert q["ok_pairs"] >= q["total_pairs"] - 2 and q["pass"]  # döngü kapanışı çifti doğal olarak bozuk
    broken = []
    for i in range(8):
        p = tmp_path / f"b_{i}.png"
        write_frame(p, foot_off=100 if i in (1, 2, 3, 4) else int(round(100 - STEP_PX * i)))
        broken.append(str(p))
    q2 = build(stand, {"walk": broken})["manifest"]["quality"]["foot_slide"]
    assert not q2["pass"]


def test_height_deviation_over_six_percent_fails(tmp_path, stand):
    clips = full_clips(tmp_path)
    p = Path(clips["cast"][2])
    write_frame(p, h=BODY_H + 55)  # ortanca 300, bu kare %18 uzun
    q = build(stand, clips)["manifest"]["quality"]
    assert not q["pass"] and q["max_height_dev_pct"] > 6.0
    assert any("yükseklik" in f for f in q["failures"])
    write_frame(p, h=BODY_H + 12)  # %4: geçer
    assert build(stand, clips)["manifest"]["quality"]["max_height_dev_pct"] <= 6.0


def test_strip_width_over_8192_fails(tmp_path, stand):
    sub = tmp_path / "huge"
    sub.mkdir()
    clips = full_clips(tmp_path)
    clips["cast"] = clip(sub, "cast", 6, arm=420)
    q = build(stand, clips)["manifest"]["quality"]
    assert q["strip_width"] > 8192 and not q["strip_width_ok"] and not q["pass"]


def test_clip_scale_normalizes_each_clip_to_body_height(tmp_path, stand):
    clips = full_clips(tmp_path)
    sub = tmp_path / "tall"
    sub.mkdir()
    clips["cast"] = clip(sub, "cast", 6, h=400)
    m = build(stand, clips)["manifest"]
    assert m["clip_scale"]["cast"] == pytest.approx(0.75, abs=0.01)
    assert m["quality"]["max_height_dev_pct"] <= 6.0


def test_walk_zero_frames_still_builds_cast_and_gather(tmp_path, stand):
    clips = {"walk": [], "cast": clip(tmp_path, "cast", 6), "gather": clip(tmp_path, "gather", 4)}
    m = build(stand, clips)["manifest"]
    assert m["cells"] == 0 + 1 + 6 + 4 and (m["idle_index"], m["cast_base"], m["gather_base"]) == (0, 1, 7)
    assert "foot_slide" not in m["quality"] and m["quality"]["pass"]


def test_walk_cast_set_is_appended_and_measured(tmp_path, stand):
    clips = full_clips(tmp_path)
    clips["walk_cast"] = walk_clip(tmp_path, n=3, name="wc")
    m = build(stand, clips)["manifest"]
    assert m["cells"] == 8 + 1 + 6 + 4 + 3 and m["walk_cast_base"] == 19
    assert m["quality"]["walk_cast_foot_slide"]["total_pairs"] == 2
    assert m["quality"]["pass"], m["quality"]["failures"]


def test_walk_cast_static_feet_fail(tmp_path, stand):
    clips = full_clips(tmp_path)
    clips["walk_cast"] = walk_clip(tmp_path, n=4, name="wc", static=True)
    q = build(stand, clips)["manifest"]["quality"]
    assert not q["pass"] and any("walk_cast" in f for f in q["failures"])


def test_palm_is_in_cast_point_space(tmp_path, stand):
    """Avuç = cast karesinde işaretli piksel; çıktı gövde kutusu merkezine göre, display_height kesri."""
    clips = full_clips(tmp_path)
    # Kaynak kare: write_frame boyutu; torso merkezi x = 30+half. Avucu torso merkezinin 60 px sağında, kare üstünden 80 px aşağıda ver.
    p = Path(clips["cast"][3])
    img = np.asarray(Image.open(p).convert("RGBA"))
    ys, xs = np.nonzero(img[..., 3] > 0)
    x0, y0 = int(xs.min()), int(ys.min())
    torso_cx = (x0 + int(xs.max()) + 1) / 2.0 if False else None
    # torso merkezi: üst satırdaki opak piksellerin ortası
    top_row = np.nonzero(img[y0, :, 3] > 0)[0]
    cx = (top_row.min() + top_row.max() + 1) / 2.0
    palm = (cx + 60.0, y0 + 80.0)
    r = build(stand, clips, fire_frame=3, palm_px=palm)
    fx, fy = r["manifest"]["palm"]["point"]
    # duruş alfa kutusu merkezi: x = torso merkezi (ayak bloğu simetrik), y = yüksekliğin yarısı
    assert fx == pytest.approx(60.0 / BODY_H, abs=0.01)
    assert fy == pytest.approx((80.0 - BODY_H / 2.0) / BODY_H, abs=0.01)
    assert r["manifest"]["palm"]["fire_frame"] == 3
    left = build(stand, clips, fire_frame=3, palm_px=palm, native_facing="left")
    assert left["manifest"]["palm"]["point"][0] == pytest.approx(-fx, abs=1e-6)


def test_cli_roundtrip_and_exit_codes(tmp_path, stand):
    clips = full_clips(tmp_path)
    for i in range(10, 12):  # doğal sıra: cast_10 cast_2'den sonra
        write_frame(tmp_path / f"extra_{i}.png")
    out = tmp_path / "out"
    cmd = [sys.executable, str(TOOL), "--stand", stand, "--walk", str(tmp_path / "walk_*.png"), "--cast", str(tmp_path / "cast_*.png"),
           "--gather", str(tmp_path / "gather_*.png"), "--strip", str(out / "s.png"), "--body", str(out / "b.png"),
           "--manifest", str(out / "m.json"), "--quality", str(out / "q.json"), "--preview", "--preview-dir", str(out / "pv")]
    r = subprocess.run(cmd, capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    m = json.loads((out / "m.json").read_text())
    q = json.loads((out / "q.json").read_text())
    assert q["pass"] is True and m["cells"] == 19
    assert Image.open(out / "s.png").size == (m["cell"][0] * 19, 320)
    assert (out / "pv" / "s_preview.png").is_file()
    # kapı kalırsa çıkış 1, --no-gate ile 0
    bad = [c if c != str(tmp_path / "walk_*.png") else str(tmp_path / "stat_*.png") for c in cmd]
    walk_clip(tmp_path, name="stat", static=True)
    assert subprocess.run(bad, capture_output=True, text=True).returncode == 1
    assert subprocess.run(bad + ["--no-gate"], capture_output=True, text=True).returncode == 0
    # girdi hatası: eşleşmeyen glob / eksik duruş
    nomatch = [c if c != str(tmp_path / "walk_*.png") else str(tmp_path / "yok_*.png") for c in cmd]
    assert subprocess.run(nomatch, capture_output=True, text=True).returncode == 2
    nostand = [c if c != stand else str(tmp_path / "yok.png") for c in cmd]
    assert subprocess.run(nostand, capture_output=True, text=True).returncode == 2


def test_natural_sort_order():
    assert sorted(["f_10.png", "f_2.png", "f_1.png"], key=mz.natural_key) == ["f_1.png", "f_2.png", "f_10.png"]


def test_empty_frame_is_input_error(tmp_path, stand):
    p = tmp_path / "empty.png"
    Image.fromarray(np.zeros((50, 50, 4), np.uint8), "RGBA").save(p)
    with pytest.raises(ValueError, match="boş kare"):
        build(stand, {"walk": [], "cast": [str(p)] * 2, "gather": []})
