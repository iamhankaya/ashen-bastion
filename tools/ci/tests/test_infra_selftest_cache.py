"""H1/H2: selftest_gate.sh — taban_yesil süzgeci (SELFTEST_SKIP_TABAN) ve .godot/imported önbelleğinin senaryo kopyasına aktarımı."""
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "selftest_gate.sh"


def mini_repo(tmp_path, gate_body):
    """selftest'in kopyalayacağı sahte depo: yalnız tools/gate.sh (gerçek Godot gerekmez)."""
    repo = tmp_path / "repo"
    (repo / "tools").mkdir(parents=True)
    (repo / "tools" / "gate.sh").write_text("#!/usr/bin/env bash\n" + gate_body, newline="\n")
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True, env=env)
    return repo


def run(repo, scenario, **extra):
    env = {"PATH": os.environ["PATH"], "SELFTEST_ROOT": str(repo)}
    env.update(extra)
    return subprocess.run(["bash", str(SCRIPT), "--scenario", scenario], capture_output=True, text=True, encoding="utf-8", env=env)


def test_skip_taban_skips_only_taban_yesil_and_labels_it(tmp_path):
    repo = mini_repo(tmp_path, "exit 9\n")  # koşsa kırmızı olurdu
    r = run(repo, "taban_yesil", SELFTEST_SKIP_TABAN="1")
    assert r.returncode == 0, r.stdout + r.stderr
    assert "SKIPPED_BY_FILTER" in r.stdout and "taban_yesil" in r.stdout


def test_without_skip_taban_yesil_runs_the_gate(tmp_path):
    repo = mini_repo(tmp_path, "exit 9\n")
    r = run(repo, "taban_yesil")
    assert r.returncode == 1 and "FAIL" in r.stdout  # gate 9 verdi, beklenen 0


def test_negative_scenarios_always_run_even_when_taban_is_skipped(tmp_path):
    repo = mini_repo(tmp_path, "exit 0\n")  # sahte gate yeşil: negatif senaryo (beklenen 1) KIRMIZI olmalı => koştuğunun kanıtı
    r = run(repo, "to_upper", SELFTEST_SKIP_TABAN="1")
    assert r.returncode == 1 and "SKIPPED_BY_FILTER" not in r.stdout


def test_import_cache_is_transferred_into_scenario_copy(tmp_path):
    repo = mini_repo(tmp_path, "[ -f .godot/imported/marker.ctex ] && [ -f .godot/uid_cache.bin ] && exit 0\nexit 9\n")
    godot = tmp_path / "cache_godot"
    (godot / "imported").mkdir(parents=True)
    (godot / "imported" / "marker.ctex").write_text("x")
    (godot / "uid_cache.bin").write_text("u")
    (godot / "global_script_class_cache.cfg").write_text("sinif")  # AKTARILMAMALI
    r = run(repo, "taban_yesil", SELFTEST_GODOT_CACHE=str(godot))
    assert r.returncode == 0, r.stdout + r.stderr


def test_class_cache_is_never_transferred(tmp_path):
    repo = mini_repo(tmp_path, "[ -e .godot/global_script_class_cache.cfg ] && exit 9\nexit 0\n")
    godot = tmp_path / "cache_godot"
    (godot / "imported").mkdir(parents=True)
    (godot / "global_script_class_cache.cfg").write_text("sinif")
    r = run(repo, "taban_yesil", SELFTEST_GODOT_CACHE=str(godot))
    assert r.returncode == 0, r.stdout + r.stderr


def test_no_cache_dir_still_works(tmp_path):
    repo = mini_repo(tmp_path, "[ -d .godot ] && exit 9\nexit 0\n")
    r = run(repo, "taban_yesil", SELFTEST_GODOT_CACHE=str(tmp_path / "yok"))
    assert r.returncode == 0, r.stdout + r.stderr


def test_unknown_scenario_is_usage_error(tmp_path):
    repo = mini_repo(tmp_path, "exit 0\n")
    assert run(repo, "yok_boyle").returncode == 2


# --- F-119: soğuk koşu yavaşlaması. Soğuk selftest işinde her senaryo kopyası --import'u sıfırdan yapıyordu (~60 sn/senaryo) ve iş
# .godot/imported'ı hiç doldurmadığından actions/cache de yazılmıyordu. Düzeltme: önbellek yoksa kökte BİR kez ısınma (SELFTEST_WARMUP_CMD).
def warm_cmd(tmp_path, gc, counter, fail=False):
    c = tmp_path / "warm.sh"
    body = f'echo x >> "{counter.as_posix()}"\n' + ("exit 7\n" if fail else f'mkdir -p "{gc.as_posix()}/imported"; echo m > "{gc.as_posix()}/imported/marker.ctex"; echo u > "{gc.as_posix()}/uid_cache.bin"\n')
    c.write_text("#!/usr/bin/env bash\n" + body, newline="\n")
    return f'bash "{c.as_posix()}"'


MARKER_GATE = "[ -f .godot/imported/marker.ctex ] && exit 0\nexit 9\n"


def test_cold_cache_triggers_one_warmup_and_scenarios_get_the_result(tmp_path):
    repo = mini_repo(tmp_path, MARKER_GATE)
    gc, counter = tmp_path / "gc", tmp_path / "count"
    r = run(repo, "taban_yesil", SELFTEST_GODOT_CACHE=str(gc), SELFTEST_WARMUP_CMD=warm_cmd(tmp_path, gc, counter))
    assert r.returncode == 0, r.stdout + r.stderr
    assert counter.read_text().split() == ["x"]


def test_warm_cache_skips_the_warmup(tmp_path):
    repo = mini_repo(tmp_path, MARKER_GATE)
    gc, counter = tmp_path / "gc", tmp_path / "count"
    (gc / "imported").mkdir(parents=True)
    (gc / "imported" / "marker.ctex").write_text("x")
    r = run(repo, "taban_yesil", SELFTEST_GODOT_CACHE=str(gc), SELFTEST_WARMUP_CMD=warm_cmd(tmp_path, gc, counter))
    assert r.returncode == 0, r.stdout + r.stderr
    assert not counter.exists(), "önbellek sıcakken ısınma koşmamalı"


def test_warmup_failure_is_not_fatal_and_is_reported(tmp_path):
    repo = mini_repo(tmp_path, "exit 0\n")
    gc, counter = tmp_path / "gc", tmp_path / "count"
    r = run(repo, "taban_yesil", SELFTEST_GODOT_CACHE=str(gc), SELFTEST_WARMUP_CMD=warm_cmd(tmp_path, gc, counter, fail=True))
    assert r.returncode == 0, r.stdout + r.stderr  # senaryolar kendi import'larını yapar; ısınma yalnız hızlandırıcı
    assert "ısınma" in r.stdout + r.stderr


def test_list_never_warms_up(tmp_path):
    repo = mini_repo(tmp_path, "exit 0\n")
    gc, counter = tmp_path / "gc", tmp_path / "count"
    env = {"PATH": os.environ["PATH"], "SELFTEST_ROOT": str(repo), "SELFTEST_GODOT_CACHE": str(gc), "SELFTEST_WARMUP_CMD": warm_cmd(tmp_path, gc, counter)}
    r = subprocess.run(["bash", str(SCRIPT), "--list"], capture_output=True, text=True, encoding="utf-8", env=env)
    assert r.returncode == 0 and not counter.exists()
