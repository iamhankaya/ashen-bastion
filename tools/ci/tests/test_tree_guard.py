"""F-153: gate'te pytest, GUT ile aynı ağaçta koşar; pytest'in izlenen dosyayı değiştirmesi ya da GUT'un okuduğu dizinlere
(test/, scripts/, data/, addons/) yeni dosya bırakması tree_guard ile yakalanır."""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import tree_guard  # noqa: E402


def git(repo, *a):
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *a], cwd=repo, check=True, capture_output=True)


def make_repo(tmp_path):
    (tmp_path / "data").mkdir()
    (tmp_path / "data" / "a.json").write_text("{}", encoding="utf-8")
    (tmp_path / ".gitignore").write_text(".gate/\n", encoding="utf-8")
    git(tmp_path, "init", "-q")
    git(tmp_path, "add", "-A")
    git(tmp_path, "commit", "-qm", "x")
    return tmp_path


def test_digest_changes_when_a_tracked_file_is_modified(tmp_path):
    repo = make_repo(tmp_path)
    before = tree_guard.digest(repo)
    (repo / "data" / "a.json").write_text('{"x":1}', encoding="utf-8")
    assert tree_guard.digest(repo) != before


def test_digest_changes_when_a_new_file_appears_in_a_gut_read_dir(tmp_path):
    repo = make_repo(tmp_path)
    before = tree_guard.digest(repo)
    (repo / "data" / "yeni.json").write_text("{}", encoding="utf-8")
    assert tree_guard.digest(repo) != before


def test_digest_ignores_gate_outputs_and_untracked_files_elsewhere(tmp_path):
    repo = make_repo(tmp_path)
    before = tree_guard.digest(repo)
    (repo / ".gate").mkdir()
    (repo / ".gate" / "junit.xml").write_text("x", encoding="utf-8")
    (repo / "not.txt").write_text("x", encoding="utf-8")
    assert tree_guard.digest(repo) == before


def test_digest_is_none_without_git(tmp_path):
    assert tree_guard.digest(tmp_path) is None
