"""Gerçek çıktılar (assets/audio/music): 7 parçanın tamamı var, -18 LUFS ±0,5, döngü dikişi temiz."""
import json
import sys
from pathlib import Path

import soundfile as sf

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools/audio"))
import audio_lib as lib  # noqa: E402
import check_music  # noqa: E402

CFG = json.loads((ROOT / "tools/audio/audio_manifest.json").read_text(encoding="utf-8"))


def test_all_seven_tracks_exist():
    assert check_music.missing() == []


def test_loudness_and_seams():
    for t in CFG["tracks"]:
        y, sr = sf.read(ROOT / "assets/audio/music" / f"{t['id']}.ogg", dtype="float32", always_2d=True)
        assert sr == CFG["sample_rate"], t["id"]
        assert abs(lib.loudness(y, sr) - CFG["target_lufs"]) <= CFG["lufs_tolerance"], t["id"]
        if t["loop"]:
            r = lib.seam_report(y, sr)
            assert r["rms_diff_db"] <= 1.5, (t["id"], r)
            assert r["sample_jump"] <= 0.02, (t["id"], r)
