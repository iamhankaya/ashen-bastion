"""F-044: seçici koşu eşlemesi — sahipsiz test yok, paylaşılan/eşlemesiz dosya => FULL, eşleme güncel."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import shard  # noqa: E402
import test_map  # noqa: E402

M = test_map.load()


def test_map_is_fresh():
    assert test_map.build() == M, "tools/ci/test_map.json güncel değil: python3 tools/ci/test_map.py generate"


def test_every_test_file_is_in_map_and_selects_itself():
    # sahipsiz test yok: gate'in koştuğu her dosya eşlemede ve (a) kendi değişince kendini seçer (b) en az bir kaynak dosyaya bağlıdır ya da
    # yalnız kendisi vardır (bu durumda test bağımsızdır; yine de koşar)
    discovered = set(shard.discover())
    assert discovered == set(M["tests"]), sorted(discovered ^ set(M["tests"]))[:10]
    for t in M["tests"]:
        assert test_map.select([t], M) == [t], t


def test_every_test_is_reachable_from_some_mapped_source_or_is_standalone():
    linked = {t for ts in M["files"].values() for t in ts}
    standalone = sorted(set(M["tests"]) - linked)
    # kaynağa hiç bağlı olmayan test dosyası ancak kendi kendine yeten (yardımcı/sim ile paylaşılan) testtir; liste kısa olmalı ve
    # bu testlerin bağımlılıkları FULL_IF kapsamındadır (sim/data/helpers) — hızlı modda yalnız kendi değişince koşarlar.
    assert len(standalone) < len(M["tests"]) // 2, standalone


def test_shared_files_force_full():
    for f in (
        "scripts/sim/game_sim.gd",
        "scripts/sim/skills/hortum.gd",
        "data/skills/tufan.json",
        "test/helpers/sim_kit.gd",
        "test/fixtures/golden_hashes.json",
        "tools/gate.sh",
        "tools/ci/shard.py",
        "tools/gate_min_tests.json",
        "project.godot",
        ".gutconfig.json",
        "export_presets.cfg",
        "addons/gut/gut.gd",
        ".github/workflows/ci.yml",
        "assets/gfx/x.png",
        "scripts/autoload/events.gd",
    ):
        assert test_map.select([f], M) == "FULL", f


def test_unmapped_file_falls_back_to_full():
    assert test_map.select(["scripts/ui/zz_yeni_dosya.gd"], M) == "FULL"
    assert test_map.select(["bilinmeyen/dizin/x.bin"], M) == "FULL"
    assert test_map.select(["README.md"], M) == "FULL"


def test_full_wins_over_mapped_in_a_mixed_change():
    hud = next(f for f in M["files"] if f.endswith("ui/hud.gd"))
    assert isinstance(test_map.select([hud], M), list)
    assert test_map.select([hud, "data/skills/tufan.json"], M) == "FULL"
    assert test_map.select(["data/skills/tufan.json", hud], M) == "FULL"


def test_mapped_script_selects_all_tests_that_reference_it():
    # bağımsız kontrol: hud.gd sınıf adı/yolu geçen her test seçimde olmalı (geçişli kapanışın alt kümesi)
    hud = "scripts/ui/hud.gd"
    sel = set(test_map.select([hud], M))
    direct = {
        t for t in M["tests"]
        if "Hud" in test_map.strip_comments((ROOT / t).read_text(encoding="utf-8")) or "ui/hud.gd" in (ROOT / t).read_text(encoding="utf-8")
    }
    assert direct <= sel, sorted(direct - sel)


def test_map_json_has_no_stale_entries():
    for f in M["files"]:
        assert (ROOT / f).is_file(), f
    for t in M["tests"]:
        assert (ROOT / t).is_file(), t


def test_check_command_ok():
    assert test_map.check() == 0


def test_comment_mentions_do_not_create_dependencies():
    assert "Hud" not in test_map.strip_comments("# Hud burada yorum\nvar x := 1  # Hud\nvar s := \"# Hud\"\n").replace('"# Hud"', "")
