"""Gerçek çıktılar (assets/audio/sfx): kaynağı olan her ses var ve manifest sınırlarında (süre, LUFS, tepe, baş sessizlik)."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools/audio"))
import process_sfx as ps  # noqa: E402

CFG = ps.load_manifest()


def test_every_available_source_has_a_valid_output():
    checked = 0
    for s in CFG["sounds"]:
        if not ps.source_path(s).exists():
            continue  # bekleyen (ör. dry_fire)
        out = ps.OUT_DIR / f"{s['id']}.ogg"
        assert out.exists(), s["id"]
        assert ps.check(s, ps.measure(out), CFG) == [], s["id"]
        checked += 1
    assert checked >= 21


def test_level_ordering_follows_the_mix_intent():
    lufs = {s["id"]: s["target_lufs"] for s in CFG["sounds"]}
    assert lufs["level_up_evolution"] > lufs["level_up_normal"] > lufs["shot_right"]
    assert lufs["evolution_1"] > lufs["shot_right"]
    assert lufs["reload_click"] < lufs["shot_right"] and lufs["reload_spin_1"] < lufs["shot_right"]
    assert lufs["xp_pickup"] <= lufs["shot_right"] - 4
