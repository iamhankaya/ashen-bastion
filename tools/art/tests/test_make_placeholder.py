import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import make_placeholder as mp

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "art" / "make_placeholder.py"


def synthetic(mode="RGBA", size=(64, 48)):
    w, h = size
    x = np.linspace(0, 255, w, dtype=np.uint8)[None, :].repeat(h, axis=0)
    y = np.linspace(0, 255, h, dtype=np.uint8)[:, None].repeat(w, axis=1)
    rgb = np.stack([x, y, (255 - x) // 2 + 40], axis=-1).astype(np.uint8)
    img = Image.fromarray(rgb, "RGB")
    if mode == "RGBA":
        a = np.where((np.arange(w)[None, :] + np.arange(h)[:, None]) % 7 == 0, 0, 255).astype(np.uint8)
        img.putalpha(Image.fromarray(a, "L"))
    return img


def hsv_means(img):
    hsv = np.asarray(img.convert("RGB").convert("HSV"), dtype=np.float32)
    return hsv[..., 1].mean(), hsv[..., 2].mean()


def test_size_mode_and_alpha_are_preserved():
    src = synthetic("RGBA")
    out = mp.shift(src)
    assert out.size == src.size and out.mode == "RGBA"
    assert np.array_equal(np.asarray(out.getchannel("A")), np.asarray(src.getchannel("A")))


def test_rgb_source_stays_rgb():
    out = mp.shift(synthetic("RGB"))
    assert out.mode == "RGB"


def test_saturation_and_brightness_drop():
    src = synthetic("RGB")
    out = mp.shift(src)
    s0, v0 = hsv_means(src)
    s1, v1 = hsv_means(out)
    assert s1 < s0 * 0.9
    assert v1 < v0
    assert v1 > v0 * 0.6


def test_identity_parameters_keep_pixels_close():
    src = synthetic("RGB")
    out = mp.shift(src, sepia=0.0, hue_deg=0.0, sat=1.0, val=1.0)
    diff = np.abs(np.asarray(out, dtype=np.int16) - np.asarray(src, dtype=np.int16))
    assert diff.max() <= 8  # 8-bit HSV gidiş-dönüş niceleme payı


def test_deterministic():
    src = synthetic("RGBA")
    assert np.array_equal(np.asarray(mp.shift(src)), np.asarray(mp.shift(src)))


def test_cli_writes_destination(tmp_path):
    src = tmp_path / "in.png"
    dst = tmp_path / "sub" / "out.png"
    synthetic("RGBA").save(src)
    r = subprocess.run([sys.executable, str(SCRIPT), str(src), str(dst)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert Image.open(dst).size == (64, 48)


def test_cli_without_paths_fails(tmp_path):
    r = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True)
    assert r.returncode != 0


def test_zyfen_placeholder_targets_are_retired_so_real_art_is_never_overwritten():
    # v2.0.2 U2: zyfen_* gerçek varlık; --zyfen hiçbir dosyaya yazmaz.
    assert mp.ZYFEN == []
