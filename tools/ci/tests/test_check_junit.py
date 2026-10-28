import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check_junit.py"


def run(tmp_path, suites, skipped=None):
    skipped = skipped or {}
    xml = "<testsuites>" + "".join(
        f'<testsuite name="{n}" tests="{c}" skipped="{skipped.get(n, 0)}"></testsuite>'
        for n, c in suites.items()
    ) + "</testsuites>"
    j = tmp_path / "j.xml"
    j.write_text(xml)
    return subprocess.run([sys.executable, str(SCRIPT), str(j)], capture_output=True)


def test_ok(tmp_path):
    assert run(tmp_path, {"a": 3}).returncode == 0


def test_zero_total_fails(tmp_path):
    assert run(tmp_path, {"a": 0}).returncode == 1


def test_all_skipped_fails(tmp_path):
    assert run(tmp_path, {"a": 3}, skipped={"a": 3}).returncode == 1


def test_some_skipped_still_ok(tmp_path):
    assert run(tmp_path, {"a": 3}, skipped={"a": 1}).returncode == 0


def test_table_argument_is_gone(tmp_path):
    j = tmp_path / "j.xml"
    j.write_text('<testsuites><testsuite name="a" tests="1" skipped="0"></testsuite></testsuites>')
    assert subprocess.run([sys.executable, str(SCRIPT), str(j), "m.json"], capture_output=True).returncode == 2
