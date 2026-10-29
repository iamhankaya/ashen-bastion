"""Kapı geçişi (plan Faz 8): gate_min_tests.json emekli, adım 7 kimlik kapısı (check_test_ids.py) ile koşar."""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GATE = (ROOT / "tools" / "gate.sh").read_text(encoding="utf-8")
CI = (ROOT / "tools" / "ci")


def step7():
    return GATE[GATE.index('step "7. Sahte yeşil korumaları"'):GATE.index('step "8.')]


def test_retired_files_are_gone():
    assert not (ROOT / "tools" / "gate_min_tests.json").exists()
    assert not (ROOT / "tools" / "update_min_tests.sh").exists()


def test_no_live_reference_to_the_retired_table():
    hits = []
    for p in list((ROOT / "tools").rglob("*")) + list((ROOT / "test").rglob("*.gd")):
        if not p.is_file() or p.suffix not in {".py", ".sh", ".gd", ".txt", ".yml"} or p == Path(__file__):
            continue
        if re.search(r"gate_min_tests|update_min_tests", p.read_text(encoding="utf-8", errors="replace")):
            hits.append(p.relative_to(ROOT).as_posix())
    assert not hits, hits


def test_gate_step7_uses_the_id_gate_full_and_selected():
    assert "gate_min_tests" not in GATE
    full, fast = GATE.split("elif [ $FAST -eq 1 ] && [ -n \"$GUT_CONFIG\" ]; then")
    assert "check_test_ids.py" in full and "--mode full" in full and "--junit .gate/junit.xml" in full
    assert "check_test_ids.py" in fast and "--mode selected" in fast and "--files .gate/selected.txt" in fast


def test_gate_base_comes_from_git_declared_file_or_is_announced():
    s = GATE
    assert "GATE_BASE_DECLARED" in s and "--base-declared" in s
    assert "--no-base" in s and "LOST denetimi atlandı" in s


def test_shard_merge_check_no_longer_claims_min_table():
    assert "gate_min_tests" not in (CI / "shard.py").read_text(encoding="utf-8")


def test_verify_job_has_history_for_the_base():
    ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    job = ci[ci.index("  test:\n"):ci.index("  selftest:")]
    assert "fetch-depth: 0" in job


def test_selftest_has_id_loss_scenarios():
    s = (CI / "selftest_gate.sh").read_text(encoding="utf-8")
    assert "gate_min_tests" not in s
    for name in ("test_kimligi_kaybi", "kosmayan_test"):
        assert f"scenario_{name}()" in s and f"GROUP[{name}]=" in s


def test_check_junit_is_a_total_sanity_check_only(tmp_path):
    j = tmp_path / "j.xml"
    j.write_text('<testsuites><testsuite name="a" tests="2" skipped="2"></testsuite></testsuites>')
    r = subprocess.run([sys.executable, str(CI / "check_junit.py"), str(j)], capture_output=True, text=True)
    assert r.returncode == 1 and "sıfır" in r.stderr
    j.write_text('<testsuites><testsuite name="a" tests="2" skipped="1"></testsuite></testsuites>')
    assert subprocess.run([sys.executable, str(CI / "check_junit.py"), str(j)]).returncode == 0


def test_selftest_inline_python_heredocs_compile():
    """selftest_gate.sh içindeki `python3 - <<'PY'` gövdeleri sözdizimi olarak geçerli (kaçış hatası CI'da geç görünür)."""
    text = (CI / "selftest_gate.sh").read_text(encoding="utf-8")
    bodies = re.findall(r"<<'PY'\n(.*?)\nPY\n", text, re.S)
    assert len(bodies) >= 3
    for b in bodies:
        compile(b, "selftest_gate.sh:heredoc", "exec")
