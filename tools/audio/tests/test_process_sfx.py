"""Ses efekti işleme: kırpma, mono, sönme, LUFS/tepe, kodlama sonrası tepe tavanı, bekleyen kaynak."""
import numpy as np
import soundfile as sf

import audio_lib as lib
import process_sfx as ps

SR = 48000


def _burst(lead_s=0.5, body_s=0.2, tail_s=0.3, amp=0.5, sr=SR, stereo=True):
    """Baş sessizlik + sönümlü 800 Hz patlama + sessiz kuyruk (stereo)."""
    n_body = int(sr * body_s)
    t = np.arange(n_body) / sr
    body = amp * np.sin(2 * np.pi * 800 * t) * np.exp(-t * 12.0)
    x = np.concatenate([np.zeros(int(sr * lead_s)), body, np.zeros(int(sr * tail_s))]).astype(np.float32)
    return np.stack([x, x * 0.8], axis=1) if stereo else x[:, None]


def _cfg():
    return ps.load_manifest()


def test_to_mono_averages_channels():
    x = np.stack([np.ones(10), np.zeros(10)], axis=1).astype(np.float32)
    y = lib.to_mono(x)
    assert y.shape == (10, 1) and np.allclose(y, 0.5)


def test_trim_silence_drops_leading_silence_and_tail():
    x = lib.to_mono(_burst(lead_s=0.5, body_s=0.2, tail_s=0.3))
    thr = lib.peak_db(x) - 36.0
    y = lib.trim_silence(x, SR, thr, preroll_s=0.005, tail_s=0.03)
    head, tail = lib.silence_edges(y, SR, thr)
    assert head <= 0.006
    assert tail <= 0.031
    assert len(y) / SR < 0.3


def test_trim_silence_caps_duration():
    x = lib.to_mono(_burst(lead_s=0.1, body_s=1.0, tail_s=0.0))
    y = lib.trim_silence(x, SR, -50.0, 0.0, 0.0, max_s=0.4)
    assert abs(len(y) / SR - 0.4) < 1e-3


def test_trim_silence_rejects_silent_source():
    try:
        lib.trim_silence(np.zeros((SR, 1), dtype=np.float32), SR, -50.0, 0.0, 0.0)
    except ValueError:
        return
    raise AssertionError("sessiz kaynak reddedilmeli")


def test_fades_start_and_end_at_zero():
    x = np.ones((SR // 2, 1), dtype=np.float32) * 0.5
    y = lib.fade_out(lib.fade_in(x, SR, 0.002), SR, 0.02)
    assert abs(float(y[0, 0])) < 1e-6 and abs(float(y[-1, 0])) < 1e-3
    assert float(y[SR // 4, 0]) == 0.5


def test_lowpass_attenuates_highs_keeps_lows():
    t = np.arange(SR) / SR
    lo = np.sin(2 * np.pi * 500 * t)[:, None].astype(np.float32)
    hi = np.sin(2 * np.pi * 15000 * t)[:, None].astype(np.float32)
    assert np.std(lib.lowpass(lo, SR, 6000)) > 0.95 * np.std(lo)
    assert np.std(lib.lowpass(hi, SR, 6000)) < 0.1 * np.std(hi)


def test_short_sound_loudness_is_measurable():
    x = lib.to_mono(_burst(lead_s=0.0, body_s=0.1, tail_s=0.0))
    assert np.isfinite(lib.loudness(x, SR))


def test_process_sound_end_to_end(tmp_path):
    cfg = _cfg()
    sf.write(tmp_path / "t.wav", _burst(), SR)
    s = {"id": "t", "src": "t.wav", "target_lufs": -24.0, "max_s": 0.35}
    r = ps.process_sound(s, cfg, root=tmp_path, out_dir=tmp_path / "out")
    m = ps.measure(tmp_path / "out" / "t.ogg")
    assert m["sr"] == 44100 and m["channels"] == 1
    assert m["seconds"] <= 0.35 + 0.005
    assert m["head_s"] <= 0.015
    assert m["peak_db"] <= cfg["peak_ceiling_db"] + 1e-3
    assert abs(m["lufs"] - (-24.0)) <= cfg["lufs_tolerance"]
    assert ps.check(s, m, cfg) == []
    assert not r["limited"]


def test_peaky_source_is_limited_and_stays_under_ceiling(tmp_path):
    cfg = _cfg()
    x = _burst(amp=0.9)
    sf.write(tmp_path / "t.wav", x, SR)
    s = {"id": "t", "src": "t.wav", "target_lufs": -8.0, "max_s": 0.35}
    r = ps.process_sound(s, cfg, root=tmp_path, out_dir=tmp_path / "out")
    m = ps.measure(tmp_path / "out" / "t.ogg")
    assert r["limited"]
    assert m["peak_db"] <= cfg["peak_ceiling_db"] + 1e-3  # Vorbis taşması dahil çözülmüş dosyada ölçülür


def test_check_flags_too_long_and_too_loud():
    cfg = _cfg()
    s = {"id": "t", "target_lufs": -24.0, "max_s": 0.3}
    m = {"sr": 44100, "channels": 1, "seconds": 0.5, "lufs": -20.0, "peak_db": -3.0, "head_s": 0.0, "tail_s": 0.0}
    bad = ps.check(s, m, cfg)
    assert any("süre" in b for b in bad) and any("LUFS" in b for b in bad)


def test_manifest_is_consistent():
    cfg = _cfg()
    ids = [s["id"] for s in cfg["sounds"]]
    assert len(ids) == len(set(ids))
    for s in cfg["sounds"]:
        assert s["max_s"] > 0 and -40 < s["target_lufs"] < -10, s["id"]
        assert ps.FADE_MIN_S <= cfg["fade_out_s"] <= ps.FADE_MAX_S
    for need in ("shot_right", "hit_1", "enemy_die_2", "reload_spin_2", "evolution_6", "level_up_normal", "level_up_evolution"):
        assert need in ids
