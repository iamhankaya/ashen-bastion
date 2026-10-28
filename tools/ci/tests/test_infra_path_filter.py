"""H1/H10: tools/ci/path_filter.sh; yol süzgeci. Şüphede (diff alınamaz, shallow, main, dispatch) HER ZAMAN tam koşu (run=1)."""
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "path_filter.sh"
INFRA = r"tools/|\.github/|project\.godot$|\.gutconfig\.json$|\.godot-version$|export_presets\.cfg$|addons/|scripts/ci"


def git(repo, *args):
    subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True,
                   env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"})


def make_repo(tmp_path, changed):
    """main'de bir commit (origin/main olarak da), dalda `changed` dosyalarını değiştiren bir commit."""
    repo = tmp_path / "r"
    repo.mkdir(parents=True)
    git(repo, "init", "-q", "-b", "main")
    (repo / "a.txt").write_text("1")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "base")
    git(repo, "update-ref", "refs/remotes/origin/main", "HEAD")
    git(repo, "checkout", "-q", "-b", "vlad/x")
    for f in changed:
        p = repo / f
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("degisti")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "change")
    return repo


def run(repo, pattern=INFRA, **env):
    out = repo / "gh_output"
    out.unlink(missing_ok=True)
    e = {"PATH": os.environ["PATH"], "GITHUB_REF": "refs/heads/vlad/x", "GITHUB_EVENT_NAME": "push", "GITHUB_OUTPUT": str(out)}
    e.update(env)
    r = subprocess.run(["bash", str(SCRIPT), pattern], cwd=repo, env=e, capture_output=True, text=True, encoding="utf-8")
    flag = out.read_text().strip() if out.exists() else None
    return r, flag


def test_only_scripts_changed_skips_with_label(tmp_path):
    r, flag = run(make_repo(tmp_path, ["scripts/ui/a.gd", "docs/x.md"]))
    assert r.returncode == 0 and flag == "run=0"
    assert "SKIPPED_BY_FILTER" in r.stderr


def test_infra_path_runs(tmp_path):
    for f in ["tools/ci/x.py", ".github/workflows/ci.yml", "project.godot", "addons/gut/a.gd", "scripts/ci_helper.gd", "export_presets.cfg"]:
        r, flag = run(make_repo(tmp_path / f.replace("/", "_"), [f]))
        assert flag == "run=1", f
        assert "SKIPPED_BY_FILTER" not in r.stderr


def test_pattern_is_anchored_at_start(tmp_path):
    # 'docs/tools/x.md' tools/ ile BAŞLAMAZ: süzgeci tetiklememeli
    r, flag = run(make_repo(tmp_path, ["docs/tools/x.md"]))
    assert flag == "run=0"


def test_main_and_non_push_events_always_run(tmp_path):
    repo = make_repo(tmp_path, ["scripts/ui/a.gd"])
    assert run(repo, GITHUB_REF="refs/heads/main")[1] == "run=1"
    assert run(repo, GITHUB_EVENT_NAME="workflow_dispatch")[1] == "run=1"
    assert run(repo, GITHUB_EVENT_NAME="schedule")[1] == "run=1"
    assert run(repo, PATH_FILTER_FORCE="1")[1] == "run=1"


def test_diff_failure_means_full_run(tmp_path):
    repo = make_repo(tmp_path, ["scripts/ui/a.gd"])
    git(repo, "update-ref", "-d", "refs/remotes/origin/main")  # taban ref'i yok: diff alınamaz
    r, flag = run(repo)
    assert flag == "run=1" and "TAM KOŞU" in r.stderr


def test_shallow_clone_means_full_run(tmp_path):
    repo = make_repo(tmp_path, ["scripts/ui/a.gd"])
    sh = tmp_path / "shallow"
    subprocess.run(["git", "clone", "-q", "--depth", "1", repo.as_uri(), str(sh)], check=True, capture_output=True)
    git(sh, "update-ref", "refs/remotes/origin/main", "HEAD")
    r, flag = run(sh)
    assert flag == "run=1" and "shallow" in r.stderr


def test_unrelated_history_means_full_run(tmp_path):
    repo = make_repo(tmp_path, ["scripts/ui/a.gd"])
    git(repo, "checkout", "-q", "--orphan", "yetim")
    (repo / "z.txt").write_text("z")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "yetim")
    r, flag = run(repo)
    assert flag == "run=1" and "TAM KOŞU" in r.stderr


def test_missing_pattern_is_usage_error(tmp_path):
    repo = make_repo(tmp_path, ["a.txt"])
    r = subprocess.run(["bash", str(SCRIPT)], cwd=repo, capture_output=True, text=True)
    assert r.returncode == 2
