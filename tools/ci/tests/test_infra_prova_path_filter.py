"""CI provası: yol süzgeci GERÇEK ci.yml desenleriyle (T20261028-33 prova fazı). Desenler workflow'dan okunur; sapma olursa test de görür.
Yalnız scripts/ değişince taban_yesil atlanır, tools/ ve .github/ değişince koşar; main/olay dışı/shallow/ref yok/ortak ata yok => tam koşu;
negatif selftest senaryoları süzgeçten etkilenmez (SELFTEST_SKIP_TABAN yalnız taban_yesil'de)."""
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "path_filter.sh"
BASH = shutil.which("bash")
CI = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
PATTERNS = re.findall(r"path_filter\.sh '([^']+)'", CI)
pytestmark = pytest.mark.skipif(BASH is None, reason="bash yok")


def sh(cwd, *cmd, env=None):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")


def commit(repo, msg="c"):
    sh(repo, "git", "add", "-A")
    r = sh(repo, "git", "-c", "user.email=t@example.invalid", "-c", "user.name=t", "commit", "-q", "-m", msg)
    assert r.returncode == 0, r.stderr


def decision(repo, pattern, **env):
    e = {**os.environ, "GITHUB_EVENT_NAME": "push", "GITHUB_REF": "refs/heads/vlad/x"}
    e.pop("GITHUB_OUTPUT", None)
    e.pop("GITHUB_STEP_SUMMARY", None)
    e.update(env)
    r = sh(repo, BASH, str(SCRIPT), pattern, env=e)
    assert r.returncode == 0, r.stderr
    return r.stdout.strip(), r.stderr


@pytest.fixture(scope="module")
def repo(tmp_path_factory):
    """Gerçek ağacın hafif kopyası: yalnız yol adları önemli (içerik gerekmez) -> küçük depo, taban `origin/main`."""
    r = tmp_path_factory.mktemp("pf")
    sh(r, "git", "init", "-q", "-b", "main")
    for p in ("scripts/ui/a.gd", "tools/ci/x.sh", ".github/workflows/ci.yml", "project.godot", "README.md"):
        (r / p).parent.mkdir(parents=True, exist_ok=True)
        (r / p).write_text("x\n")
    commit(r, "base")
    sh(r, "git", "update-ref", "refs/remotes/origin/main", "HEAD")
    return r


def branch(repo, name, path):
    sh(repo, "git", "checkout", "-q", "-B", name, "origin/main")
    p = repo / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(p.read_text() + "y\n" if p.exists() else "y\n")
    commit(repo, name)


def test_patterns_are_read_from_the_workflow():
    assert len(PATTERNS) == 3, PATTERNS  # taban_yesil, export-debug, release-prova


def test_scripts_only_change_skips_every_filtered_job(repo):
    branch(repo, "b_scripts", "scripts/ui/a.gd")
    for pat in PATTERNS:
        out, err = decision(repo, pat)
        assert out == "run=0", (pat, err)
        assert "SKIPPED_BY_FILTER" in err


def test_tools_change_runs_taban_but_not_export_or_release_unless_matching(repo):
    branch(repo, "b_tools", "tools/ci/x.sh")
    taban, export, release = PATTERNS
    assert decision(repo, taban)[0] == "run=1"
    assert decision(repo, export)[0] == "run=0"  # tools/ci/x.sh export_/ensure_/write_editor değil
    assert decision(repo, release)[0] == "run=0"


def test_workflow_change_runs_all_three(repo):
    branch(repo, "b_wf", ".github/workflows/ci.yml")
    for pat in PATTERNS:
        assert decision(repo, pat)[0] == "run=1", pat


def test_project_godot_runs_taban_and_export(repo):
    branch(repo, "b_pg", "project.godot")
    taban, export, release = PATTERNS
    assert decision(repo, taban)[0] == "run=1" and decision(repo, export)[0] == "run=1"


def test_main_and_non_push_events_always_run_full(repo):
    branch(repo, "b_scripts2", "scripts/ui/a.gd")
    for pat in PATTERNS:
        assert decision(repo, pat, GITHUB_REF="refs/heads/main")[0] == "run=1"
        for ev in ("workflow_dispatch", "schedule", "workflow_call"):
            assert decision(repo, pat, GITHUB_EVENT_NAME=ev)[0] == "run=1", (pat, ev)
        assert decision(repo, pat, PATH_FILTER_FORCE="1")[0] == "run=1"


def test_missing_base_ref_or_no_common_ancestor_or_shallow_runs_full(repo, tmp_path):
    branch(repo, "b_scripts3", "scripts/ui/a.gd")
    taban = PATTERNS[0]
    assert decision(repo, taban, PATH_FILTER_BASE="origin/yok")[0] == "run=1"  # yeni dal / taban ref'i yok
    sh(repo, "git", "checkout", "-q", "--orphan", "yetim")
    sh(repo, "git", "rm", "-rfq", ".")
    (repo / "z.txt").write_text("z\n")
    commit(repo, "orphan")
    assert decision(repo, taban)[0] == "run=1"  # ortak ata yok
    shallow = tmp_path / "sh"
    r = sh(tmp_path, "git", "clone", "-q", "--depth", "1", "--branch", "b_scripts3", repo.as_uri(), str(shallow))
    assert r.returncode == 0, r.stderr
    sh(shallow, "git", "update-ref", "refs/remotes/origin/main", "HEAD")
    assert decision(shallow, taban)[0] == "run=1"  # shallow klon: diff güvenilmez


def test_negative_selftest_scenarios_are_never_filtered():
    """SELFTEST_SKIP_TABAN yalnız taban_yesil senaryosunda okunur; bozuk_gd, bos_test_dizisi vb. her zaman koşar."""
    text = (ROOT / "tools" / "ci" / "selftest_gate.sh").read_text(encoding="utf-8")
    lines = [i for i, l in enumerate(text.splitlines(), 1) if "SELFTEST_SKIP_TABAN" in l and not l.lstrip().startswith("#")]
    body = text.split("scenario_taban_yesil() {", 1)[1].split("\n}", 1)[0]
    assert body.count("SELFTEST_SKIP_TABAN") == 1
    assert len(lines) == 1, f"SELFTEST_SKIP_TABAN başka yerde de okunuyor: satırlar {lines}"
