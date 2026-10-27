"""v2.1 U1b (M dilimi): balance.yml matrisi (14 hücre), mid_all.sh hücre parametresi, nightly.yml ve Sonsuz 40. dk testi."""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def _src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def _cells():
    wf = _src(".github/workflows/balance.yml")
    m = re.search(r"^\s+cell:\s*\[(.*?)\]", wf, re.M | re.S)
    assert m, "balance.yml matrix.cell listesi yok"
    return re.findall(r"[\w]+:[\w]+:[\w]+", m.group(1))


def test_m30_matrix_has_14_cells_mode_x_diff_x_policy():
    cells = _cells()
    assert len(cells) == len(set(cells)) == 14
    want = {f"{m}:{d}:{p}" for m in ("normal", "quick") for d in ("easy", "normal", "hard") for p in ("strong_lord", "kite")}
    want |= {"endless:easy:strong_lord", "endless:normal:strong_lord"}
    assert set(cells) == want


def test_m31_each_cell_splits_into_four_100_seed_jobs_with_timing():
    wf = _src(".github/workflows/balance.yml")
    assert re.search(r"part:\s*\[0,\s*1,\s*2,\s*3\]", wf)
    assert 'default: "100"' in wf and "timing_" in wf  # ilk dispatch'te 100 tohum süresi ölçülür


def test_m32_merge_job_reports_level_ratio_sanity_and_cell_differences():
    wf = _src(".github/workflows/balance.yml")
    assert "--level-ratio quick:normal normal:normal" in wf and "--sanity" in wf
    assert "--diff quick:normal normal:normal" in wf and "--diff normal:easy normal:normal" in wf


def test_m33_mid_all_passes_mode_and_diff_per_cell_and_defaults_to_legacy():
    sh = _src("tools/balance/mid_all.sh")
    assert "CELLS" in sh and "mid_run.gd" in sh
    r = subprocess.run(["bash", "-n", "tools/balance/mid_all.sh"], cwd=ROOT, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


def test_m34_nightly_runs_only_verify_long_with_120_min_timeout():
    wf = _src(".github/workflows/nightly.yml")
    assert re.search(r"^\s+schedule:", wf, re.M) and "workflow_dispatch:" in wf
    assert "bash tools/verify_long.sh" in wf and re.search(r"timeout-minutes:\s*120\b", wf)
    assert "pull_request" not in wf and "push:" not in wf  # PR'ları bloke etmez


def test_m35_ci_verify_job_runs_no_long_simulation():
    ci = _src(".github/workflows/ci.yml")
    assert "verify_long" not in ci and "test/long" not in ci


def test_m36_endless_long_test_exists_with_the_three_thresholds():
    src = _src("test/long/test_ver_v21_endless_long.gd")
    assert "OBJECT_COUNT" in src and "alive_cap" in src and "P99_RATIO" in src
    assert "endless" in src and "2400" in src  # 40. dk
    assert "user://" not in src


def _run_mid_all(tmp_path, env_extra):
    fake = tmp_path / "godot.sh"
    log = tmp_path / "calls.txt"
    fake.write_text(f'#!/usr/bin/env bash\necho "$*" >> "{log.as_posix()}"\n', encoding="utf-8", newline="\n")
    fake.chmod(0o755)  # Linux'ta çalıştırma biti şart: xargs altında "$0" olarak çağrılır
    env ={"PATH": "/usr/bin:/bin:/mingw64/bin", "GODOT_BIN": fake.as_posix(), "POLICIES": "strong", "CHARS": "gunslinger", **env_extra}
    r = subprocess.run(["bash", "tools/balance/mid_all.sh", (tmp_path / "out").as_posix(), "3001", "10", "1"],
                       cwd=ROOT, capture_output=True, text=True, env=env)
    assert r.returncode == 0, r.stderr
    return sorted(log.read_text(encoding="utf-8").splitlines())


def test_m37_mid_all_legacy_runs_every_job_without_mode_args(tmp_path):
    calls = _run_mid_all(tmp_path, {})
    assert len(calls) == 2  # 10 tohum / 5'lik parça: iş satırları birleşip kaybolmaz
    assert all(len(c.split(" -- ", 1)[1].split()) == 5 for c in calls), calls


def test_m38_mid_all_cell_appends_mode_and_diff(tmp_path):
    calls = _run_mid_all(tmp_path, {"CELLS": "quick:easy endless:normal"})
    assert len(calls) == 4
    tails = sorted(" ".join(c.split(" -- ", 1)[1].split()[-2:]) for c in calls)
    assert tails == ["endless normal"] * 2 + ["quick easy"] * 2
    assert all("quick_easy_" in c or "endless_normal_" in c for c in calls)
