"""A0: tools/ci/run_checks.sh (gate.sh adım 0) `checks.d/NN-ad.sh` kancası; sözleşme fazları gate.sh'e dokunmadan denetim ekler."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "tools" / "ci" / "run_checks.sh"
GATE = (ROOT / "tools" / "gate.sh").read_text(encoding="utf-8")


def run(tmp_path, scripts):
    d = tmp_path / "checks.d"
    d.mkdir()
    for name, body in scripts.items():
        (d / name).write_text("#!/usr/bin/env bash\n" + body, encoding="utf-8", newline="\n")  # çalıştırma biti verilmez
    return subprocess.run(["bash", str(RUNNER), str(d)], capture_output=True, text=True)


def test_runs_scripts_in_name_order(tmp_path):
    log = tmp_path / "log"
    r = run(tmp_path, {"20-b.sh": f'echo B >> "{log.as_posix()}"\n', "10-a.sh": f'echo A >> "{log.as_posix()}"\n'})
    assert r.returncode == 0, r.stderr
    assert log.read_text().split() == ["A", "B"]


def test_violation_is_red_names_the_check_and_stops(tmp_path):
    log = tmp_path / "log"
    r = run(tmp_path, {"10-ok.sh": "exit 0\n", "20-bad.sh": "echo ihlal >&2; exit 7\n", "30-never.sh": f'echo X > "{log.as_posix()}"\n'})
    assert r.returncode == 7
    assert "CHECK FAIL" in r.stderr and "20-bad.sh" in r.stderr and "ihlal" in r.stderr
    assert not log.exists(), "ilk kırmızıdan sonra betik koşmamalı"


def test_empty_dir_is_green_missing_dir_is_usage_error(tmp_path):
    assert run(tmp_path, {}).returncode == 0
    r = subprocess.run(["bash", str(RUNNER), str(tmp_path / "yok")], capture_output=True, text=True)
    assert r.returncode == 2


def test_gate_calls_hook_before_godot_only_for_static_and_all():
    guard = 'if [ "$PART" = "all" ] || [ "$PART" = "static" ]; then' + chr(10) + '  if compgen -G "tools/ci/checks.d/*.sh"'
    assert guard in GATE
    assert "bash tools/ci/run_checks.sh tools/ci/checks.d || fail" in GATE
    assert GATE.index("run_checks.sh") < GATE.index('step "1. Godot kurulumu"')


def test_gate_goes_red_at_step_0_on_deliberate_violation(tmp_path):
    # Uçtan uca: gate.sh'in kendisi, Godot'a varmadan kanca ihlalinde kırmızı (kabul: kasıtlı ihlalde kırmızı)
    import os
    import shutil

    repo = tmp_path / "repo"
    (repo / "tools" / "ci" / "checks.d").mkdir(parents=True)
    shutil.copy(ROOT / "tools" / "gate.sh", repo / "tools" / "gate.sh")
    shutil.copy(RUNNER, repo / "tools" / "ci" / "run_checks.sh")
    (repo / "tools" / "ci" / "checks.d" / "10-ihlal.sh").write_text("echo KASITLI_IHLAL >&2; exit 1\n", newline="\n")
    r = subprocess.run(["bash", "tools/gate.sh"], cwd=repo, capture_output=True, text=True,
                       env={"PATH": os.environ["PATH"], "GATE_PART": "static"})
    assert r.returncode == 1
    assert "KASITLI_IHLAL" in r.stderr and "ön denetim kırmızı" in r.stderr
    assert "ensure_godot" not in r.stderr  # Godot kurulumuna hiç gelinmedi
