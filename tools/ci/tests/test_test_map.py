"""F-044: seçici koşu eşlemesi — sahipsiz test yok, paylaşılan/eşlemesiz dosya => FULL, eşleme güncel."""

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import shard  # noqa: E402
import test_map  # noqa: E402

M = test_map.build()  # test_map.json izlenmez (S-map): bellekte üretilir


def test_build_is_deterministic():
    assert test_map.build() == M


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


def test_map_entries_point_to_existing_files():
    for f in M["files"]:
        assert (ROOT / f).is_file(), f
    for t in M["tests"]:
        assert (ROOT / t).is_file(), t


def test_check_command_ok():
    assert test_map.check() == 0


def test_comment_mentions_do_not_create_dependencies():
    assert "Hud" not in test_map.strip_comments("# Hud burada yorum\nvar x := 1  # Hud\nvar s := \"# Hud\"\n").replace('"# Hud"', "")


def test_mutation_compare_flags_missed_failures(tmp_path):
    import prova_test_map  # noqa: PLC0415

    hud = "scripts/ui/hud.gd"
    sel = test_map.select([hud], M)
    outside = next(t for t in M["tests"] if t not in sel)
    ok, bad = tmp_path / "ok.xml", tmp_path / "bad.xml"
    suite = '<testsuites><testsuite name="{n}" tests="1" failures="1" errors="0"><testcase classname="{n}" name="a"/></testsuite></testsuites>'
    ok.write_text(suite.format(n=sel[0]))
    bad.write_text(suite.format(n=outside))
    assert prova_test_map.compare([hud], [str(ok)]) == 0
    assert prova_test_map.compare([hud], [str(bad)]) == 1


# --- S-map: test_map.json izlenmez, `ensure` ile üretilir ---------------------------------------------------------------------


@pytest.fixture
def tmp_map(tmp_path, monkeypatch):
    monkeypatch.setattr(test_map, "MAP", tmp_path / "test_map.json")
    return tmp_path / "test_map.json"


def test_ensure_creates_a_missing_map(tmp_map):
    assert not tmp_map.exists()
    assert test_map.ensure() == 0
    assert json.loads(tmp_map.read_text(encoding="utf-8")) == M


def test_ensure_rewrites_a_stale_map(tmp_map):
    tmp_map.write_text('{"version": 0}', encoding="utf-8")
    assert test_map.ensure() == 0
    assert json.loads(tmp_map.read_text(encoding="utf-8")) == M


def test_ensure_leaves_a_fresh_map_untouched(tmp_map):
    test_map.ensure()
    before = tmp_map.stat().st_mtime_ns
    assert test_map.ensure() == 0
    assert tmp_map.stat().st_mtime_ns == before


def test_ensure_reports_generation_failure(tmp_map, monkeypatch, capsys):
    def boom(*a, **k):
        raise RuntimeError("kırık")

    monkeypatch.setattr(test_map, "build", boom)
    assert test_map.ensure() == 1
    assert "TEST_MAP: üretim hatası" in capsys.readouterr().err
    assert not tmp_map.exists()


def test_load_generates_when_missing(tmp_map):
    assert test_map.load() == M


def test_ensure_command_via_cli(tmp_path):
    r = subprocess.run([sys.executable, str(ROOT / "tools/ci/test_map.py"), "ensure"], capture_output=True, text=True, cwd=ROOT)
    assert r.returncode == 0, r.stderr


def test_map_json_is_untracked_and_ignored():
    tracked = subprocess.run(["git", "ls-files", "tools/ci/test_map.json"], capture_output=True, text=True, cwd=ROOT).stdout
    assert tracked.strip() == "", "tools/ci/test_map.json izlenmemeli (git rm --cached)"
    ignored = subprocess.run(["git", "check-ignore", "-q", "tools/ci/test_map.json"], cwd=ROOT)
    assert ignored.returncode == 0, ".gitignore'da tools/ci/test_map.json yok"


def test_gate_fast_mode_uses_ensure_not_a_committed_map():
    gate = (ROOT / "tools/gate.sh").read_text(encoding="utf-8")
    assert "test_map.py ensure" in gate
    assert "test_map.py check" not in gate


def test_clean_gitless_copy_ensures_and_selects(tmp_path):
    # selftest kopyası: izlenen dosyalar, .git yok, harita yok (temiz checkout)
    for d in ("scripts", "test"):
        shutil.copytree(ROOT / d, tmp_path / d, ignore=shutil.ignore_patterns("*.import"))
    (tmp_path / "tools/ci").mkdir(parents=True)
    shutil.copy(ROOT / "tools/ci/test_map.py", tmp_path / "tools/ci/test_map.py")
    shutil.copy(ROOT / "project.godot", tmp_path / "project.godot")
    py = tmp_path / "tools/ci/test_map.py"
    assert not (tmp_path / "tools/ci/test_map.json").exists()
    assert subprocess.run([sys.executable, str(py), "ensure"], capture_output=True, text=True, cwd=tmp_path).returncode == 0
    assert (tmp_path / "tools/ci/test_map.json").is_file()
    sel = subprocess.run([sys.executable, str(py), "select", "scripts/ui/hud.gd"], capture_output=True, text=True, cwd=tmp_path)
    assert sel.returncode == 0 and sel.stdout.strip() != "FULL"


def test_selection_is_safe_for_deleted_or_renamed_files():
    assert test_map.select(["test/unit/test_silinmis_dosya.gd"], M) == []  # silinmiş/taşınmış test: seçilecek şey yok
    assert test_map.select(["scripts/ui/yeniden_adlandirilmis_eski_ad.gd"], M) == "FULL"  # eşlemede yok => şüphede tam
