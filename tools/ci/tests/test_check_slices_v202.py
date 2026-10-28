"""check_slices.py v2.0.2 genellemesi: (1) v2.0 çıktısı anlık görüntüyle BİREBİR aynı, (2) v2.0.2 simgeleri P R W Z E A."""
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SCRIPT = HERE.parent / "check_slices.py"
sys.path.insert(0, str(HERE.parent))
import check_slices  # noqa: E402

SNAP = json.loads((HERE / "slice_snapshot_v2.json").read_text(encoding="utf-8"))
TABLE = json.loads((HERE / "slice_cases_v202.json").read_text(encoding="utf-8"))
CLASS = "test/acceptance/test_acc_v202_pool_cards.gd"


def _run(cmd, env_extra):
    env = {**os.environ, "V2_SLICES_FORCE": "", "V202_SLICES_FORCE": ""}
    env.update(env_extra)
    return subprocess.run(cmd, capture_output=True, text=True, env=env)


def test_v2_snapshot_is_byte_identical(tmp_path):
    """Genellemeden önce kaydedilen v2.0 vakalarının (rc, stdout, stderr) çıktısı değişmemeli."""
    assert len(SNAP) >= 30
    for s in SNAP:
        sl = tmp_path / "slices.txt"
        if s["text"] == "__REPO__":
            sl = ROOT / "tools" / "v2_slices.txt"
        elif s["text"] is not None:
            sl.write_text(s["text"], encoding="utf-8")
        elif sl.exists():
            sl.unlink()
        cmd = [sys.executable, str(SCRIPT), str(sl)]
        if s["junit"] == "__MISSING__":
            cmd.append(str(tmp_path / "yok.xml"))
        elif s["junit"] is not None:
            (tmp_path / "junit.xml").write_text(s["junit"], encoding="utf-8")
            cmd.append(str(tmp_path / "junit.xml"))
        r = _run(cmd, {"V2_SLICES_FORCE": s["force"]})
        got = {
            "rc": r.returncode,
            "stdout": r.stdout.replace(str(tmp_path), "<TMP>"),
            "stderr": r.stderr.replace(str(tmp_path), "<TMP>"),
        }
        assert got == s["expect"], s["name"]


def test_v202_shared_case_table_parse():
    valid = tuple(TABLE["valid"])
    assert valid == check_slices.V202_SYMBOLS
    for c in TABLE["cases"]:
        ok, marks, errors = check_slices.parse(c["text"], valid)
        assert ok == c["ok"], c["name"]
        assert marks == c["marks"], c["name"]
        assert bool(errors) == (not c["ok"]), c["name"]


def _case(name, status="pass", cls=CLASS):
    skipped = '<skipped message="pending">x</skipped>' if status == "pending" else ""
    return f'<testcase name="{name}" assertions="1" status="{status}" classname="{cls}" time="0.01">{skipped}</testcase>'


def _junit(*cases):
    return '<testsuites><testsuite name="s" tests="%d">%s</testsuite></testsuites>' % (len(cases), "".join(cases))


def _run202(tmp_path, text, junit=None, env=None):
    sl = tmp_path / "v202_slices.txt"
    sl.write_text(text, encoding="utf-8")
    cmd = [sys.executable, str(SCRIPT), "--v202", "--file", str(sl)]
    if junit is not None:
        (tmp_path / "junit.xml").write_text(junit, encoding="utf-8")
        cmd.append(str(tmp_path / "junit.xml"))
    return _run(cmd, env or {})


def test_v202_table_via_cli(tmp_path):
    for c in TABLE["cases"]:
        assert (_run202(tmp_path, c["text"]).returncode == 0) == c["ok"], c["name"]


def test_v202_real_repo_file_is_valid():
    ok, _marks, errors = check_slices.parse((ROOT / "tools" / "v202_slices.txt").read_text(encoding="utf-8"), check_slices.V202_SYMBOLS)
    assert ok, errors


def test_v202_slice_of_uses_all_six_prefixes():
    for sym in "prwzea":
        assert check_slices.slice_of(f"test_{sym}12_x", check_slices.V202) == sym.upper()
    assert check_slices.slice_of("test_k1_x", check_slices.V202) is None
    assert check_slices.slice_of("test_m1_x", check_slices.V202) is None  # v2.0 simgeleri v2.0.2'de yok
    assert check_slices.slice_of("test_p_x", check_slices.V202) is None
    assert check_slices.slice_of("test_p1_x", check_slices.V2) is None  # v2.0 profili P'yi bilmez


def test_slice_of_accepts_letter_suffix():
    """F-ashen-bastion-123: test_e5b_ gibi harf soneki ad önekini bozmaz (check_test_ids ile aynı kural)."""
    assert check_slices.slice_of("test_e5b_tufan_pulls", check_slices.V202) == "E"
    assert check_slices.slice_of("test_m8a_flow", check_slices.V2) == "M"
    assert check_slices.slice_of("test_e5bc_x", check_slices.V202) is None  # tek harf
    assert check_slices.slice_of("test_e5_", check_slices.V202) == "E"


def test_v202_marked_slice_counts_suffixed_test(tmp_path):
    j = tmp_path / "j.xml"
    j.write_text(_junit(_case("test_e5b_x")), encoding="utf-8")
    r = _run([sys.executable, str(SCRIPT), "--v202", str(ROOT / "tools" / "v202_slices.txt"), str(j)], {"V202_SLICES_FORCE": "E"})
    assert r.returncode == 0, r.stderr


def test_v202_unmarked_pending_is_fine(tmp_path):
    assert _run202(tmp_path, "# yok\n", _junit(_case("test_p1_x", "pending"))).returncode == 0


def test_v202_marked_pending_fails(tmp_path):
    r = _run202(tmp_path, "P\n", _junit(_case("test_p1_x", "pending"), _case("test_p2_y")))
    assert r.returncode == 1 and "P:" in r.stderr and "pending" in r.stderr


def test_v202_marked_zero_tests_fails(tmp_path):
    r = _run202(tmp_path, "W\n", _junit(_case("test_p1_x")))
    assert r.returncode == 1 and "hiç test yok" in r.stderr


def test_v202_marked_all_real_passes(tmp_path):
    j = _junit(_case("test_r1_a"), _case("test_r2_b"), _case("test_w1_c", "pending"))
    assert _run202(tmp_path, "R\n", j).returncode == 0


def test_v202_old_v11_tests_with_same_prefix_are_ignored(tmp_path):
    """test_p20_… gibi v1.1 adları v202 sınıf süzgeci sayesinde P'ye sayılmaz (ne pending kırar ne sıfırı örter)."""
    old = "test/acceptance/test_acc_v11_bomb.gd"
    j = _junit(_case("test_p20_old", "pending", old), _case("test_p1_new"))
    assert _run202(tmp_path, "P\n", j).returncode == 0
    j2 = _junit(_case("test_p20_old", "pass", old))
    r = _run202(tmp_path, "P\n", j2)
    assert r.returncode == 1 and "hiç test yok" in r.stderr


def test_v202_force_env(tmp_path):
    j = _junit(_case("test_z3_x", "pending"))
    r = _run202(tmp_path, "# yok\n", j, env={"V202_SLICES_FORCE": "Z"})
    assert r.returncode == 1 and "Z:" in r.stderr
    assert _run202(tmp_path, "# yok\n", None, env={"V202_SLICES_FORCE": "K"}).returncode == 1
    # v2.0 zorlama değişkeni v2.0.2'yi etkilemez
    assert _run202(tmp_path, "# yok\n", j, env={"V2_SLICES_FORCE": "K"}).returncode == 0


def test_explicit_flags_equal_shortcut(tmp_path):
    sl = tmp_path / "s.txt"
    sl.write_text("E\n", encoding="utf-8")
    (tmp_path / "j.xml").write_text(_junit(_case("test_e1_x")), encoding="utf-8")
    a = _run([sys.executable, str(SCRIPT), "--v202", str(sl), str(tmp_path / "j.xml")], {})
    b = _run(
        [sys.executable, str(SCRIPT), "--file", str(sl), "--symbols", "P R W Z E A", "--force-env", "V202_SLICES_FORCE",
         "--classname-re", "v202", "--no-sliceless", str(tmp_path / "j.xml")], {})
    assert (a.returncode, a.stdout, a.stderr) == (b.returncode, b.stdout, b.stderr) == (0, "dilim işaretleri: E\n", "")


def test_bad_usage_exits_2():
    assert _run([sys.executable, str(SCRIPT), "--bilinmeyen"], {}).returncode == 2
    assert _run([sys.executable, str(SCRIPT)], {}).returncode == 2
