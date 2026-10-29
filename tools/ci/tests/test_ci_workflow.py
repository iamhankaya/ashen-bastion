"""F-044: ci.yml tam kapsamı bölerek koşar; hızlı mod CI'da yoktur; parça sayıları tutarlıdır."""

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parents[3]
CI = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
GATE = (ROOT / "tools" / "gate.sh").read_text(encoding="utf-8")


def block(job: str) -> str:
    start = CI.index(f"\n  {job}:\n") + 1
    body = start + len(f"  {job}:\n")
    nxt = re.search(r"^  [\w-]+:[ \t]*$", CI[body:], re.M)
    return CI[start:body + nxt.start()] if nxt else CI[start:]


def code_lines(text: str) -> str:
    return "\n".join(l for l in text.splitlines() if not l.strip().startswith("#"))


def test_ci_runs_on_push_and_pull_request():
    head = CI.split("jobs:")[0]
    assert re.search(r"^\s*push:", head, re.M) and re.search(r"^\s*pull_request:", head, re.M)


def test_ci_never_uses_fast_mode():
    assert "--changed" not in code_lines(CI), "hızlı mod CI'da kullanılamaz: PR/merge/son kapı tam suite"
    assert "GATE_BASE" not in code_lines(CI)


def test_gate_refuses_fast_mode_in_ci():
    r = subprocess.run(
        ["bash", "tools/gate.sh", "--changed"], cwd=ROOT, capture_output=True, text=True, env={"PATH": "/usr/bin:/bin", "CI": "true"}
    )
    assert r.returncode == 2 and "CI'DA YASAK" in r.stderr
    r = subprocess.run(
        ["bash", "tools/gate.sh", "--changed"], cwd=ROOT, capture_output=True, text=True, env={"PATH": "/usr/bin:/bin", "GITHUB_ACTIONS": "true"}
    )
    assert r.returncode == 2 and "CI'DA YASAK" in r.stderr


def test_shard_count_is_consistent_everywhere():
    gut = block("gut")
    shards = [int(x) for x in re.search(r"shard:\s*\[([\d,\s]+)\]", gut).group(1).split(",")]
    n = len(shards)
    assert shards == list(range(1, n + 1))
    assert f"/{n} bash tools/gate.sh" in gut
    assert f"GATE_SHARD_COUNT={n} " in block("test")
    assert f"gut-junit-${{{{ matrix.shard }}}}" in gut
    from test_shard import SHARD_COUNT  # noqa: PLC0415 (aynı dizin; pytest rootdir)

    assert SHARD_COUNT == n


def test_test_job_gates_on_static_and_all_gut_shards():
    t = block("test")
    assert re.search(r"needs:\s*\[static,\s*gut\]", t)
    assert "GATE_PART=verify" in t and "gut-junit-*" in t
    assert "GATE_PART=static" in block("static")


def test_parts_cover_full_gate_steps():
    # birleşim: static (1-5) + gut (6) + verify (7) = tam gate adımları
    for needle in ('step "3. Lint"', 'step "4. Veri doğrulama"', 'step "5. Python testleri"', 'step "6. Birim + kabul (GUT)"',
                   'step "7. Sahte yeşil korumaları"'):
        assert needle in GATE
    assert 'if [ "$PART" = "all" ] || [ "$PART" = "static" ]; then\n  step "3. Lint"' in GATE
    assert '[ "$PART" != "static" ] && [ "$PART" != "verify" ]' in GATE  # adım 6 yalnız all/gut
    assert 'if [ $FAST -eq 0 ] && { [ "$PART" = "all" ] || [ "$PART" = "verify" ]; }; then\n  step "7.' in GATE


def test_gate_ok_only_on_full_gate():
    assert GATE.count('echo "GATE OK"') == 1
    assert 'elif [ "$PART" = "all" ]; then\n  echo "GATE OK"' in GATE
    assert "GATE_FAST OK (KISMİ" in GATE
    assert not re.search(r"GATE OK.*--changed", GATE.split("GATE_FAST OK")[0].split("elif")[-1])


def test_dependencies_pinned_and_cached():
    req = (ROOT / "tools/ci/requirements-ci.txt").read_text()
    pkgs = [l for l in req.splitlines() if l and not l.startswith("#")]
    assert pkgs and all("==" in l for l in pkgs), "bağımlılık sürümleri sabit olmalı"
    assert "pip install -r tools/ci/requirements-ci.txt" in CI
    assert "cache: pip" in CI
    assert "restore-keys" not in code_lines(CI)  # .godot önbelleği yalnız tam eşleşen anahtarla


def test_gate_refuses_stdin_execution_and_leaves_parent_untouched(tmp_path):
    # `bash -s < gate.sh` iken $0='bash': eski betik üst dizine çıkıp orada `.gate` oluşturur/siler (F-044 provası)
    repo = tmp_path / "parent" / "repo"
    (repo / "tools").mkdir(parents=True)
    (repo / "tools" / "gate.sh").write_text(GATE, encoding="utf-8")
    with open(repo / "tools" / "gate.sh", "rb") as fh:
        r = subprocess.run(["bash", "-s"], stdin=fh, cwd=repo, capture_output=True, text=True, env={"PATH": "/usr/bin:/bin"})
    assert r.returncode == 2 and "bash -s" in r.stderr
    assert not (tmp_path / "parent" / ".gate").exists() and not (repo / ".gate").exists()
