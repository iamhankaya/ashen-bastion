"""Altyapı-B: tools/ci/refresh_weights.py — JUnit sürelerinden shard_weights.json yenileme (F-044). Otomatik commit/push yok."""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "tools" / "ci" / "refresh_weights.py"


def make_root(tmp_path, files, weights):
    root = tmp_path / "root"
    (root / "tools" / "ci").mkdir(parents=True)
    (root / "test").mkdir()
    (root / ".gutconfig.json").write_text(json.dumps({"dirs": ["res://test"], "include_subdirs": True}))
    for f in files:
        p = root / f
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("extends GutTest\n")
    w = root / "tools" / "ci" / "shard_weights.json"
    w.write_text(json.dumps(weights, indent=1, sort_keys=True) + "\n")
    return root, w


def junit(tmp_path, name, suites):
    body = "".join(f'<testsuite name="{n}" tests="1" failures="0" skipped="0" time="{t}"></testsuite>' for n, t in suites)
    p = tmp_path / name
    p.write_text(f'<?xml version="1.0"?><testsuites name="GutTests" tests="{len(suites)}">{body}</testsuites>')
    return p


def run(root, *args):
    return subprocess.run(
        [sys.executable, str(TOOL), "--root", str(root), *args], capture_output=True, text=True, encoding="utf-8"
    )


def test_adds_weightless_file_from_junit(tmp_path):
    root, w = make_root(tmp_path, ["test/unit/test_a.gd", "test/unit/test_b.gd"], {"test/unit/test_a.gd": 1.0})
    j = junit(tmp_path, "j.xml", [("test/unit/test_b.gd", "2.449")])
    r = run(root, "--junit", str(j), "--write")
    assert r.returncode == 0, r.stderr
    got = json.loads(w.read_text())
    assert got["test/unit/test_b.gd"] == 2.4
    assert got["test/unit/test_a.gd"] == 1.0  # JUnit'te yoksa eski ağırlık korunur


def test_without_write_changes_nothing(tmp_path):
    root, w = make_root(tmp_path, ["test/unit/test_a.gd"], {})
    before = w.read_text()
    j = junit(tmp_path, "j.xml", [("test/unit/test_a.gd", "3.0")])
    r = run(root, "--junit", str(j))
    assert r.returncode == 0, r.stderr
    assert w.read_text() == before
    assert "test/unit/test_a.gd" in r.stdout


def test_updates_existing_weight_and_drops_stale(tmp_path):
    root, w = make_root(tmp_path, ["test/unit/test_a.gd"], {"test/unit/test_a.gd": 9.9, "test/unit/test_gone.gd": 1.0})
    j = junit(tmp_path, "j.xml", [("test/unit/test_a.gd", "0.51")])
    assert run(root, "--junit", str(j), "--write").returncode == 0
    assert json.loads(w.read_text()) == {"test/unit/test_a.gd": 0.5}


def test_multiple_junits_are_merged_and_same_file_times_summed(tmp_path):
    root, w = make_root(tmp_path, ["test/unit/test_a.gd", "test/unit/test_b.gd"], {})
    j1 = junit(tmp_path, "j1.xml", [("test/unit/test_a.gd", "1.0")])
    j2 = junit(tmp_path, "j2.xml", [("test/unit/test_b.gd", "4.0"), ("test/unit/test_a.gd", "0.5")])
    assert run(root, "--junit", str(j1), str(j2), "--write").returncode == 0
    assert json.loads(w.read_text()) == {"test/unit/test_a.gd": 1.5, "test/unit/test_b.gd": 4.0}


def test_unknown_junit_suite_is_reported_not_written(tmp_path):
    root, w = make_root(tmp_path, ["test/unit/test_a.gd"], {})
    j = junit(tmp_path, "j.xml", [("test/unit/test_a.gd", "1.0"), ("test/unit/test_ghost.gd", "9.0")])
    r = run(root, "--junit", str(j), "--write")
    assert r.returncode == 0
    assert "test_ghost.gd" in r.stderr
    assert "test_ghost.gd" not in w.read_text()


def test_output_format_matches_existing_file_style(tmp_path):
    root, w = make_root(tmp_path, ["test/unit/test_b.gd", "test/unit/test_a.gd"], {})
    j = junit(tmp_path, "j.xml", [("test/unit/test_b.gd", "2"), ("test/unit/test_a.gd", "1")])
    run(root, "--junit", str(j), "--write")
    assert w.read_text() == '{\n "test/unit/test_a.gd": 1.0,\n "test/unit/test_b.gd": 2.0\n}\n'


def test_missing_or_broken_junit_is_an_error_and_keeps_file(tmp_path):
    root, w = make_root(tmp_path, ["test/unit/test_a.gd"], {"test/unit/test_a.gd": 1.0})
    before = w.read_text()
    r = run(root, "--junit", str(tmp_path / "yok.xml"), "--write")
    assert r.returncode == 1 and "REFRESH_WEIGHTS" in r.stderr
    bad = tmp_path / "bad.xml"
    bad.write_text("<testsuites><oops")
    r = run(root, "--junit", str(bad), "--write")
    assert r.returncode == 1 and "REFRESH_WEIGHTS" in r.stderr
    assert w.read_text() == before


def test_empty_junit_is_refused(tmp_path):
    """Hiç testsuite yok = sahte yeşil: ağırlık dosyasını boşaltmaz."""
    root, w = make_root(tmp_path, ["test/unit/test_a.gd"], {"test/unit/test_a.gd": 1.0})
    j = junit(tmp_path, "j.xml", [])
    r = run(root, "--junit", str(j), "--write")
    assert r.returncode == 1 and "REFRESH_WEIGHTS" in r.stderr
    assert json.loads(w.read_text()) == {"test/unit/test_a.gd": 1.0}


def test_requires_junit_argument(tmp_path):
    root, _ = make_root(tmp_path, [], {})
    r = run(root)
    assert r.returncode == 2
