"""F-044: GUT parçalama — her test dosyası tam bir parçada, birleşim = tüm dosyalar, atama deterministik."""

import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import shard  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SHARD_COUNT = 4  # ci.yml gut matrisi ile aynı olmalı (test_ci_workflow.py denetler)


def test_every_file_in_exactly_one_shard():
    files = shard.discover()
    assert files, "test dosyası bulunamadı"
    for n in (1, 2, 3, 4, 5, 7):
        parts = shard.assign(files, n, shard.load_weights())
        flat = [f for p in parts for f in p]
        assert sorted(flat) == files, f"N={n}: birleşim tüm dosyalar değil"
        assert len(flat) == len(set(flat)), f"N={n}: bir dosya birden çok parçada"


def test_assignment_is_deterministic():
    files = shard.discover()
    w = shard.load_weights()
    assert shard.assign(files, SHARD_COUNT, w) == shard.assign(list(reversed(files)), SHARD_COUNT, w)


def test_new_file_without_weight_still_assigned():
    files = shard.discover() + ["test/unit/test_zz_new_without_weight.gd"]
    parts = shard.assign(files, SHARD_COUNT, shard.load_weights())
    assert sum("test/unit/test_zz_new_without_weight.gd" in p for p in parts) == 1


def test_shards_are_balanced():
    files = shard.discover()
    w = shard.load_weights()
    parts = shard.assign(files, SHARD_COUNT, w)
    known = [w[f] for f in files if f in w]
    med = sorted(known)[len(known) // 2] if known else 1.0
    loads = [sum(w.get(f, med) for f in p) for p in parts]
    assert max(loads) <= 1.25 * (sum(loads) / len(loads)) + max(w.values(), default=0), loads


def test_weights_only_name_existing_files():
    stale = sorted(set(shard.load_weights()) - set(shard.discover()))
    assert not stale, f"shard_weights.json'da olmayan dosyalar: {stale[:5]}"


def test_config_replaces_dirs_with_tests(tmp_path):
    out = tmp_path / "c.json"
    subprocess.run(
        [sys.executable, str(ROOT / "tools/ci/shard.py"), "config", "2", "4", str(out), "--junit", "res://.gate/junit-2.xml"],
        check=True,
        cwd=ROOT,
    )
    cfg = json.loads(out.read_text())
    assert cfg["dirs"] == [] and cfg["tests"], cfg
    assert cfg["junit_xml_file"] == "res://.gate/junit-2.xml"
    base = json.loads((ROOT / ".gutconfig.json").read_text())
    for k in ("prefix", "suffix", "pre_run_script", "post_run_script", "should_exit"):
        assert cfg[k] == base[k]


def _suite(name, tests=1):
    return f'<testsuite name="{name}" tests="{tests}" failures="0" errors="0" skipped="0"><testcase classname="{name}" name="a" time="0.1"/></testsuite>'


def test_merge_and_check_merge(tmp_path):
    files = shard.discover()
    parts = shard.assign(files, 2, shard.load_weights())
    paths = []
    for i, p in enumerate(parts):
        f = tmp_path / f"j{i}.xml"
        f.write_text("<testsuites>" + "".join(_suite(x) for x in p) + "</testsuites>")
        paths.append(str(f))
    out = tmp_path / "all.xml"
    subprocess.run([sys.executable, str(ROOT / "tools/ci/shard.py"), "merge", str(out)] + paths, check=True)
    assert len(list(ET.parse(out).getroot().iter("testsuite"))) == len(files)
    ok = subprocess.run([sys.executable, str(ROOT / "tools/ci/shard.py"), "check-merge"] + paths)
    assert ok.returncode == 0
    dup = subprocess.run([sys.executable, str(ROOT / "tools/ci/shard.py"), "check-merge", paths[0], paths[0]], capture_output=True)
    assert dup.returncode == 1 and b"birden" in dup.stderr


def test_check_merge_detects_unknown_suite(tmp_path):
    f = tmp_path / "x.xml"
    f.write_text("<testsuites>" + _suite("test/unit/test_yok.gd") + "</testsuites>")
    r = subprocess.run([sys.executable, str(ROOT / "tools/ci/shard.py"), "check-merge", str(f)], capture_output=True)
    assert r.returncode == 1
