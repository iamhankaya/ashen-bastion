"""Çakışma provası: iki paralel dalın sahte karakter/mod/başarım + kayıt satırları çakışmasız birleşir; union'sız kontrol çakışır."""
import subprocess
import sys

import pytest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
IN_GIT = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--git-dir"], capture_output=True).returncode == 0  # selftest kopyası git'siz


@pytest.mark.skipif(not IN_GIT, reason="git deposu değil (selftest kopyası)")
def test_two_parallel_branches_merge_cleanly_and_control_without_union_conflicts(tmp_path):
    r = subprocess.run([sys.executable, "-I", str(ROOT / "tools/ci/prova_conflict.py"), "--clone", str(tmp_path / "cf")],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    assert "MERGE a+b: temiz" in r.stdout, r.stdout + r.stderr
    assert "MERGE kontrol(union yok): " in r.stdout and "temiz" not in r.stdout.split("kontrol(union yok)")[1], r.stdout
    assert r.returncode == 0, r.stdout + r.stderr
