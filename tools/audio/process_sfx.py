#!/usr/bin/env python3
"""audio/sfx/<kimlik>.wav -> assets/audio/sfx/<kimlik>.ogg (mono, 44,1 kHz, kırpılmış, kimliğe göre LUFS, tepe <= -1 dBFS).

Kullanım: python tools/audio/process_sfx.py [--only <kimlik>] [--verify] [--report]
Eksik kaynak "bekleyen" olarak listelenir (hata değil; ör. dry_fire). `--verify` yazmadan çıktıları denetler;
`--report` çıktıların ölçüm tablosunu (süre, LUFS, tepe, baş/son sessizlik) Markdown olarak yazar.
Sıra: mono -> baş sessizlik/kuyruk kırp (zirveden `trim_below_peak_db` aşağısı sessizdir) -> 44,1 kHz -> isteğe bağlı
alçak geçiren -> kısa giriş + 10-30 ms çıkış sönmesi -> hedef LUFS (tepe sınırı aşılırsa kazanç düşer, limiter yok).
Vorbis kodlaması tepeyi aşırtabilir: çözülmüş dosyada tepe > tavan ise tavan düşürülüp yeniden kodlanır.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).parent))
import audio_lib as lib  # noqa: E402
import process_audio as pa  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("sfx_manifest.json")
SRC_DIR = "audio/sfx"
OUT_DIR = ROOT / "assets" / "audio" / "sfx"
SILENCE_DB = -45.0  # ölçüm raporunda "sessizlik" eşiği (mutlak, işlenmiş çıktı)
FADE_MIN_S = 0.010
FADE_MAX_S = 0.030
MAX_RETRIES = 4


def load_manifest(path: Path = MANIFEST) -> dict:
    return pa.load_manifest(path)


def source_path(sound: dict, root: Path = ROOT) -> Path:
    return root / sound.get("src", f"{SRC_DIR}/{sound['id']}.wav")


def render(sound: dict, cfg: dict, x: np.ndarray, sr: int, ceiling_db: float) -> tuple:
    """Kaynak (n, k) -> işlenmiş (n, 1) float. Döner: (ses, ulaşılan_lufs, tepe_sınırlı_mı)."""
    x = lib.to_mono(x)
    thr = lib.peak_db(x) + cfg["trim_below_peak_db"]
    x = lib.trim_silence(x, sr, thr, cfg["preroll_s"], cfg["tail_s"], sound.get("max_s"))
    x = lib.resample(x, sr, cfg["sample_rate"])
    sr = cfg["sample_rate"]
    if "lowpass_hz" in sound:
        x = lib.lowpass(x, sr, sound["lowpass_hz"])
    fade = min(max(float(sound.get("fade_out_s", cfg["fade_out_s"])), FADE_MIN_S), FADE_MAX_S)
    x = lib.fade_in(x, sr, cfg["fade_in_s"])
    x = lib.fade_out(x, sr, fade)
    return lib.normalize(x, sr, sound["target_lufs"], ceiling_db)


def process_sound(sound: dict, cfg: dict, root: Path = ROOT, out_dir: Path = OUT_DIR) -> dict:
    x, sr = sf.read(source_path(sound, root), dtype="float32", always_2d=True)
    sr_out = cfg["sample_rate"]
    ceiling = cfg["peak_ceiling_db"]
    out = out_dir / f"{sound['id']}.ogg"
    out_dir.mkdir(parents=True, exist_ok=True)
    for _ in range(MAX_RETRIES):
        y, lufs, limited = render(sound, cfg, x, sr, ceiling)
        pa.write_ogg(out, y, sr_out)
        decoded, _ = sf.read(out, dtype="float32", always_2d=True)
        over = lib.peak_db(decoded) - cfg["peak_ceiling_db"]
        if over <= 0.0:
            break
        ceiling -= over + 0.05  # kodlama taşması: bir sonraki turda tavan o kadar düşer
    return {"id": sound["id"], "lufs": lufs, "limited": limited, "seconds": len(y) / sr_out, "out": out}


def measure(path: Path) -> dict:
    y, sr = sf.read(path, dtype="float32", always_2d=True)
    head, tail = lib.silence_edges(y, sr, SILENCE_DB)
    return {
        "sr": sr,
        "channels": y.shape[1],
        "seconds": len(y) / sr,
        "lufs": lib.loudness(y, sr),
        "peak_db": lib.peak_db(y),
        "head_s": head,
        "tail_s": tail,
    }


def check(sound: dict, m: dict, cfg: dict) -> list:
    """Ölçümün manifeste uymayan yanlarını metin listesi olarak döndürür (boş: tamam)."""
    bad = []
    if m["sr"] != cfg["sample_rate"] or m["channels"] != 1:
        bad.append(f"biçim {m['sr']} Hz/{m['channels']} kanal")
    if m["seconds"] > sound["max_s"] + 0.005:
        bad.append(f"süre {m['seconds']:.3f} > {sound['max_s']}")
    if m["peak_db"] > cfg["peak_ceiling_db"] + 1e-3:
        bad.append(f"tepe {m['peak_db']:.2f} dBFS")
    diff = m["lufs"] - sound["target_lufs"]
    # hedefin altı yalnız tepe sınırı yüzünden kabul (tepe tavana yakın); hedefin üstü her zaman hata
    peak_bound = m["peak_db"] > cfg["peak_ceiling_db"] - 0.3
    if diff > cfg["lufs_tolerance"] or (diff < -cfg["lufs_tolerance"] and not peak_bound):
        bad.append(f"LUFS {m['lufs']:.2f} (hedef {sound['target_lufs']})")
    if m["head_s"] > 0.015:
        bad.append(f"baş sessizlik {m['head_s'] * 1000:.0f} ms")
    return bad


def report_table(rows: list) -> str:
    out = [
        "| Kimlik | Süre (sn) | LUFS | Hedef | Tepe (dBFS) | Baş sessizlik (ms) | Son sessizlik (ms) |",
        "|---|---|---|---|---|---|---|",
    ]
    for s, m in rows:
        out.append(
            f"| {s['id']} | {m['seconds']:.3f} | {m['lufs']:.1f} | {s['target_lufs']:.0f} | {m['peak_db']:.2f} "
            f"| {m['head_s'] * 1000:.0f} | {m['tail_s'] * 1000:.0f} |"
        )
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    cfg = load_manifest()
    pending, rows, bad = [], [], 0
    for s in cfg["sounds"]:
        if a.only and s["id"] != a.only:
            continue
        if not source_path(s).exists():
            pending.append(s["id"])
            continue
        out = OUT_DIR / f"{s['id']}.ogg"
        if a.verify or a.report:
            if not out.exists():
                print(f"EKSİK çıktı: {out}")
                bad += 1
                continue
            m = measure(out)
            rows.append((s, m))
            problems = check(s, m, cfg)
            if a.verify:
                print(f"{s['id']}: {m['lufs']:.2f} LUFS {'tamam' if not problems else 'HATA: ' + '; '.join(problems)}")
                bad += 1 if problems else 0
            continue
        r = process_sound(s, cfg)
        note = " (hedefin altında kaldı: tepe sınırı)" if r["limited"] else ""
        print(f"{r['id']}: {r['seconds']:.3f} sn, {r['lufs']:.2f} LUFS{note}")
    if a.report and rows:
        print(report_table(rows))
    if pending:
        print("bekleyen (kaynak yok):", ", ".join(pending))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
