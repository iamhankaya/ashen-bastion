#!/usr/bin/env python3
"""test/fixtures/profile_bad_<kod>/run_profiles.json üretir (çıktı commit'lidir; data/run_profiles.json şeması değişince yeniden üretilir).

Her dizin data/run_profiles.json'un TEK kusurlu kopyasıdır; <kod> RunProfiles.ERROR_CODES'tan biridir ve doğrulayıcı çıktısında
"[kod]" olarak aranır. (Ad `data_bad_*` DEĞİL: test_game_data.gd o önekli her dizini GameData hata kodu sayar.)
`profile_file_missing` dizininde dosya yoktur (yalnız .gitkeep).
"""
import copy
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test" / "fixtures"
GOOD = json.loads((ROOT / "data" / "run_profiles.json").read_text(encoding="utf-8"))


def mutate(fn):
    d = copy.deepcopy(GOOD)
    fn(d)
    return d


CASES = {
    "profile_range": lambda d: d["modes"]["quick"].update(time_scale=0.2),
    "profile_type": lambda d: d["modes"]["quick"].update(time_scale="0.5"),
    "profile_missing_key": lambda d: d["difficulties"]["easy"].pop("xp"),
    "profile_unknown_key": lambda d: d["modes"]["quick"].update(bogus=1),
    "profile_default": lambda d: d["default"].update(mode="turbo"),
    "profile_cross": lambda d: d["modes"]["endless"].pop("enrage_after_sec"),
}


def main() -> None:
    for code, fn in CASES.items():
        target = OUT / f"profile_bad_{code.removeprefix('profile_')}"
        shutil.rmtree(target, ignore_errors=True)
        target.mkdir(parents=True)
        (target / "run_profiles.json").write_text(json.dumps(mutate(fn), indent=1) + "\n", encoding="utf-8")
    missing = OUT / "profile_bad_file_missing"
    shutil.rmtree(missing, ignore_errors=True)
    missing.mkdir(parents=True)
    (missing / ".gitkeep").write_text("", encoding="utf-8")


if __name__ == "__main__":
    main()
