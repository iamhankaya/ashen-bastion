"""check_slices.py --v21 (v2.1 dilimleri M S K A B): simge/ad-öneki/çoklu açık dilim olumsuz vakaları."""
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE.parent / "check_slices.py"
sys.path.insert(0, str(HERE.parent))
import check_slices  # noqa: E402

CLASS = "test/unit/test_v21_sim_profile.gd"


def _run(args, env_extra=None):
    env = {**os.environ, "V21_SLICES_FORCE": "", "V2_SLICES_FORCE": "", "V202_SLICES_FORCE": ""}
    env.update(env_extra or {})
    return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True, env=env)


def _case(name, status="pass", cls=CLASS):
    skipped = '<skipped message="pending">x</skipped>' if status == "pending" else ""
    return f'<testcase name="{name}" assertions="1" status="{status}" classname="{cls}" time="0.01">{skipped}</testcase>'


def _junit(*cases):
    return '<testsuites><testsuite name="s" tests="%d">%s</testsuite></testsuites>' % (len(cases), "".join(cases))


def _go(tmp_path, text, junit=None, env=None):
    sl = tmp_path / "v21_slices.txt"
    sl.write_text(text, encoding="utf-8")
    args = ["--v21", str(sl)]
    if junit is not None:
        (tmp_path / "junit.xml").write_text(junit, encoding="utf-8")
        args.append(str(tmp_path / "junit.xml"))
    return _run(args, env)


def test_v21_symbols_constant():
    assert check_slices.V21_SYMBOLS == ("M", "S", "K", "A", "B")


def test_repo_file_is_valid_and_all_closed():
    r = _run(["--v21", str(HERE.parents[1] / "v21_slices.txt")])
    assert r.returncode == 0, r.stderr
    assert "M S K A B" in r.stdout  # T-tur 1: tüm dilimler açık


def test_all_symbols_accepted(tmp_path):
    r = _go(tmp_path, "M S K A B\n")
    assert r.returncode == 0, r.stderr
    assert "M S K A B" in r.stdout


def test_wrong_symbol_rejected(tmp_path):
    r = _go(tmp_path, "Z\n")
    assert r.returncode == 1
    assert "geçersiz simge 'Z'" in r.stderr


def test_other_family_symbol_rejected(tmp_path):
    # v2.0 simgesi (C: başarım dilimi v203) v2.1 ailesinde yok
    assert _go(tmp_path, "C\n").returncode == 1


def test_force_env_wrong_symbol(tmp_path):
    r = _go(tmp_path, "", env={"V21_SLICES_FORCE": "Q"})
    assert r.returncode == 1
    assert "V21_SLICES_FORCE" in r.stderr


def test_unmatched_name_prefix_is_not_counted(tmp_path):
    # test_u1_ v21 önekiyle eşleşmez: işaretli S diliminde sıfır test
    r = _go(tmp_path, "S\n", _junit(_case("test_u1_foo")))
    assert r.returncode == 1
    assert "hiç test yok" in r.stderr


def test_pending_in_marked_slice_fails(tmp_path):
    r = _go(tmp_path, "S\n", _junit(_case("test_s1_a"), _case("test_s2_b", "pending")))
    assert r.returncode == 1
    assert "pending" in r.stderr


def test_zero_tests_in_marked_slice_fails(tmp_path):
    r = _go(tmp_path, "K\n", _junit(_case("test_s1_a")))
    assert r.returncode == 1


def test_marked_slice_with_real_tests_passes(tmp_path):
    r = _go(tmp_path, "S\n", _junit(_case("test_s1_a"), _case("test_s2_b")))
    assert r.returncode == 0, r.stderr


def test_unmarked_slice_pending_is_fine(tmp_path):
    r = _go(tmp_path, "S\n", _junit(_case("test_s1_a"), _case("test_k1_x", "pending")))
    assert r.returncode == 0, r.stderr


def test_classname_filter_ignores_old_families(tmp_path):
    # eski dosyadaki test_s1_ adı (v21 olmayan sınıf) sayılmaz
    r = _go(tmp_path, "S\n", _junit(_case("test_s1_old", cls="test/unit/test_old.gd")))
    assert r.returncode == 1


def test_multiple_open_slices_all_checked(tmp_path):
    r = _go(tmp_path, "S K\n", _junit(_case("test_s1_a"), _case("test_k1_a", "pending")))
    assert r.returncode == 1
    assert "K:" in r.stderr and "S:" not in r.stderr


# --- T-tur 1: adlandırma kuralı (tek kural: v2.1 K/M/B testleri de test_<simge><N>_; v2.0 profili v21 sınıflarını saymaz) ---

V2_SYMBOLS_FILE = "K\nM\nB\n"


def _go_v2(tmp_path, junit):
    sl = tmp_path / "v2_slices.txt"
    sl.write_text(V2_SYMBOLS_FILE, encoding="utf-8")
    (tmp_path / "junit.xml").write_text(junit, encoding="utf-8")
    return _run([str(sl), str(tmp_path / "junit.xml")])


def test_v2_profile_ignores_pending_in_v21_classes(tmp_path):
    # v2.1 sınıfındaki pending test_k/m/b<N>_ v2.0 kapısını kırmamalı (K/M/B v2.0'da işaretli)
    cls = "test/acceptance/test_acc_v21_highscores.gd"
    v2_real = [_case(f"test_{s}2_x", cls="test/acceptance/test_acc_v2_ach_flow.gd") for s in "kmb"]  # M1 dilimsiz
    pend = [_case(f"test_{s}1_y", "pending", cls=cls) for s in "kmb"]
    r = _go_v2(tmp_path, _junit(*v2_real, *pend))
    assert r.returncode == 0, r.stderr


def test_v2_profile_still_counts_pending_in_v2_classes(tmp_path):
    # süzgeç yalnız v21 sınıflarını dışlar: v2.0 sınıfındaki pending hâlâ kırar (sahte yeşil olmasın)
    cls = "test/acceptance/test_acc_v2_ach_flow.gd"
    r = _go_v2(tmp_path, _junit(_case("test_k1_a", cls=cls), _case("test_k2_b", "pending", cls=cls),
                                _case("test_m2_a", cls=cls), _case("test_b2_a", cls=cls)))
    assert r.returncode == 1
    assert "K:" in r.stderr


def test_v21_profile_counts_k_m_b_plain_names(tmp_path):
    cls = "test/acceptance/test_acc_v21_highscores.gd"
    ok = _go(tmp_path, "K\n", _junit(_case("test_k1_a", cls=cls)))
    assert ok.returncode == 0, ok.stderr
    bad = _go(tmp_path, "K\n", _junit(_case("test_k1_a", cls=cls), _case("test_k2_b", "pending", cls=cls)))
    assert bad.returncode == 1


def test_v21_profile_does_not_count_legacy_v21_prefixed_names(tmp_path):
    # eski ad test_v21k<N>_ tek kural dışıdır: işaretli K diliminde sayılmaz (yeniden adlandırma unutulursa kapı kırılır)
    cls = "test/acceptance/test_acc_v21_highscores.gd"
    r = _go(tmp_path, "K\n", _junit(_case("test_v21k1_a", cls=cls)))
    assert r.returncode == 1
    assert "hiç test yok" in r.stderr


def test_no_legacy_v21_prefixed_test_names_in_repo():
    # kural tek: depoda test_v21<k|m|b><N>_ adlı test kalmamalı
    import re
    pat = re.compile(r"func\s+test_v21[a-z]\d+_")
    hits = []
    for p in (HERE.parents[2] / "test").rglob("*.gd"):
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if pat.search(line):
                hits.append(f"{p.name}:{n}")
    assert not hits, hits[:5]
