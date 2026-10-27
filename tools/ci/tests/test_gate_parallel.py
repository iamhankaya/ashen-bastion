"""F-066: yerel tam gate GUT parçalarını paralel süreçlerde koşar (tools/ci/run_gut_parallel.sh); kapsam kanıtı aynı kalır.

Gerçek Godot yerine sahte ikili kullanılır: -gconfig dosyasındaki `tests` listesinden JUnit üretir, ortamı kaydeder.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "run_gut_parallel.sh"
GATE = (ROOT / "tools" / "gate.sh").read_text(encoding="utf-8")

FAKE_GODOT = r"""#!/usr/bin/env bash
# Sahte Godot: --version ve GUT koşusu. FAKE_FAIL_SHARD=K -> o parça çıkış 1; FAKE_SKIP_JUNIT=K -> o parça JUnit yazmaz; FAKE_BARRIER=N -> bariyer.
for a in "$@"; do case "$a" in -gconfig=*) CFG="${a#-gconfig=res://}" ;; esac; done
[ -n "${CFG:-}" ] || { echo "--version"; exit 0; }
K="$(basename "$CFG" .json | sed 's/gutconfig-//')"
echo "XDG=$XDG_DATA_HOME" > "$FAKE_OUT/xdg-$K.txt"
if [ -n "${FAKE_BARRIER:-}" ]; then  # eşzamanlılık bariyeri: FAKE_BARRIER=N parçanın hepsi başlayana dek bekle (en çok ~30 sn)
  touch "$FAKE_OUT/start-$K"
  for _ in $(seq 1 300); do [ "$(ls "$FAKE_OUT" | grep -c '^start-')" -ge "$FAKE_BARRIER" ] && break; sleep 0.1; done
  [ "$(ls "$FAKE_OUT" | grep -c '^start-')" -ge "$FAKE_BARRIER" ] || { echo "bariyer: parçalar eşzamanlı değil"; exit 1; }
fi
"$PYTHON" - "$CFG" "$K" <<'PY'
import json, sys, os
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
if os.environ.get("FAKE_SKIP_JUNIT") == sys.argv[2]:
    sys.exit(0)
out = cfg["junit_xml_file"].removeprefix("res://")
body = "".join(f'<testsuite name="{t.removeprefix("res://")}" tests="1" failures="0" errors="0"><testcase classname="c" name="t" time="0.1"/></testsuite>' for t in cfg["tests"])
open(out, "w", encoding="utf-8").write(f'<?xml version="1.0"?><testsuites>{body}</testsuites>')
PY
[ "${FAKE_FAIL_SHARD:-}" = "$K" ] && { echo "[Failed]: sahte"; exit 1; }
exit 0
"""


@pytest.fixture
def env(tmp_path):
    gate_dir = f".gate/_ptest_{os.getpid()}"
    full = ROOT / gate_dir
    full.mkdir(parents=True, exist_ok=True)
    fake = tmp_path / "godot"
    fake.write_text(FAKE_GODOT, encoding="utf-8", newline="\n")
    fake.chmod(0o755)
    out = tmp_path / "out"
    out.mkdir()
    e = dict(os.environ, GODOT_BIN=str(fake), PYTHON=sys.executable, GATE_DIR=gate_dir, FAKE_OUT=str(out))
    yield e, full, out
    shutil.rmtree(full, ignore_errors=True)


def run(e, jobs, **extra):
    return subprocess.run(["bash", str(SCRIPT), str(jobs)], cwd=ROOT, env=dict(e, **extra), capture_output=True, text=True, encoding="utf-8")


def test_all_shards_run_merge_and_cover_everything(env):
    e, gdir, out = env
    r = run(e, 4)
    assert r.returncode == 0, r.stdout + r.stderr
    for k in range(1, 5):
        assert (gdir / f"junit-{k}.xml").is_file()
    merged = (gdir / "junit.xml").read_text(encoding="utf-8")
    sys.path.insert(0, str(ROOT / "tools" / "ci"))
    import shard  # noqa: PLC0415

    for f in shard.discover():
        assert f'name="{f}"' in merged, f"{f} birleşik JUnit'te yok"
    assert (gdir / "gut.log").is_file()


def test_each_shard_gets_its_own_user_dir(env):
    # user:// sızıntı denetimi taban/son karşılaştırır: ortak dizinde bir parçanın geçici dosyası diğerinde sızıntı görünür.
    e, _, out = env
    assert run(e, 3).returncode == 0
    dirs = {(out / f"xdg-{k}.txt").read_text(encoding="utf-8").strip() for k in (1, 2, 3)}
    assert len(dirs) == 3 and all(d.startswith("XDG=") and d != "XDG=" for d in dirs)


def test_failing_shard_fails_and_names_shard(env):
    e, gdir, _ = env
    r = run(e, 4, FAKE_FAIL_SHARD="2")
    assert r.returncode == 1
    assert "parça 2/4" in r.stderr
    assert not (gdir / "junit.xml").exists(), "kırmızı koşuda birleşik JUnit üretilmez"


def test_missing_junit_is_red_not_green(env):
    e, _, _ = env
    r = run(e, 4, FAKE_SKIP_JUNIT="3")
    assert r.returncode == 1
    assert "parça 3/4" in r.stderr


def test_user_leak_in_any_shard_log_is_red(env):
    e, _, _ = env
    e2 = dict(e, FAKE_LEAK="1")
    # sahte ikili başarı kodu verip günlüğe USER_LEAK yazarsa (gerçek kanca da böyle yapar) kırmızı olmalı
    fake = Path(e["GODOT_BIN"])
    fake.write_text(fake.read_text(encoding="utf-8").replace('echo "XDG=', 'echo "USER_LEAK: x.json"; echo "XDG=', 1), encoding="utf-8", newline="\n")
    r = run(e2, 2)
    assert r.returncode == 1 and "USER_LEAK" in (r.stdout + r.stderr)


def test_shards_really_overlap(env):
    # Süre ölçmeden eşzamanlılık kanıtı: sahte Godot, diğer tüm parçalar başlayana dek bekler (bariyer). Seri koşan bir
    # çalıştırıcıda ilk parça bariyerde zaman aşımına düşer ve çıkış 1 olur.
    e, _, _ = env
    assert run(e, 4, FAKE_BARRIER="4").returncode == 0


def test_gate_sh_uses_parallel_runner_for_full_local_gate():
    assert "tools/ci/run_gut_parallel.sh" in GATE
    assert "GATE_JOBS" in GATE
    # adım 6 adı ve CI parçaları (GATE_PART=gut) değişmez; GATE_JOBS=1 eski tek süreç yolunu korur
    assert 'step "6. Birim + kabul (GUT)"' in GATE
    assert 'GATE_PART=gut' in GATE


def test_gate_jobs_validated():
    r = subprocess.run(["bash", "tools/gate.sh"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", env=dict(os.environ, GATE_JOBS="abc"))
    assert r.returncode == 2 and "GATE_JOBS" in r.stderr


def test_check_dirs_rejects_missing_gutconfig_dir(tmp_path):
    # selftest "GUT ERROR": .gutconfig.json'a olmayan dizin eklenir. Tek süreçte GUT [GUT ERROR] yazar; parçalı yolda dirs
    # boşaltıldığı için o hata oluşmaz, bu yüzden parçalamadan önce açıkça denetlenir.
    cfg = tmp_path / "gutconfig.json"
    cfg.write_text(json.dumps({"dirs": ["res://test/unit", "res://test/yok_boyle_dizin"]}), encoding="utf-8")
    tool = ROOT / "tools" / "ci" / "shard.py"
    r = subprocess.run([sys.executable, str(tool), "check-dirs", str(cfg)], capture_output=True, text=True, encoding="utf-8")
    assert r.returncode == 1 and "yok_boyle_dizin" in r.stderr
    cfg.write_text(json.dumps({"dirs": ["res://test/unit", "res://test/acceptance"]}), encoding="utf-8")
    r = subprocess.run([sys.executable, str(tool), "check-dirs", str(cfg)], capture_output=True, text=True, encoding="utf-8")
    assert r.returncode == 0, r.stderr


def test_runner_and_gut_part_check_dirs():
    assert "shard.py check-dirs" in SCRIPT.read_text(encoding="utf-8")
    assert "shard.py check-dirs" in GATE
