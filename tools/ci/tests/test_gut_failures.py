"""F-ashen-bastion-126: kapı başarısız test adlarını günlük kırpılsa da basar; F-ashen-bastion-045: mid_all.sh --import kontrolü."""
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LOG = (
    "res://test/unit/test_a.gd\n* test_ok\n    [Passed]\n* test_bad_one\n    [Failed]:  expected 1\n"
    "res://test/unit/test_b.gd\n- test_bad_two\n    [Failed]:  nope\n" + "\x1b[31mfiller\x1b[0m\n" * 50
)


def test_gut_failures_lists_failed_test_names(tmp_path):
    log = tmp_path / "gut.log"
    log.write_text(LOG, encoding="utf-8")
    r = subprocess.run([sys.executable, str(ROOT / "tools/ci/gut_failures.py"), str(log), str(tmp_path / "yok.log")], capture_output=True, text=True)
    assert r.returncode == 0
    assert "GUT_FAILED: res://test/unit/test_a.gd :: test_bad_one" in r.stderr
    assert "GUT_FAILED: res://test/unit/test_b.gd :: test_bad_two" in r.stderr
    assert "test_ok" not in r.stderr


def test_gate_prints_failed_names_on_gut_failure():
    gate = (ROOT / "tools/gate.sh").read_text(encoding="utf-8")
    assert gate.count("tools/ci/gut_failures.py") >= 2  # tek süreç + paralel yol


def test_mid_all_requires_imported_project(tmp_path):
    """Temiz klonda (.godot/imported yok) sessizce boş çıktı yerine açık hata."""
    (tmp_path / "tools/balance").mkdir(parents=True)
    shutil.copy(ROOT / "tools/balance/mid_all.sh", tmp_path / "tools/balance/mid_all.sh")
    env = {**os.environ, "GODOT_BIN": "/bin/true"}
    r = subprocess.run(["bash", str(tmp_path / "tools/balance/mid_all.sh"), str(tmp_path / "out"), "1", "0", "1"], capture_output=True, text=True, env=env)
    assert r.returncode != 0 and "--import" in r.stderr
