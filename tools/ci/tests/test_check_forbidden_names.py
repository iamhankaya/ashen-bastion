"""tools/ci/check_forbidden_names.sh: desen ortamdan gelir; yoksa atlanır; eşleşen dosya adı yazılır, metin yazılmaz."""

import os
import shutil
import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check_forbidden_names.sh"


def run(repo: Path, **env):
    e = {"PATH": os.environ["PATH"], "HOME": str(repo), **env}
    return subprocess.run(["bash", str(repo / "tools/ci/check_forbidden_names.sh")], cwd=repo, env=e, capture_output=True, text=True)


def make_repo(tmp_path: Path) -> Path:
    (tmp_path / "tools/ci").mkdir(parents=True)
    shutil.copy(SCRIPT, tmp_path / "tools/ci/check_forbidden_names.sh")
    (tmp_path / "ok.md").write_text("temiz metin\n")
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp_path, check=True)
    return tmp_path


def test_skips_without_pattern(tmp_path):
    r = run(make_repo(tmp_path))
    assert r.returncode == 0 and "atlandı" in r.stdout


def test_clean_repo_passes(tmp_path):
    r = run(make_repo(tmp_path), GATE_FORBIDDEN_RE="gizliad|baskaad")
    assert r.returncode == 0 and "temiz" in r.stdout


def test_match_fails_with_file_path_but_not_the_text(tmp_path):
    repo = make_repo(tmp_path)
    (repo / "docs").mkdir()
    (repo / "docs/not.md").write_text("burada GizliAd geçiyor\n")  # izlenmeyen dosya da taranır
    r = run(repo, GATE_FORBIDDEN_RE="gizliad")
    assert r.returncode == 1
    assert "docs/not.md" in r.stderr
    assert "GizliAd" not in r.stderr + r.stdout and "gizliad" not in r.stderr.replace("GATE_FORBIDDEN_RE", "")


def test_invalid_pattern_fails(tmp_path):
    assert run(make_repo(tmp_path), GATE_FORBIDDEN_RE="(").returncode == 1
