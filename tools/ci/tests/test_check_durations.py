import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "check_durations.py"


def junit(tmp_path, times):
    cases = "".join(
        f'<testcase name="test_{i}" classname="test/unit/test_x.gd" time="{t}"></testcase>'
        for i, t in enumerate(times)
    )
    p = tmp_path / "junit.xml"
    p.write_text(
        f'<testsuites><testsuite name="test/unit/test_x.gd" tests="{len(times)}">{cases}</testsuite></testsuites>'
    )
    return str(p)


def run(path, *args):
    return subprocess.run(
        [sys.executable, str(SCRIPT), path, *args], capture_output=True, text=True
    )


def test_fast_tests_pass_silently(tmp_path):
    r = run(junit(tmp_path, [0.1, 3.0, 19.9]))
    assert r.returncode == 0
    assert r.stdout == "" and r.stderr == ""


def test_single_test_over_limit_fails(tmp_path):
    r = run(junit(tmp_path, [1.0, 75.5]))
    assert r.returncode == 1
    assert "GATE_SLOW" in r.stderr and "test_1" in r.stderr


def test_exactly_at_limit_passes(tmp_path):
    assert run(junit(tmp_path, [75.0])).returncode == 0


def test_over_warn_is_info_not_failure(tmp_path):
    r = run(junit(tmp_path, [25.0]))
    assert r.returncode == 0
    assert "GATE_SLOW_INFO" in r.stdout


def test_total_over_720_warns_but_does_not_fail(tmp_path):
    r = run(junit(tmp_path, [50.0] * 15))  # 750 sn
    assert r.returncode == 0
    assert "GATE_WARN" in r.stderr


def test_total_under_threshold_has_no_warning(tmp_path):
    r = run(junit(tmp_path, [50.0] * 14))  # 700 sn
    assert "GATE_WARN" not in r.stderr


# --- Paralel (çekişmeli) koşu: T20261027-12 ---------------------------------------------------------------------
# Yerel/selftest tam gate GUT'u N süreçte koşar; testler CPU'yu paylaşır, JUnit'teki süre izole süreyi ~2 kat şişirir
# (run 40460222973: 41,9 -> 75,1 sn; toplam 724 sn, ardışık ölçüm 435 sn). 75/720 sn eşikleri ardışık koşuya göre
# ayarlıdır; çekişmeli ölçümde sert hata olmaz, uyarıya iner. Sert denetim çekişmesiz koşuda yapılır
# (CI gut parçaları: iş başına tek süreç; GATE_JOBS=1).


def test_contended_slow_test_warns_but_does_not_fail(tmp_path):
    r = run(junit(tmp_path, [1.0, 75.5]), "--contended")
    assert r.returncode == 0
    assert "GATE_SLOW_CONTENDED" in r.stderr and "test_1" in r.stderr
    assert "GATE_SLOW:" not in r.stderr


def test_contended_total_is_not_judged_against_sequential_threshold(tmp_path):
    r = run(junit(tmp_path, [50.0] * 15), "--contended")  # 750 sn
    assert r.returncode == 0
    assert "GATE_WARN" not in r.stderr


def test_contended_still_lists_info_tests(tmp_path):
    r = run(junit(tmp_path, [25.0]), "--contended")
    assert r.returncode == 0
    assert "GATE_SLOW_INFO" in r.stdout


def test_contended_fast_run_is_silent(tmp_path):
    r = run(junit(tmp_path, [0.1, 3.0, 19.9]), "--contended")
    assert r.returncode == 0
    assert r.stdout == "" and r.stderr == ""


def test_default_mode_unchanged_without_flag(tmp_path):
    # çekişmesiz (tek süreç) koşuda sınır sert kalır: bayrak yoksa davranış aynı.
    assert run(junit(tmp_path, [75.5])).returncode == 1
