"""R3 kanıtı: check_assert_counts.py — JUnit `assertions` özniteliğiyle bölme öncesi/sonrası assertion kaybı denetimi."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "tools" / "ci" / "check_assert_counts.py"


def junit(path, cases):
    rows = "".join(f'<testcase name="{n}" assertions="{a}" status="pass" classname="{c}" time="0.1"/>' for c, n, a in cases)
    path.write_text(f'<?xml version="1.0"?><testsuites><testsuite name="s">{rows}</testsuite></testsuites>', encoding="utf-8")
    return str(path)


def run(tmp_path, before, after, moved="", removed=""):
    (tmp_path / "moved.txt").write_text(moved, encoding="utf-8")
    (tmp_path / "removed.txt").write_text(removed, encoding="utf-8")
    b, a = junit(tmp_path / "b.xml", before), junit(tmp_path / "a.xml", after)
    return subprocess.run(
        [sys.executable, str(TOOL), "--before", b, "--after", a, "--moved", str(tmp_path / "moved.txt"), "--removed", str(tmp_path / "removed.txt")],
        capture_output=True,
        text=True,
    )


def test_unchanged_ids_with_equal_counts_pass(tmp_path):
    r = run(tmp_path, [("t.gd", "test_a", 3)], [("t.gd", "test_a", 3)])
    assert r.returncode == 0, r.stderr


def test_split_one_to_many_sums_targets(tmp_path):
    moved = "t.gd::test_a -> n.gd::test_a1, n.gd::test_a2\n"
    r = run(tmp_path, [("t.gd", "test_a", 4)], [("n.gd", "test_a1", 2), ("n.gd", "test_a2", 2)], moved)
    assert r.returncode == 0, r.stderr


def test_split_losing_an_assertion_fails(tmp_path):
    moved = "t.gd::test_a -> n.gd::test_a1, n.gd::test_a2\n"
    r = run(tmp_path, [("t.gd", "test_a", 4)], [("n.gd", "test_a1", 2), ("n.gd", "test_a2", 1)], moved)
    assert r.returncode == 1
    assert "ASSERTS_LOST: t.gd::test_a: önce 4, sonra 3" in r.stderr


def test_unmoved_id_dropping_count_fails(tmp_path):
    r = run(tmp_path, [("t.gd", "test_a", 3)], [("t.gd", "test_a", 2)])
    assert r.returncode == 1 and "ASSERTS_LOST" in r.stderr


def test_missing_target_counts_as_zero_and_removed_is_exempt(tmp_path):
    assert run(tmp_path, [("t.gd", "test_a", 3)], []).returncode == 1
    r = run(tmp_path, [("t.gd", "test_a", 3)], [], removed="t.gd::test_a | gerekçe | T-1\n")
    assert r.returncode == 0, r.stderr


def test_more_assertions_after_is_fine(tmp_path):
    assert run(tmp_path, [("t.gd", "test_a", 3)], [("t.gd", "test_a", 5)]).returncode == 0
