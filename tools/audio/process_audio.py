#!/usr/bin/env python3
"""audio/muzik/* (wav/mp3) -> assets/audio/music/<id>.ogg (44,1 kHz, -18 LUFS, döngü crossfade).

Kullanım: python tools/audio/process_audio.py [--only <id>] [--verify]
Eksik kaynak "bekleyen" olarak listelenir (hata değil). `--verify` yazmadan çıktıları denetler.
Manifest parçasında isteğe bağlı `start_s`/`end_s` (saniye) kaynağı kırpar. Döngülü parçada kırpma varsa kesim aranmaz:
döngü uzunluğu ≈ end_s - start_s - loop_crossfade_s (en çok 40 ms kısa; tam ölçü katına oturtulmuş seçilir).
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).parent))
import audio_lib as lib  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("audio_manifest.json")
OUT_DIR = ROOT / "assets" / "audio" / "music"
LOOP_TRIM_SEARCH_S = 0.04


def load_manifest(path: Path = MANIFEST) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_ogg(path: Path, y: np.ndarray, sr: int) -> None:
    """Blok blok OGG Vorbis yazar (tek çağrıda büyük diziyi yazmak libsndfile'ı çökertebiliyor)."""
    with sf.SoundFile(path, "w", samplerate=sr, channels=y.shape[1], format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(y), sr):
            f.write(y[i : i + sr])


def process_track(track: dict, cfg: dict, root: Path = ROOT, out_dir: Path = OUT_DIR) -> dict:
    src = root / track["src"]
    x, sr = sf.read(src, dtype="float32", always_2d=True)
    trimmed = "start_s" in track or "end_s" in track
    x = lib.trim(x, sr, track.get("start_s"), track.get("end_s"))
    x = lib.resample(x, sr, cfg["sample_rate"])
    sr = cfg["sample_rate"]
    if track["loop"]:
        # Elle seçilmiş (kırpılmış) döngüde kesim yalnız son LOOP_TRIM_SEARCH_S içinde ince ayarlanır (ritim kaymaz):
        # döngü uzunluğu ≈ end_s - start_s - crossfade (en çok LOOP_TRIM_SEARCH_S kısa).
        x = lib.loop_crossfade(x, sr, cfg["loop_crossfade_s"], search_s=LOOP_TRIM_SEARCH_S if trimmed else 4.0)
    y, lufs, limited = lib.normalize(x, sr, cfg["target_lufs"], cfg["peak_ceiling_db"])
    if not track["loop"]:
        y = lib.fade_out(y, sr)
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{track['id']}.ogg"
    write_ogg(out, y, sr)
    seam = None
    if track["loop"]:  # kodlama sonrası çözülmüş dosyadan ölç: Vorbis uç örnekleri değiştirebilir
        decoded, _ = sf.read(out, dtype="float32", always_2d=True)
        seam = lib.seam_report(decoded, sr)
    return {"id": track["id"], "lufs": lufs, "limited": limited, "seconds": len(y) / sr, "seam": seam, "out": out}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    cfg = load_manifest()
    pending = []
    bad = 0
    for t in cfg["tracks"]:
        if a.only and t["id"] != a.only:
            continue
        if not (ROOT / t["src"]).exists():
            pending.append(t["id"])
            continue
        if a.verify:
            out = OUT_DIR / f"{t['id']}.ogg"
            if not out.exists():
                print(f"EKSİK çıktı: {out}")
                bad += 1
                continue
            y, sr = sf.read(out, dtype="float32", always_2d=True)
            lufs = lib.loudness(y, sr)
            ok = abs(lufs - cfg["target_lufs"]) <= cfg["lufs_tolerance"] or t["id"] in ("boss-uyari",)
            print(f"{t['id']}: {lufs:.2f} LUFS {'tamam' if ok else 'HEDEF DIŞI'}")
            bad += 0 if ok else 1
            continue
        r = process_track(t, cfg)
        note = " (hedefin altında kaldı: tepe sınırı)" if r["limited"] else ""
        print(f"{r['id']}: {r['seconds']:.1f} sn, {r['lufs']:.2f} LUFS{note}, dikiş={r['seam']}")
    if pending:
        print("bekleyen (kaynak yok):", ", ".join(pending))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
