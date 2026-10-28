"""S-budget: check_line_budget.py — tek tip tavan (varsayılan 800), azalan istisna kaydı, tarama dışı dizinler."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "tools" / "ci" / "check_line_budget.py"
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import check_line_budget  # noqa: E402


def gd(root, rel, n):
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("x\n" * n, encoding="utf-8")


def errors(root, exceptions="", base=None, max_lines=800):
    return check_line_budget.check(root, max_lines, check_line_budget.parse_exceptions(exceptions), None if base is None else check_line_budget.parse_exceptions(base))


def test_file_over_ceiling_without_exception_is_red(tmp_path):
    gd(tmp_path, "scripts/sim/big.gd", 801)
    gd(tmp_path, "scripts/sim/ok.gd", 800)
    errs = errors(tmp_path)
    assert errs == ["LINE_BUDGET: scripts/sim/big.gd: 801 > 800"]


def test_exception_raises_the_ceiling_for_that_file_only(tmp_path):
    gd(tmp_path, "scripts/ui/a.gd", 900)
    gd(tmp_path, "scripts/ui/b.gd", 801)
    errs = errors(tmp_path, "scripts/ui/a.gd | 900\n")
    assert errs == ["LINE_BUDGET: scripts/ui/b.gd: 801 > 800"]


def test_file_growing_past_its_exception_is_red(tmp_path):
    gd(tmp_path, "scripts/ui/a.gd", 901)
    assert errors(tmp_path, "scripts/ui/a.gd | 900\n") == ["LINE_BUDGET: scripts/ui/a.gd: 901 > 900"]


def test_exception_for_file_within_ceiling_is_stale(tmp_path):
    gd(tmp_path, "scripts/ui/a.gd", 800)
    assert errors(tmp_path, "scripts/ui/a.gd | 900\n") == ["LINE_BUDGET_STALE: scripts/ui/a.gd: 800 <= 800, satırı sil"]


def test_exception_for_missing_file_is_stale(tmp_path):
    assert errors(tmp_path, "scripts/ui/gone.gd | 900\n") == ["LINE_BUDGET_STALE: scripts/ui/gone.gd: dosya yok, satırı sil"]


def test_exception_value_may_not_rise_or_appear_versus_base(tmp_path):
    gd(tmp_path, "scripts/ui/a.gd", 950)
    gd(tmp_path, "scripts/ui/n.gd", 850)
    errs = errors(tmp_path, "scripts/ui/a.gd | 950\nscripts/ui/n.gd | 850\n", base="scripts/ui/a.gd | 900\n")
    assert errs == [
        "LINE_BUDGET_RAISED: scripts/ui/a.gd: 900 -> 950",
        "LINE_BUDGET_RAISED: scripts/ui/n.gd: yeni istisna (base'de yok)",
    ]


def test_value_may_drop_versus_base(tmp_path):
    gd(tmp_path, "scripts/ui/a.gd", 850)
    assert errors(tmp_path, "scripts/ui/a.gd | 850\n", base="scripts/ui/a.gd | 900\n") == []


def test_ignored_directories_are_not_scanned(tmp_path):
    for d in (".claude/worktrees/x/scripts", ".godot", ".gate", "addons/gut", "build"):
        gd(tmp_path, f"{d}/huge.gd", 1200)
    gd(tmp_path, "test/unit/test_big.gd", 1200)  # yalnız scripts/ ağacı denetlenir
    assert errors(tmp_path) == []


def test_comments_and_blank_lines_in_exception_file(tmp_path):
    gd(tmp_path, "scripts/ui/a.gd", 900)
    assert errors(tmp_path, "# başlık\n\nscripts/ui/a.gd | 900  # R5b boşaltır\n") == []


def test_malformed_exception_line_is_reported(tmp_path):
    errs = errors(tmp_path, "scripts/ui/a.gd 900\n")
    assert errs and errs[0].startswith("LINE_BUDGET_FORMAT:")


def test_cli_exit_codes_and_stderr_format(tmp_path):
    gd(tmp_path, "scripts/sim/big.gd", 801)
    exc = tmp_path / "exc.txt"
    exc.write_text("", encoding="utf-8")
    r = subprocess.run([sys.executable, str(TOOL), "--root", str(tmp_path), "--exceptions", str(exc)], capture_output=True, text=True)
    assert r.returncode == 1
    assert "LINE_BUDGET: scripts/sim/big.gd: 801 > 800" in r.stderr
    r = subprocess.run([sys.executable, str(TOOL), "--root", str(tmp_path), "--exceptions", str(exc), "--max", "900"], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


def test_real_repo_is_green_with_committed_exceptions():
    r = subprocess.run([sys.executable, str(TOOL)], capture_output=True, text=True, cwd=ROOT)
    assert r.returncode == 0, r.stderr


def test_committed_exceptions_are_the_five_known_files_at_current_size():
    parsed = check_line_budget.parse_exceptions((ROOT / "tools" / "ci" / "line_budget_exceptions.txt").read_text(encoding="utf-8"))
    assert set(parsed) == {
        "scripts/ui/result_screen.gd",
        "scripts/sim/game_sim.gd",
        "scripts/ctrl/game_controller.gd",
        "scripts/sim/game_data.gd",
        "scripts/ui/characters_screen.gd",
    }


def test_unresolvable_base_ref_is_an_error_not_a_silent_skip(tmp_path):
    gd(tmp_path, "scripts/sim/a.gd", 1)
    r = subprocess.run([sys.executable, str(TOOL), "--root", str(tmp_path), "--base", "yok-ref"], capture_output=True, text=True, encoding="utf-8")
    assert r.returncode != 0 and "BASE_UNRESOLVED" in (r.stderr + r.stdout)
