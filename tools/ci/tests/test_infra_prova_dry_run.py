"""Prova fazı kuru deneme aracı: dosya kümesi, git durumu sınıflaması, GUT günlüğü ayrıştırma, kök güvenliği."""
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
IN_GIT = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--git-dir"], capture_output=True).returncode == 0  # selftest kopyası git'siz
DRY_TREE = (ROOT / "data/characters/zz_dry.json").exists()  # kuru deneme ağacı: sahte dosyalar commit'li, "temiz ağaç" varsayımı geçersiz
spec = importlib.util.spec_from_file_location("prova_dry_run", ROOT / "tools" / "ci" / "prova_dry_run.py")
pdr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pdr)


@pytest.mark.skipif(DRY_TREE, reason="kuru deneme ağacı: sahte dosyalar zaten var")
def test_scenarios_only_create_new_files_under_data_or_reducer_dir():
    for name in pdr.SCENARIOS:
        files = pdr.scenario_files(ROOT, name)
        assert files, name
        for rel in files:
            assert not (ROOT / rel).exists(), f"{name}: {rel} zaten var (yeni dosya olmalı)"
            assert rel.startswith(("data/", "scripts/ctrl/achievement_reducers/")), rel


def test_scenario_json_is_valid_and_ids_are_zz_dry():
    for name in pdr.SCENARIOS:
        for rel, body in pdr.scenario_files(ROOT, name).items():
            if rel.endswith(".json"):
                assert "zz_dry" in json.dumps(json.loads(body)), rel


def test_reducer_scenario_is_consistent():
    files = pdr.scenario_files(ROOT, "ach_reducer")
    metric = json.loads(files["data/achievements/zz_dry_reducer.json"])
    gd = files["scripts/ctrl/achievement_reducers/zz_dry_reducer.gd"]
    assert metric["reducer"] == "ZzDryReducer" and "class_name ZzDryReducer" in gd and "extends AchievementReducer" in gd


def test_classify_status_splits_new_from_modified():
    new, changed = pdr.classify_status("?? data/a.json\n M data/achievements.json\nA  x.gd\n D gone.gd\n")
    assert new == ["data/a.json", "x.gd"]
    assert changed == ["data/achievements.json", "gone.gd"]


def test_parse_gut_failures_binds_failed_line_to_last_test():
    log = (
        "res://test/unit/test_a.gd\n* test_ok\n* test_bad\n    [Failed]:  x\n      at line 3\n    [Failed]:  y\n* test_after\n"
        "res://test/unit/test_b.gd\n* test_b1\n    [Failed]:  z\n\nTests              9\nPassing Tests      6\nFailing Tests      3\n"
    )
    fails, tot = pdr.parse_gut_failures(log)
    assert fails == ["res://test/unit/test_a.gd :: test_bad", "res://test/unit/test_b.gd :: test_b1"]
    assert tot == {"tests": 9, "passing": 6, "failing": 3}


def test_root_guard_refuses_repo_and_non_worktree(tmp_path):
    with pytest.raises(SystemExit):
        pdr.check_root(ROOT)
    with pytest.raises(SystemExit):
        pdr.check_root(ROOT / "tools")
    plain = tmp_path / "plain"
    plain.mkdir()
    with pytest.raises(SystemExit):
        pdr.check_root(plain)  # .git yok


def test_root_guard_refuses_outside_tempdir(tmp_path, monkeypatch):
    monkeypatch.setattr(pdr.tempfile, "gettempdir", lambda: str(tmp_path / "elsewhere"))
    d = tmp_path / "wt"
    (d / ".git").mkdir(parents=True)
    with pytest.raises(SystemExit):
        pdr.check_root(d)


@pytest.mark.skipif(not IN_GIT or DRY_TREE, reason="git deposu değil (selftest kopyası) ya da kuru deneme ağacı")
def test_no_run_reports_files_and_leaves_tree_clean(tmp_path):
    wt = tmp_path / "wt"
    subprocess.run(["git", "-C", str(ROOT), "worktree", "add", "--detach", "-q", str(wt), "HEAD"], check=True)
    try:
        r = subprocess.run([sys.executable, str(ROOT / "tools/ci/prova_dry_run.py"), "--root", str(wt), "--scenario", "all", "--no-run"],
                           capture_output=True, text=True, encoding="utf-8", env={**os.environ, "PROVA_ALLOW_ROOT": str(wt.resolve())})
        assert r.returncode == 0, r.stderr
        lines = [l for l in r.stdout.splitlines() if l.startswith("SCENARIO")]
        assert len(lines) == 4
        for l in lines:
            assert "degisen=0" in l, l
        assert subprocess.run(["git", "-C", str(wt), "status", "--porcelain"], capture_output=True, text=True).stdout.strip() == ""
    finally:
        subprocess.run(["git", "-C", str(ROOT), "worktree", "remove", "--force", str(wt)], check=False)
