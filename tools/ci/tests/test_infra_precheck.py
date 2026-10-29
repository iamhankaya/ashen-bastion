"""Altyapı-B: tools/precheck.sh sınıfları. Her kırmızı sınıf için kasıtlı ihlal -> ilgili `PRECHECK_FAIL: <sınıf>` etiketi.

Gerçek depoya dokunulmaz: her test geçici bir git deposunda precheck.sh'nin KOPYASIYLA koşar (betik kendi konumundan
depo kökünü bulur). Zamana/saate bağlı iddia yok.
"""

import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
PRECHECK = ROOT / "tools" / "precheck.sh"
BASH = shutil.which("bash")

pytestmark = pytest.mark.skipif(BASH is None, reason="bash yok")


def sh(cmd, cwd, env=None, **kw):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", **kw)


def git(repo, *args):
    r = sh(["git", *args], repo)
    assert r.returncode == 0, r.stderr
    return r.stdout


@pytest.fixture
def repo(tmp_path):
    """Geçici depo: tools/precheck.sh kopyası + tek commit; `main` dalı taban."""
    r = tmp_path / "repo"
    (r / "tools").mkdir(parents=True)
    shutil.copy(PRECHECK, r / "tools" / "precheck.sh")
    git(r, "init", "-q", "-b", "main")
    git(r, "config", "user.email", "t@example.invalid")
    git(r, "config", "user.name", "t")
    git(r, "config", "core.autocrlf", "false")
    git(r, "add", "-A")
    git(r, "update-index", "--chmod=+x", "tools/precheck.sh")
    git(r, "commit", "-q", "-m", "base")
    git(r, "checkout", "-q", "-b", "work")
    return r


def clean_env(tmp_path, extra_path=None):
    """Araç bulunmayan PATH: gdformat/gdlint/godot düşmanca ortamda yok sayılır; bash+git+python kalır."""
    env = dict(os.environ)
    env.pop("GODOT_BIN", None)
    if extra_path:
        env["PATH"] = str(extra_path) + os.pathsep + env["PATH"]
    return env


def run(repo, *args, env=None, tmp_path=None):
    return sh([BASH, "tools/precheck.sh", *args], repo, env=env or clean_env(tmp_path))


def commit_all(repo, msg="c", chmod_x=()):
    git(repo, "add", "-A")
    for p in chmod_x:
        git(repo, "update-index", "--chmod=+x", p)
    git(repo, "commit", "-q", "-m", msg)


def test_clean_repo_passes(repo, tmp_path):
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr
    assert "PRECHECK_FAIL" not in r.stderr


def test_sh_mode_must_be_executable(repo, tmp_path):
    (repo / "tools" / "x.sh").write_text("#!/usr/bin/env bash\ntrue\n")
    commit_all(repo)  # 100644
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 1
    assert "PRECHECK_FAIL: SH_MODE: tools/x.sh" in r.stderr


def test_sh_mode_ok_when_100755(repo, tmp_path):
    (repo / "tools" / "x.sh").write_text("#!/usr/bin/env bash\ntrue\n")
    commit_all(repo, chmod_x=["tools/x.sh"])
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr


def test_to_upper_forbidden(repo, tmp_path):
    d = repo / "scripts"
    d.mkdir()
    (d / "a.gd").write_text("extends RefCounted\n\n\nfunc f(s: String) -> String:\n\treturn s.to_upper()\n")
    commit_all(repo)
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 1
    assert "PRECHECK_FAIL: UPPER_LOWER: scripts/a.gd" in r.stderr


def test_to_lower_untracked_file_also_caught(repo, tmp_path):
    d = repo / "test"
    d.mkdir()
    (d / "test_a.gd").write_text("func f(s):\n\treturn s.to_lower()\n")  # commit'lenmedi
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 1
    assert "PRECHECK_FAIL: UPPER_LOWER: test/test_a.gd" in r.stderr


def test_unchanged_gd_not_scanned(repo, tmp_path):
    """Yalnız değişen dosyalar: tabandaki eski ihlal bu dalın işi değildir (tam kapı yakalar)."""
    (repo / "scripts").mkdir()
    (repo / "scripts" / "old.gd").write_text("func f(s):\n\treturn s.to_upper()\n")
    git(repo, "checkout", "-q", "main")
    commit_all(repo, "old")
    git(repo, "checkout", "-q", "-b", "work2")
    (repo / "README.md").write_text("x\n")
    commit_all(repo)
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr


def fake_tool(bindir, name, rc, msg=""):
    bindir.mkdir(exist_ok=True)
    p = bindir / name
    p.write_text(f"#!/usr/bin/env bash\necho '{msg}' >&2\nexit {rc}\n")
    p.chmod(p.stat().st_mode | stat.S_IEXEC)
    return bindir


def test_missing_gdformat_is_skipped_loudly_not_green_silently(repo, tmp_path):
    (repo / "scripts").mkdir()
    (repo / "scripts" / "a.gd").write_text("extends RefCounted\n")
    commit_all(repo)
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    if shutil.which("gdformat"):
        pytest.skip("gdformat kurulu; atlama yolu bu makinede denenemez")
    assert r.returncode == 0, r.stderr
    assert "PRECHECK_SKIP: GDFORMAT" in r.stderr
    assert "PRECHECK_SKIP: GDLINT" in r.stderr


def test_gdformat_failure_is_red(repo, tmp_path):
    (repo / "scripts").mkdir()
    (repo / "scripts" / "a.gd").write_text("extends RefCounted\n")
    commit_all(repo)
    bindir = fake_tool(tmp_path / "bin", "gdformat", 1, "would reformat")
    fake_tool(bindir, "gdlint", 0)
    r = run(repo, "--base", "main", env=clean_env(tmp_path, bindir))
    assert r.returncode == 1
    assert "PRECHECK_FAIL: GDFORMAT" in r.stderr


def test_gdlint_failure_is_red(repo, tmp_path):
    (repo / "scripts").mkdir()
    (repo / "scripts" / "a.gd").write_text("extends RefCounted\n")
    commit_all(repo)
    bindir = fake_tool(tmp_path / "bin", "gdformat", 0)
    fake_tool(bindir, "gdlint", 1, "problem")
    r = run(repo, "--base", "main", env=clean_env(tmp_path, bindir))
    assert r.returncode == 1
    assert "PRECHECK_FAIL: GDLINT" in r.stderr


@pytest.mark.parametrize(
    "script,label",
    [
        ("check_line_budget.py", "LINE_BUDGET"),
        ("check_ui_rules.py", "UI_RULES"),
        ("check_layers.py", "LAYERS"),
        ("check_test_ids.py", "TEST_IDS"),
    ],
)
def test_check_tools_failure_maps_to_label(repo, tmp_path, script, label):
    ci = repo / "tools" / "ci"
    ci.mkdir()
    (ci / script).write_text("import sys\nprint('ihlal', file=sys.stderr)\nsys.exit(1)\n")
    commit_all(repo)
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 1
    assert f"PRECHECK_FAIL: {label}" in r.stderr


def test_absent_check_tools_are_skipped_with_notice(repo, tmp_path):
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr
    for label in ("LINE_BUDGET", "UI_RULES", "LAYERS", "TEST_IDS"):
        assert f"PRECHECK_SKIP: {label}" in r.stderr


def test_test_ids_runs_in_static_mode(repo, tmp_path):
    ci = repo / "tools" / "ci"
    ci.mkdir()
    (ci / "check_test_ids.py").write_text(
        "import sys\nsys.exit(0 if sys.argv[1:3] == ['--mode', 'static'] else 1)\n"
    )
    commit_all(repo)
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr


def test_stdin_execution_is_refused(repo, tmp_path):
    """`bash -s < precheck.sh`: $0 = bash; betik kendi konumunu bulamaz -> açık hata, üst dizine taşmaz."""
    with open(repo / "tools" / "precheck.sh", "rb") as f:
        r = subprocess.run([BASH, "-s"], stdin=f, cwd=repo, capture_output=True, text=True, encoding="utf-8", env=clean_env(tmp_path))
    assert r.returncode == 2
    assert "dosya olarak" in r.stderr


def test_unknown_argument_is_usage_error(repo, tmp_path):
    r = run(repo, "--nope", tmp_path=tmp_path)
    assert r.returncode == 2
    assert "kullanım" in r.stderr


def test_restrictive_umask_leaves_no_unreadable_artifacts(repo, tmp_path):
    r = sh(["bash", "-c", "umask 077; bash tools/precheck.sh --base main"], repo, env=clean_env(tmp_path))
    assert r.returncode == 0, r.stderr


def test_godot_without_binary_is_red_not_green(repo, tmp_path):
    r = run(repo, "--godot", "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 1
    assert "PRECHECK_FAIL: GODOT" in r.stderr


def test_script_does_not_use_grep_q_in_pipelines():
    """pipefail + grep -q: üretici SIGPIPE (141) alır, boru hattı yanlış kırmızı verir."""
    src = PRECHECK.read_text(encoding="utf-8")
    for line in src.splitlines():
        s = line.strip()
        if s.startswith("#"):
            continue
        assert not ("|" in s and "grep -q" in s and "||" not in s.split("grep -q")[0]), f"boru hattında grep -q: {s}"


def test_script_is_executable_in_index():
    # selftest_gate.sh senaryo dizini git'siz kopyadır (izlenen dosyaları kopyalar): orada indeks yok, kip denetlenemez.
    if sh(["git", "rev-parse", "--is-inside-work-tree"], ROOT).returncode != 0 or not (ROOT / ".git").exists():
        pytest.skip("git deposu değil (selftest kopyası)")
    r = sh(["git", "ls-files", "-s", "tools/precheck.sh"], ROOT)
    assert r.stdout.startswith("100755"), r.stdout


def test_test_map_without_ensure_command_uses_check_even_if_word_appears(repo, tmp_path):
    """Gerçek test_map.py'de 'ensure_ascii' geçer; bu 'ensure' komutu var demek değildir (yerel Godot denemesinde yakalandı)."""
    ci = repo / "tools" / "ci"
    ci.mkdir()
    (ci / "test_map.py").write_text(
        "import sys, json\njson.dumps({}, ensure_ascii=False)\n"
        "sys.exit(0 if sys.argv[1] == 'check' else 1)\n"
    )
    commit_all(repo)
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr


def test_test_map_with_ensure_command_uses_ensure(repo, tmp_path):
    ci = repo / "tools" / "ci"
    ci.mkdir()
    (ci / "test_map.py").write_text(
        'import sys\ncmd = sys.argv[1]\nif cmd == "ensure":\n    sys.exit(0)\nsys.exit(1)\n'
    )
    commit_all(repo)
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr


def _base_with_old_violation(repo):
    (repo / "scripts").mkdir()
    (repo / "scripts" / "old.gd").write_text("func f(s):\n\treturn s.to_upper()\n\n\nfunc g():\n\treturn 1\n")
    git(repo, "checkout", "-q", "main")
    commit_all(repo, "old")
    git(repo, "checkout", "-q", "-b", "work2")


def test_f131_touching_file_with_old_violation_elsewhere_is_not_red(repo, tmp_path):
    """F-131: dosyada TABANDAN kalan to_upper, başka satır değişince kırmızı vermez (gate.sh de yalnız yeni ihlali kırar)."""
    _base_with_old_violation(repo)
    p = repo / "scripts" / "old.gd"
    p.write_text(p.read_text().replace("return 1", "return 2"))
    commit_all(repo)
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr
    assert "UPPER_LOWER" not in r.stderr


def test_f131_added_violation_line_in_old_file_is_red(repo, tmp_path):
    _base_with_old_violation(repo)
    p = repo / "scripts" / "old.gd"
    p.write_text(p.read_text() + "\n\nfunc h(s):\n\treturn s.to_lower()\n")
    commit_all(repo)
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 1
    assert "PRECHECK_FAIL: UPPER_LOWER: scripts/old.gd" in r.stderr


GUARD = ROOT / "tools" / "ci" / "tests" / "test_rf_baseline_guard.py"


def _with_guard(repo):
    d = repo / "tools" / "ci" / "tests"
    d.mkdir(parents=True)
    shutil.copy(GUARD, d / "test_rf_baseline_guard.py")
    (repo / "tools" / "ci" / "baseline_changes.txt").write_text("# kayıt\n", encoding="utf-8")
    commit_all(repo, "guard")
    git(repo, "checkout", "-q", "main")
    git(repo, "merge", "-q", "work")
    git(repo, "checkout", "-q", "-b", "work3")


def test_baseline_change_without_record_is_red_even_where_pytest_class_is_skipped(repo, tmp_path):
    """Prova bulgusu: Windows'ta PYTEST sınıfı atlandığından BASELINE_CHANGED yerelde hiç görünmüyordu."""
    _with_guard(repo)
    b = repo / "test" / "characterization" / "baseline"
    b.mkdir(parents=True)
    (b / "x.json").write_text('{"a": 1}\n', encoding="utf-8")
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 1
    assert "PRECHECK_FAIL: BASELINE:" in r.stderr and "BASELINE_CHANGED" in r.stderr


def test_baseline_change_with_matching_record_is_green(repo, tmp_path):
    import hashlib
    _with_guard(repo)
    b = repo / "test" / "characterization" / "baseline"
    b.mkdir(parents=True)
    body = b'{"a": 1}\n'
    (b / "x.json").write_bytes(body)
    sha = hashlib.sha256(body).hexdigest()
    with open(repo / "tools" / "ci" / "baseline_changes.txt", "a", encoding="utf-8", newline="\n") as f:
        f.write(f"test/characterization/baseline/x.json | {sha} | prova | T-test\n")
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr


def test_baseline_guard_not_run_when_baseline_untouched(repo, tmp_path):
    _with_guard(repo)
    (repo / "README.md").write_text("x\n")
    r = run(repo, "--base", "main", tmp_path=tmp_path)
    assert r.returncode == 0, r.stderr
    assert "BASELINE" not in r.stderr
