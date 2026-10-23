"""Sentetik fixture ile müzik işleme birimleri: LUFS, örnek hızı, döngü dikişi, OGG çözülebilirliği."""
import numpy as np
import soundfile as sf

import audio_lib as lib
import check_music
import process_audio as pa

SR = 22050


def _music(seconds=14.0, sr=SR, seed=1):
    rng = np.random.default_rng(seed)
    t = np.arange(int(sr * seconds)) / sr
    env = 0.6 + 0.4 * np.sin(2 * np.pi * 0.35 * t)
    left = 0.2 * env * np.sin(2 * np.pi * 220 * t) + 0.002 * rng.standard_normal(len(t))
    right = 0.2 * env * np.sin(2 * np.pi * 330 * t) + 0.002 * rng.standard_normal(len(t))
    return np.stack([left, right], axis=1).astype(np.float32)


def test_resample_changes_rate_and_length():
    x = _music(2.0)
    y = lib.resample(x, SR, 44100)
    assert abs(len(y) - len(x) * 2) <= 2
    assert y.shape[1] == 2


def test_normalize_reaches_target_lufs():
    x = _music()
    y, lufs, limited = lib.normalize(x, SR, -18.0, -1.0)
    assert not limited
    assert abs(lufs - (-18.0)) <= 0.5
    assert float(np.max(np.abs(y))) <= 10 ** (-1.0 / 20) + 1e-4


def test_peak_ceiling_limits_gain_and_reports_it():
    x = _music()
    x[1000] = [0.95, 0.95]  # tek tepe: hedef LUFS'a ulaşmak tepeyi aşırır
    y, lufs, limited = lib.normalize(x, SR, -8.0, -1.0)
    assert limited
    assert float(np.max(np.abs(y))) <= 10 ** (-1.0 / 20) + 1e-4
    assert lufs < -8.0


def test_loop_crossfade_has_no_seam_jump():
    x = _music(20.0)
    y = lib.loop_crossfade(x, SR, 1.5)
    assert len(y) < len(x)
    r = lib.seam_report(y, SR)
    assert r["rms_diff_db"] <= 1.5
    assert r["sample_jump"] <= 0.02


def test_short_input_is_left_unchanged():
    x = _music(2.0)
    assert len(lib.loop_crossfade(x, SR, 1.5)) == len(x)


def test_one_shot_gets_fade_out():
    x = np.ones((SR, 2), dtype=np.float32) * 0.1
    y = lib.fade_out(x, SR, 0.15)
    assert abs(float(y[-1, 0])) < 1e-3
    assert float(y[0, 0]) == float(x[0, 0])


def test_write_ogg_roundtrip_is_decodable(tmp_path):
    x = _music(3.0, sr=44100)
    out = tmp_path / "t.ogg"
    pa.write_ogg(out, x, 44100)
    y, sr = sf.read(out, dtype="float32", always_2d=True)
    assert sr == 44100 and y.shape[1] == 2
    assert abs(len(y) - len(x)) < 4096


def test_process_track_end_to_end(tmp_path):
    src = tmp_path / "src.wav"
    sf.write(src, _music(20.0), SR)
    cfg = pa.load_manifest()
    r = pa.process_track({"id": "t", "src": "src.wav", "loop": True}, cfg, root=tmp_path, out_dir=tmp_path / "out")
    assert (tmp_path / "out" / "t.ogg").exists()
    assert abs(r["lufs"] - cfg["target_lufs"]) <= cfg["lufs_tolerance"]
    assert r["seam"]["rms_diff_db"] <= 1.5 and r["seam"]["sample_jump"] <= 0.02


def test_check_music_lists_missing(tmp_path):
    (tmp_path / "tools/audio").mkdir(parents=True)
    (tmp_path / "tools/audio/audio_manifest.json").write_text(
        '{"tracks": [{"id": "a"}, {"id": "b"}]}', encoding="utf-8"
    )
    (tmp_path / "assets/audio/music").mkdir(parents=True)
    (tmp_path / "assets/audio/music/a.ogg").write_bytes(b"x")
    assert check_music.missing(tmp_path) == ["b"]
