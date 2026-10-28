"""tools/ci/check_ui_rules.py: ScrollContainer yalnız UiKit.make_scroll ile; geçiş istisnası yalnız azalır."""

import subprocess
import sys
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "check_ui_rules.py"
ROOT = Path(__file__).resolve().parents[3]


def run(root: Path, *args: str):
    return subprocess.run(
        [sys.executable, str(TOOL), "--root", str(root), *args], capture_output=True, text=True, encoding="utf-8"
    )


def write(root: Path, rel: str, text: str) -> None:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")


def repo(tmp_path: Path, exceptions: str = "") -> Path:
    write(tmp_path, "scripts/ui/ui_kit.gd", "var s := ScrollContainer.new()\n")  # fabrikanın kendisi serbest
    write(tmp_path, "scripts/ui/ok.gd", "var s := UiKit.make_scroll()\n# ScrollContainer.new() yorumda\n")
    write(tmp_path, "tools/ci/ui_rules_exceptions.txt", exceptions)
    return tmp_path


def test_clean_repo_passes(tmp_path):
    r = run(repo(tmp_path))
    assert r.returncode == 0, r.stderr


def test_scroll_container_new_outside_factory_fails(tmp_path):
    root = repo(tmp_path)
    write(root, "scripts/ui/bad.gd", "func f():\n\tvar s := ScrollContainer.new()\n")
    r = run(root)
    assert r.returncode == 1
    assert "UI_RULE: scripts/ui/bad.gd:2: ScrollContainer fabrika dışı" in r.stderr


def test_scroll_container_node_in_tscn_fails(tmp_path):
    root = repo(tmp_path)
    write(root, "scenes/x.tscn", '[node name="L" type="ScrollContainer" parent="."]\n')
    r = run(root)
    assert r.returncode == 1
    assert "UI_RULE: scenes/x.tscn:1" in r.stderr


def test_skips_addons_and_claude_dirs(tmp_path):
    root = repo(tmp_path)
    write(root, "addons/gut/a.tscn", '[node type="ScrollContainer"]\n')
    write(root, ".claude/worktrees/w/scripts/b.gd", "var s := ScrollContainer.new()\n")
    assert run(root).returncode == 0


def test_listed_exception_is_allowed(tmp_path):
    root = repo(tmp_path, "scripts/ui/bad.gd\n")
    write(root, "scripts/ui/bad.gd", "var s := ScrollContainer.new()\n")
    assert run(root).returncode == 0


def test_second_occurrence_beyond_exception_fails(tmp_path):
    root = repo(tmp_path, "scripts/ui/bad.gd\n")
    write(root, "scripts/ui/bad.gd", "var a := ScrollContainer.new()\nvar b := ScrollContainer.new()\n")
    r = run(root)
    assert r.returncode == 1 and "bad.gd:2" in r.stderr


def test_stale_exception_fails(tmp_path):
    root = repo(tmp_path, "scripts/ui/gone.gd\n")
    r = run(root)
    assert r.returncode == 1
    assert "UI_RULE_STALE: scripts/ui/gone.gd" in r.stderr


def git(root: Path, *a: str) -> None:
    subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", *a], cwd=root, check=True, capture_output=True)


def test_new_exception_vs_base_fails(tmp_path):
    root = repo(tmp_path, "scripts/ui/a.gd\n")
    write(root, "scripts/ui/a.gd", "var s := ScrollContainer.new()\n")
    git(root, "init", "-q")
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "base")
    write(root, "scripts/ui/b.gd", "var s := ScrollContainer.new()\n")
    write(root, "tools/ci/ui_rules_exceptions.txt", "scripts/ui/a.gd\nscripts/ui/b.gd\n")
    r = run(root, "--base", "HEAD")
    assert r.returncode == 1
    assert "UI_RULE_NEW_EXCEPTION: scripts/ui/b.gd" in r.stderr


def test_shrinking_exceptions_vs_base_passes(tmp_path):
    root = repo(tmp_path, "scripts/ui/a.gd\n")
    write(root, "scripts/ui/a.gd", "var s := ScrollContainer.new()\n")
    git(root, "init", "-q")
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "base")
    write(root, "scripts/ui/a.gd", "var s := UiKit.make_scroll()\n")
    write(root, "tools/ci/ui_rules_exceptions.txt", "")
    assert run(root, "--base", "HEAD").returncode == 0


def test_real_repo_is_green():
    r = run(ROOT)
    assert r.returncode == 0, r.stderr


def test_unresolvable_base_is_an_error_not_a_skip(tmp_path):
    root = repo(tmp_path)
    git(root, "init", "-q")
    r = run(root, "--base", "yok-boyle-ref")
    assert r.returncode != 0 and "UI_RULE_BASE" in r.stderr


def test_build_dir_below_root_is_still_scanned(tmp_path):
    root = repo(tmp_path)
    write(root, "scripts/build/x.gd", "var s := ScrollContainer.new()\n")
    assert run(root).returncode == 1
