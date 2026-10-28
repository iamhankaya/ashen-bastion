"""tools/ci/measure_ci.py: Ölçüm protokolü (duvar, kritik yol, runner-dk, soğuk/sıcak etiketi, medyan ve %30 kabulü)."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import measure_ci as m  # noqa: E402

Z = "0001-01-01T00:00:00Z"


def job(name, start, end, conclusion="success"):
    return {"name": name, "startedAt": start, "completedAt": end, "conclusion": conclusion}


JOBS = [
    job("static", "2026-10-28T10:00:10Z", "2026-10-28T10:02:10Z"),      # 120 sn
    job("gut (1)", "2026-10-28T10:00:20Z", "2026-10-28T10:04:20Z"),     # 240 sn
    job("gut (2)", "2026-10-28T10:00:30Z", "2026-10-28T10:03:30Z"),     # 180 sn
    job("test", "2026-10-28T10:04:30Z", "2026-10-28T10:05:00Z"),        # 30 sn
    job("selftest (1)", "2026-10-28T10:00:15Z", "2026-10-28T10:07:15Z"),  # 420 sn
    job("export-debug", Z, Z, "skipped"),
]
NEEDS = {"test": ["static", "gut"]}


def test_wall_excludes_queue_and_skipped_jobs():
    r = m.metrics(JOBS, NEEDS)
    assert r["wall"] == 425  # 10:00:10 -> 10:07:15
    assert r["jobs_run"] == 5 and r["jobs_skipped"] == 1


def test_critical_path_is_longest_needs_chain_over_matrix_max():
    r = m.metrics(JOBS, NEEDS)
    assert r["critical_path"] == 420  # selftest (bağımsız) 420 > gut 240 + test 30 = 270
    only_chain = [j for j in JOBS if not j["name"].startswith("selftest")]
    assert m.metrics(only_chain, NEEDS)["critical_path"] == 270  # matrix en uzun üye (240) + test


def test_runner_minutes_is_sum_of_job_durations():
    assert m.metrics(JOBS, NEEDS)["runner_min"] == round((120 + 240 + 180 + 30 + 420) / 60, 2)


def test_cache_label_from_log_is_recorded_not_assumed():
    hit = "Cache restored from key: godot-import-abc\nCache hit occurred on the primary key godot-import-abc"
    miss = "Cache not found for input keys: godot-import-abc"
    assert m.cache_label(hit) == "sicak"
    assert m.cache_label(miss) == "soguk"
    assert m.cache_label(hit + "\n" + miss) == "soguk"  # biri bile ıskaladıysa soğuk
    assert m.cache_label("önbellek satırı yok") == "bilinmiyor"


def test_skipped_by_filter_markers_are_collected():
    log = "PATH_FILTER: run=0 — SKIPPED_BY_FILTER (eşleşen yol yok)\nSKIPPED_BY_FILTER taban_yesil (x)"
    assert m.skipped_by_filter(log) == 2
    assert m.skipped_by_filter("hiçbiri") == 0


def test_needs_parsed_from_workflow_text():
    yml = "jobs:\n  static:\n    runs-on: x\n  test:\n    needs: [static, gut]\n    runs-on: x\n  other:\n    needs: static\n"
    assert m.parse_needs(yml) == {"test": ["static", "gut"], "other": ["static"]}


def test_median_and_acceptance_threshold():
    assert m.median([5, 1, 3]) == 3 and m.median([1, 2, 3, 4]) == 2.5
    before = [{"wall": 600, "critical_path": 500, "label": "sicak"}] * 5
    ok = [{"wall": 420, "critical_path": 350, "label": "sicak"}] * 5      # tam %70
    bad = [{"wall": 421, "critical_path": 350, "label": "sicak"}] * 5
    assert m.compare(before, ok)["sicak"]["accepted"] is True
    c = m.compare(before, bad)["sicak"]
    assert c["accepted"] is False and round(c["wall_ratio"], 3) == 0.702


def test_compare_pairs_hot_with_hot_and_cold_with_cold_only():
    before = [{"wall": 600, "critical_path": 500, "label": "sicak"}] * 5 + [{"wall": 900, "critical_path": 800, "label": "soguk"}] * 5
    after = [{"wall": 300, "critical_path": 250, "label": "sicak"}] * 5
    c = m.compare(before, after)
    assert "sicak" in c and "soguk" not in c  # karşılığı olmayan etiket karşılaştırılmaz
    assert m.compare(before, after[:3])["sicak"]["enough_samples"] is False  # taraf başına >=5


def test_mad_outliers_are_reported_not_dropped():
    vals = [100, 101, 99, 100, 102, 400]
    out = m.outliers(vals)
    assert out == [400] and len(vals) == 6
