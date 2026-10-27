"""Ölçüm satırı yardımcıları (v2.1 U1a): mid_run.gd çıktısının normalleştirilmesi, eşleştirme anahtarı, mod bazlı sabitler.

Eşleştirme anahtarı `(mod, zorluk, karakter, politika, tohum)`; v2.0.x satırlarında mod/zorluk yoktur ve legacy Zor
(normal/hard) sayılır. Sabitler mod bazlıdır: `cap` = Lord'a kadar süre (survival tavanı), `mid` = orta oyun başlangıcı.
"""
from __future__ import annotations

import glob
import json
from pathlib import Path

LEGACY_CELL = ("normal", "hard")
# Hızlı: sim süresi 0,5 ölçeğinde (Lord 600. sn). Sonsuz: ilk Lord 1200. sn; sonrası ayrı alanlarla (post_lord_secs) ölçülür.
MODE_CONSTS = {"normal": {"cap": 1200.0, "mid": 600.0}, "quick": {"cap": 600.0, "mid": 300.0}, "endless": {"cap": 1200.0, "mid": 600.0}}


def consts(mode: str) -> dict:
    return MODE_CONSTS.get(mode, MODE_CONSTS["normal"])


def normalize(r: dict) -> dict:
    r.setdefault("mode", LEGACY_CELL[0])
    r.setdefault("diff", LEGACY_CELL[1])
    return r


def row_key(r: dict) -> tuple:
    return (r["mode"], r["diff"], r["character"], r["policy"], int(r["seed"]))


def cell_of(r: dict) -> tuple:
    return (r.get("mode", LEGACY_CELL[0]), r.get("diff", LEGACY_CELL[1]))


def parse_cell(text: str) -> tuple:
    mode, _, diff = text.partition(":")
    if not mode or not diff:
        raise ValueError(f"hücre 'mod:zorluk' biçiminde olmalı: {text!r}")
    return (mode, diff)


def read_jsonl_files(path: str) -> list[dict]:
    p = Path(path)
    files = sorted(glob.glob(str(p / "*.jsonl"))) if p.is_dir() else [str(p)]
    if not files:
        raise FileNotFoundError(f"girdi yok: {path}")
    rows: list[dict] = []
    for f in files:
        with open(f, encoding="utf-8") as fh:
            rows += [normalize(json.loads(line)) for line in fh if line.strip()]
    return rows
