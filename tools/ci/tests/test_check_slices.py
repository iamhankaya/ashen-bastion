import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE.parent / "check_slices.py"
sys.path.insert(0, str(HERE.parent))
import check_slices  # noqa: E402

TABLE = json.loads((HERE / "slice_cases.json").read_text(encoding="utf-8"))


def run(tmp_path, text=None, junit=None, env=None):
    sl = tmp_path / "v2_slices.txt"
    if text is not None:
        sl.write_text(text, encoding="utf-8")
    cmd = [sys.executable, str(SCRIPT), str(sl)]
    if junit is not None:
        j = tmp_path / "junit.xml"
        j.write_text(junit, encoding="utf-8")
        cmd.append(str(j))
    import os
    e = {**os.environ, "V2_SLICES_FORCE": ""}
    e.update(env or {})
    return subprocess.run(cmd, capture_output=True, text=True, env=e)


def case(name, status="pass", cls="test/acceptance/test_acc_v2_chars.gd"):
    skipped = '<skipped message="pending">x</skipped>' if status == "pending" else ""
    return f'<testcase name="{name}" assertions="1" status="{status}" classname="{cls}" time="0.01">{skipped}</testcase>'


def junit(*cases):
    return '<testsuites><testsuite name="s" tests="%d">%s</testsuite></testsuites>' % (len(cases), "".join(cases))


def test_shared_case_table_parse():
    valid = tuple(TABLE["valid"])
    for c in TABLE["cases"]:
        ok, marks, errors = check_slices.parse(c["text"], valid)
        assert ok == c["ok"], c["name"]
        assert marks == c["marks"], c["name"]
        assert bool(errors) == (not c["ok"]), c["name"]


def test_shared_case_table_via_cli(tmp_path):
    for c in TABLE["cases"]:
        r = run(tmp_path, c["text"])
        assert (r.returncode == 0) == c["ok"], (c["name"], r.stderr)


def test_missing_file_is_error(tmp_path):
    assert run(tmp_path, None).returncode == 1
    assert "SLICE_ERROR" in run(tmp_path, None).stderr


def test_unmarked_slice_with_pending_is_fine(tmp_path):
    j = junit(case("test_k4_x", "pending"), case("test_b1_y", "pending"))
    assert run(tmp_path, "# yok\n", j).returncode == 0


def test_marked_slice_with_pending_fails(tmp_path):
    j = junit(case("test_k4_x", "pending"), case("test_k5_y"))
    r = run(tmp_path, "K\n", j)
    assert r.returncode == 1
    assert "pending" in r.stderr and "K:" in r.stderr


def test_marked_slice_with_zero_tests_fails(tmp_path):
    j = junit(case("test_b1_y"))
    r = run(tmp_path, "K\n", j)
    assert r.returncode == 1
    assert "hiç test yok" in r.stderr


def test_marked_slice_all_real_passes(tmp_path):
    j = junit(case("test_k4_x"), case("test_k10_y"), case("test_b1_z", "pending"))
    assert run(tmp_path, "K\n", j).returncode == 0


def test_other_slice_pending_does_not_break_marked_slice(tmp_path):
    j = junit(case("test_k4_x"), case("test_m2_p", "pending"))
    assert run(tmp_path, "K\n", j).returncode == 0


def test_m1_m9_m10_are_sliceless(tmp_path):
    # M işaretli, yalnız dilimsiz testler var => M'nin sıfır testi var (hata); dilimsiz pending de M'yi bozmaz
    j = junit(case("test_m1_a"), case("test_m9_b"), case("test_m10_c", "pending"))
    r = run(tmp_path, "M\n", j)
    assert r.returncode == 1 and "hiç test yok" in r.stderr
    j2 = junit(case("test_m1_a"), case("test_m2_b"), case("test_m10_c", "pending"))
    assert run(tmp_path, "M\n", j2).returncode == 0


def test_m11_is_a_slice_member_not_sliceless():
    assert check_slices.slice_of("test_m11_x") == "M"
    assert check_slices.slice_of("test_m1_x") is None
    assert check_slices.slice_of("test_m10_x") is None
    assert check_slices.slice_of("test_karakterizasyon_x") is None
    assert check_slices.slice_of("test_k_x") is None


def test_force_env_marks_slice(tmp_path):
    j = junit(case("test_k4_x", "pending"))
    r = run(tmp_path, "# yok\n", j, env={"V2_SLICES_FORCE": "K"})
    assert r.returncode == 1 and "K:" in r.stderr


def test_force_env_invalid_symbol(tmp_path):
    assert run(tmp_path, "# yok\n", None, env={"V2_SLICES_FORCE": "Z"}).returncode == 1


def test_syntax_error_skips_junit_phase(tmp_path):
    r = run(tmp_path, "Q\n", junit(case("test_k4_x")))
    assert r.returncode == 1 and "geçersiz simge" in r.stderr


def test_real_repo_file_is_valid():
    p = HERE.parents[1] / "v2_slices.txt"
    ok, marks, errors = check_slices.parse(p.read_text(encoding="utf-8"))
    assert ok, errors
