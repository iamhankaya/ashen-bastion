import json
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check_junit.py"


def run(tmp_path, suites, mins, skipped=None):
    skipped = skipped or {}
    xml = "<testsuites>" + "".join(
        f'<testsuite name="{n}" tests="{c}" skipped="{skipped.get(n, 0)}"></testsuite>'
        for n, c in suites.items()
    ) + "</testsuites>"
    j = tmp_path / "j.xml"
    j.write_text(xml)
    m = tmp_path / "m.json"
    m.write_text(json.dumps(mins))
    return subprocess.run([sys.executable, str(SCRIPT), str(j), str(m)], capture_output=True)


def test_ok(tmp_path):
    assert run(tmp_path, {"a": 3}, {"a": 3}).returncode == 0


def test_zero_total_fails(tmp_path):
    assert run(tmp_path, {"a": 0}, {}).returncode == 1


def test_below_min_fails(tmp_path):
    assert run(tmp_path, {"a": 2}, {"a": 3}).returncode == 1


def test_missing_file_fails(tmp_path):
    assert run(tmp_path, {"b": 1}, {"a": 1}).returncode == 1


def test_skipped_tests_do_not_count(tmp_path):
    assert run(tmp_path, {"a": 3}, {"a": 3}, skipped={"a": 3}).returncode == 1
    assert run(tmp_path, {"a": 3}, {"a": 2}, skipped={"a": 1}).returncode == 0
