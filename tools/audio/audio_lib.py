"""Müzik işleme çekirdeği (saf fonksiyonlar; dosya G/Ç process_audio.py'de)."""
import math

import numpy as np
import pyloudnorm as pyln
from scipy.signal import resample_poly


def resample(x: np.ndarray, sr_in: int, sr_out: int) -> np.ndarray:
    if sr_in == sr_out:
        return x
    g = math.gcd(sr_in, sr_out)
    return resample_poly(x, sr_out // g, sr_in // g, axis=0).astype(np.float32)


def loudness(x: np.ndarray, sr: int) -> float:
    return float(pyln.Meter(sr).integrated_loudness(x))


def normalize(x: np.ndarray, sr: int, target: float, ceiling_db: float):
    """Hedef LUFS'a kazanç uygular; tepe `ceiling_db` üstüne çıkarsa kazancı düşürür (limiter yok).
    Döner: (ses, ulaşılan_lufs, hedefin_altında_mı)."""
    if float(np.max(np.abs(x))) < 1e-6:
        return x.copy(), float('-inf'), False  # sessiz kayıt: kazanç uygulanmaz
    lufs = loudness(x, sr)
    gain_db = target - lufs
    peak = float(np.max(np.abs(x))) or 1e-9
    max_gain_db = ceiling_db - 20.0 * math.log10(peak)
    limited = gain_db > max_gain_db
    if limited:
        gain_db = max_gain_db
    y = (x * (10.0 ** (gain_db / 20.0))).astype(np.float32)
    return y, loudness(y, sr), limited


def _window_rms_db_diff(x: np.ndarray, q: np.ndarray, w: int) -> np.ndarray:
    """Her q için x[q-w:q] ve x[q:q+w] pencerelerinin RMS farkı (dB, mutlak)."""
    p = np.concatenate([[0.0], np.cumsum(np.mean(np.square(x.astype(np.float64)), axis=1))])
    left = np.sqrt((p[q] - p[q - w]) / w) + 1e-9
    right = np.sqrt((p[q + w] - p[q]) / w) + 1e-9
    return np.abs(20.0 * np.log10(left / right))


def loop_crossfade(x: np.ndarray, sr: int, seconds: float, search_s: float = 4.0) -> np.ndarray:
    """Sondaki `seconds` eşit-güç crossfade ile başa bindirilir ve kırpılır: son örnek -> ilk örnek sürekli.
    Kesim noktası, sondan `search_s` içinde bitişik 20 ms pencerelerin RMS farkını en aza indiren yerde seçilir
    (dikişte genlik sıçraması olmasın). `search_s <= 0`: arama yok, kesim tam `len(x) - n`."""
    n = int(sr * seconds)
    if n <= 0 or len(x) <= 2 * n + int(sr * max(search_s, 0.0)):
        return x
    w = max(1, int(sr * 0.02))
    # q = crossfade başlangıcı (çıktının sonu = x[q-1]); crossfade penceresi x[q:q+n] kuyruktur.
    hi = len(x) - n
    if search_s <= 0:
        cut = hi
    else:
        lo = max(w + 1, hi - int(sr * search_s))
        q = np.arange(lo, hi - w)
        step = np.max(np.abs(x[q] - x[q - 1]), axis=1)  # dikişteki örnek sıçraması (x[q-1] -> x[q])
        cut = int(q[np.argmin(_window_rms_db_diff(x, q, w) + 50.0 * step)])
    x = x[: cut + n]
    t = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)
    fade_in = np.sin(t * math.pi / 2.0)[:, None]
    fade_out_w = np.cos(t * math.pi / 2.0)[:, None]
    out = x[:cut].copy()
    out[:n] = x[cut : cut + n] * fade_out_w + x[:n] * fade_in
    return out.astype(np.float32)


def trim(x: np.ndarray, sr: int, start_s: float = None, end_s: float = None) -> np.ndarray:
    """Kaynağı [start_s, end_s) saniye aralığına kırpar (ikisi de isteğe bağlı); aralık geçersizse ValueError."""
    a = 0 if start_s is None else int(round(start_s * sr))
    b = len(x) if end_s is None else int(round(end_s * sr))
    if a < 0 or b > len(x) or b <= a:
        raise ValueError(f"geçersiz kırpma: start_s={start_s}, end_s={end_s}, kaynak={len(x) / sr:.3f} sn")
    return x[a:b]


def fade_out(x: np.ndarray, sr: int, seconds: float = 0.15) -> np.ndarray:
    n = min(int(sr * seconds), len(x))
    if n <= 0:
        return x.copy()
    y = x.copy()
    ramp = np.linspace(1.0, 0.0, n, dtype=np.float32)
    y[-n:] *= ramp[:, None] if y.ndim == 2 else ramp
    return y


def seam_report(x: np.ndarray, sr: int, window_s: float = 0.02) -> dict:
    """Döngü dikişi: son/ilk 20 ms RMS farkı (dB) ve |ilk - son| örnek farkı (kanal maksimumu)."""
    n = max(1, int(sr * window_s))
    head = x[:n]
    tail = x[-n:]
    rms = lambda a: float(np.sqrt(np.mean(np.square(a)))) + 1e-9
    db = abs(20.0 * math.log10(rms(head) / rms(tail)))
    jump = float(np.max(np.abs(np.atleast_1d(x[0] - x[-1]))))
    return {"rms_diff_db": db, "sample_jump": jump}
