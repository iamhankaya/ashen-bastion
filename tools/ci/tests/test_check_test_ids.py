"""S-ids: check_test_ids.py — bildirilen (declared) test kimlikleri, JUnit'te koşanlar, izinli pending ve tabana göre kimlik kaybı."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "tools" / "ci" / "check_test_ids.py"
FIXTURE = Path(__file__).resolve().parent / "fixtures" / "gut_junit_real.xml"
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import check_junit  # noqa: E402
import check_test_ids as T  # noqa: E402

GUTCONFIG = json.dumps({"dirs": ["res://test/unit", "res://test/acceptance"], "prefix": "test_", "suffix": ".gd", "include_subdirs": True})


def write_tree(root, files):
    for rel, text in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8", newline="\n")
    if ".gutconfig.json" not in files:
        (root / ".gutconfig.json").write_text(GUTCONFIG, encoding="utf-8")


def gd(*funcs):
    return "extends GutTest\n\n" + "".join(f"func {f}() -> void:\n\tpass\n\n\n" for f in funcs)


def junit(cases):
    """cases: [(dosya, ad, 'pass'|'pending')] -> JUnit metni (gerçek GUT biçimi)."""
    out = ['<?xml version="1.0" encoding="UTF-8"?>', '<testsuites name="GutTests">']
    for f in sorted({c[0] for c in cases}):
        out.append(f'<testsuite name="{f}">')
        for cf, name, st in cases:
            if cf == f:
                extra = '<skipped message="pending">x</skipped>' if st == "pending" else ""
                out.append(f'<testcase name="{name}" status="{st}" classname="{f}">{extra}</testcase>')
        out.append("</testsuite>")
    out.append("</testsuites>")
    return "\n".join(out)


def git(root, *args):
    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)


def init_repo(root, files):
    root.mkdir(exist_ok=True)
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "t@t")
    git(root, "config", "user.name", "t")
    git(root, "config", "core.autocrlf", "false")
    write_tree(root, files)
    git(root, "add", "-A")
    git(root, "commit", "-qm", "base")


def run(root, *args):
    return subprocess.run([sys.executable, str(TOOL), "--root", str(root), *args], capture_output=True, text=True, encoding="utf-8")


# --- declared ---------------------------------------------------------------------------------------------------------------


def test_declared_counts_only_column0_func_test_outside_comments_strings_and_classes():
    src = (
        "extends GutTest\n"
        "func test_real() -> void:\n\tpass\n"
        "# func test_in_comment() -> void:\n"
        "func _helper() -> void:\n\tpass\n"
        "\tfunc test_indented() -> void:\n\t\tpass\n"
        'const S := """\nfunc test_in_string() -> void:\n"""\n'
        "class _Spy:\n\tfunc test_in_class() -> void:\n\t\tpass\n"
        "func test_after_class(x = 1) -> void:\n\tpass\n"
    )
    ids, unsupported = T.parse_declared(src, "test/unit/test_x.gd")
    assert ids == ["test/unit/test_x.gd::test_real", "test/unit/test_x.gd::test_after_class"]
    assert unsupported == []


def test_inner_class_with_test_prefix_is_unsupported():
    ids, unsupported = T.parse_declared("extends GutTest\nclass TestInner:\n\tfunc test_a():\n\t\tpass\n", "test/unit/test_x.gd")
    assert unsupported == ["test/unit/test_x.gd::TestInner"]


def test_declared_reads_dirs_prefix_suffix_from_gutconfig(tmp_path):
    write_tree(tmp_path, {
        "test/unit/test_a.gd": gd("test_one"),
        "test/acceptance/sub/test_b.gd": gd("test_two"),
        "test/unit/helper.gd": gd("test_nope"),  # önek yok
        "test/long/test_c.gd": gd("test_nope2"),  # dizin gutconfig'te yok
    })
    d = T.collect_declared(T.FsSource(tmp_path))
    assert sorted(d.ids) == ["test/acceptance/sub/test_b.gd::test_two", "test/unit/test_a.gd::test_one"]


def test_duplicate_declared_id_is_reported(tmp_path):
    write_tree(tmp_path, {"test/unit/test_a.gd": gd("test_one", "test_one")})
    assert T.collect_declared(T.FsSource(tmp_path)).dups == ["test/unit/test_a.gd::test_one"]


# --- JUnit (gerçek CI biçimi) -----------------------------------------------------------------------------------------------


def test_real_junit_fixture_maps_classname_and_name_to_ids():
    j = T.read_junit([FIXTURE])
    assert "test/acceptance/test_acc_caps.gd::test_projectile_pool_caps_at_600" in j.ran
    assert len(j.ran) + len(j.skipped) == 37
    assert "test/acceptance/test_acc_v202_pool_cards.gd::test_p1_zyfen_never_offered_gunslinger_only_cards" in j.skipped
    assert not (j.ran & j.skipped)
    assert j.dups == []


def test_duplicate_junit_testcase_is_reported(tmp_path):
    a = tmp_path / "a.xml"
    b = tmp_path / "b.xml"
    a.write_text(junit([("test/unit/test_a.gd", "test_one", "pass")]), encoding="utf-8")
    b.write_text(junit([("test/unit/test_a.gd", "test_one", "pass")]), encoding="utf-8")
    assert T.read_junit([a, b]).dups == ["test/unit/test_a.gd::test_one"]


# --- pending_allowed (kapalı dilimler) --------------------------------------------------------------------------------------


def slice_tree(marks_v202="", extra=None):
    files = {
        "tools/v202_slices.txt": "# başlık\n" + marks_v202,
        "tools/v21_slices.txt": "# başlık\n",
        "tools/v2_slices.txt": "# başlık\n",
        "tools/v203_slices.txt": "# başlık\n",
        "test/acceptance/test_acc_v202_x.gd": gd("test_p1_a", "test_e5b_lenient_suffix", "test_a1_open_symbol_other_name"),
        "test/acceptance/test_acc_v21_x.gd": gd("test_s1_closed"),
        "test/unit/test_plain.gd": gd("test_plain"),
    }
    files.update(extra or {})
    return files


def test_pending_allowed_is_closed_slice_tests_only(tmp_path):
    write_tree(tmp_path, slice_tree())
    src = T.FsSource(tmp_path)
    d = T.collect_declared(src)
    allowed = T.pending_allowed(src, d.ids)
    assert "test/acceptance/test_acc_v202_x.gd::test_p1_a" in allowed
    assert "test/acceptance/test_acc_v202_x.gd::test_e5b_lenient_suffix" in allowed  # check_slices regex'inin kaçırdığı 'e5b' soneki
    assert "test/acceptance/test_acc_v21_x.gd::test_s1_closed" in allowed
    assert "test/unit/test_plain.gd::test_plain" not in allowed


def test_marked_slice_is_no_longer_allowed(tmp_path):
    write_tree(tmp_path, slice_tree(marks_v202="P\n"))
    src = T.FsSource(tmp_path)
    allowed = T.pending_allowed(src, T.collect_declared(src).ids)
    assert "test/acceptance/test_acc_v202_x.gd::test_p1_a" not in allowed
    assert "test/acceptance/test_acc_v202_x.gd::test_e5b_lenient_suffix" in allowed


# --- denetim (i): declared(HEAD) ⊆ ran ∪ pending_allowed ----------------------------------------------------------------------


def head_check(tmp_path, files, cases, **kw):
    write_tree(tmp_path, files)
    j = tmp_path / "j.xml"
    j.write_text(junit(cases), encoding="utf-8")
    return run(tmp_path, "--mode", "full", "--junit", str(j), "--no-base", **kw) if not kw else run(tmp_path, "--mode", "full", "--junit", str(j), "--no-base")


def test_declared_test_missing_from_junit_is_red(tmp_path):
    r = head_check(tmp_path, {"test/unit/test_a.gd": gd("test_one", "test_two")}, [("test/unit/test_a.gd", "test_one", "pass")])
    assert r.returncode == 1
    assert "TEST_IDS: test/unit/test_a.gd::test_two: MISSING" in r.stderr


def test_unexpected_skip_is_red_but_closed_slice_pending_is_green(tmp_path):
    files = slice_tree()
    cases = [
        ("test/acceptance/test_acc_v202_x.gd", "test_p1_a", "pending"),
        ("test/acceptance/test_acc_v202_x.gd", "test_e5b_lenient_suffix", "pending"),
        ("test/acceptance/test_acc_v202_x.gd", "test_a1_open_symbol_other_name", "pending"),  # A açık değil ama v202 'A' dilimi kapalı => izinli
        ("test/acceptance/test_acc_v21_x.gd", "test_s1_closed", "pending"),
        ("test/unit/test_plain.gd", "test_plain", "pending"),  # dilimsiz test pending => kırmızı
    ]
    r = head_check(tmp_path, files, cases)
    assert r.returncode == 1
    assert r.stderr.strip().splitlines() == ["TEST_IDS: test/unit/test_plain.gd::test_plain: MISSING"]


def test_duplicate_junit_and_declared_make_the_run_red(tmp_path):
    files = {"test/unit/test_a.gd": gd("test_one")}
    r = head_check(tmp_path, files, [("test/unit/test_a.gd", "test_one", "pass"), ("test/unit/test_a.gd", "test_one", "pass")])
    assert r.returncode == 1 and "test_one: DUP" in r.stderr


def test_pending_allowed_file_lists_known_runtime_pending(tmp_path):
    write_tree(tmp_path, {"test/unit/test_a.gd": gd("test_one"), "tools/ci/pending_allowed.txt": "# başlık\ntest/unit/test_a.gd::test_one | atlas kare yok | T-x\n"})
    j = tmp_path / "j.xml"
    j.write_text(junit([("test/unit/test_a.gd", "test_one", "pending")]), encoding="utf-8")
    assert run(tmp_path, "--mode", "full", "--junit", str(j), "--no-base").returncode == 0


# --- denetim (ii)/(iii): tabana göre kayıp --------------------------------------------------------------------------------------


@pytest.fixture
def repo(tmp_path):
    root = tmp_path / "r"
    init_repo(root, {"test/unit/test_a.gd": gd("test_one", "test_two"), "tools/ci/removed_tests.txt": "", "tools/ci/moved_tests.txt": ""})
    return root


def commit(root, files, msg="head"):
    write_tree(root, files)
    git(root, "add", "-A")
    git(root, "commit", "-qm", msg)


def test_deleted_test_without_record_is_lost(repo):
    commit(repo, {"test/unit/test_a.gd": gd("test_one")})
    r = run(repo, "--mode", "static", "--base", "HEAD~1")
    assert r.returncode == 1
    assert "TEST_IDS: test/unit/test_a.gd::test_two: LOST" in r.stderr


def test_deleted_test_with_removed_record_is_ok(repo):
    commit(repo, {"test/unit/test_a.gd": gd("test_one"), "tools/ci/removed_tests.txt": "test/unit/test_a.gd::test_two | artık gereksiz | T-1\n"})
    assert run(repo, "--mode", "static", "--base", "HEAD~1").returncode == 0


def test_moved_test_with_record_is_ok_and_split_one_to_many(repo):
    commit(repo, {
        "test/unit/test_a.gd": gd("test_one"),
        "test/unit/test_b.gd": gd("test_two_a", "test_two_b"),
        "tools/ci/moved_tests.txt": "test/unit/test_a.gd::test_two -> test/unit/test_b.gd::test_two_a, test/unit/test_b.gd::test_two_b\n",
    })
    assert run(repo, "--mode", "static", "--base", "HEAD~1").returncode == 0


@pytest.mark.parametrize("moved, why", [
    ("test/unit/test_a.gd::test_one -> test/unit/test_b.gd::test_x\n", "eski kimlik HEAD'de hâlâ var"),
    ("test/unit/test_a.gd::test_two -> test/unit/test_b.gd::yok\n", "yeni kimlik HEAD'de yok"),
    ("test/unit/test_a.gd::test_two -> test/unit/test_b.gd::test_x\ntest/unit/test_a.gd::test_two -> test/unit/test_b.gd::test_y\n", "bir eski iki satırda"),
    ("test/unit/test_a.gd::gone1 -> test/unit/test_b.gd::test_x\ntest/unit/test_a.gd::gone2 -> test/unit/test_b.gd::test_x\n", "bir yeni iki eskiden"),
    ("bozuk satır\n", "ayrıştırılamaz"),
])
def test_invalid_move_records_are_red(repo, moved, why):
    commit(repo, {"test/unit/test_a.gd": gd("test_one"), "test/unit/test_b.gd": gd("test_x", "test_y"), "tools/ci/moved_tests.txt": moved})
    r = run(repo, "--mode", "static", "--base", "HEAD~1")
    assert r.returncode == 1 and "MOVE_INVALID" in r.stderr, why


def test_removed_record_needs_reason_and_task(repo):
    commit(repo, {"test/unit/test_a.gd": gd("test_one"), "tools/ci/removed_tests.txt": "test/unit/test_a.gd::test_two\n"})
    r = run(repo, "--mode", "static", "--base", "HEAD~1")
    assert r.returncode == 1 and "REMOVED_INVALID" in r.stderr


def test_turning_a_running_test_into_allowed_pending_is_lost_by_iii(tmp_path):
    root = tmp_path / "r"
    init_repo(root, {"tools/v202_slices.txt": "# başlık\nP\n", "test/acceptance/test_acc_v202_x.gd": gd("test_p1_a")})
    commit(root, {"tools/v202_slices.txt": "# başlık\n"})  # P simgesi kapatıldı: HEAD'de p1 artık izinli pending
    j = tmp_path / "j.xml"
    j.write_text(junit([("test/acceptance/test_acc_v202_x.gd", "test_p1_a", "pending")]), encoding="utf-8")
    r = run(root, "--mode", "full", "--junit", str(j), "--base", "HEAD~1")
    assert r.returncode == 1
    assert "TEST_IDS: test/acceptance/test_acc_v202_x.gd::test_p1_a: LOST" in r.stderr
    # (i) tek başına yeşil: kimlik HEAD'de izinli pending; kayıp yalnız taban karşılaştırmasında görünür
    assert run(root, "--mode", "full", "--junit", str(j), "--no-base").returncode == 0


def test_base_declared_file_replaces_git_base(tmp_path):
    write_tree(tmp_path, {"test/unit/test_a.gd": gd("test_one")})
    bd = tmp_path / "base.txt"
    bd.write_text("test/unit/test_a.gd::test_one\ntest/unit/test_a.gd::test_gone\n", encoding="utf-8")
    r = run(tmp_path, "--mode", "static", "--base-declared", str(bd))
    assert r.returncode == 1 and "test_gone: LOST" in r.stderr


# --- kipler ------------------------------------------------------------------------------------------------------------------


def test_full_mode_without_junit_is_static_and_says_so(tmp_path):
    write_tree(tmp_path, {"test/unit/test_a.gd": gd("test_one")})
    r = run(tmp_path, "--mode", "full", "--no-base")
    assert r.returncode == 0 and "static" in r.stdout


def test_selected_mode_checks_only_selected_files(tmp_path):
    write_tree(tmp_path, {"test/unit/test_a.gd": gd("test_one"), "test/unit/test_b.gd": gd("test_two")})
    j = tmp_path / "j.xml"
    j.write_text(junit([("test/unit/test_a.gd", "test_one", "pass")]), encoding="utf-8")
    sel = tmp_path / "sel.txt"
    sel.write_text("test/unit/test_a.gd\n", encoding="utf-8")
    assert run(tmp_path, "--mode", "selected", "--junit", str(j), "--files", str(sel), "--no-base").returncode == 0
    sel.write_text("test/unit/test_a.gd\ntest/unit/test_b.gd\n", encoding="utf-8")
    r = run(tmp_path, "--mode", "selected", "--junit", str(j), "--files", str(sel), "--no-base")
    assert r.returncode == 1 and "test_b.gd::test_two: MISSING" in r.stderr


def test_report_only_exits_zero_and_prints_the_diff(tmp_path):
    write_tree(tmp_path, {"test/unit/test_a.gd": gd("test_one", "test_two")})
    j = tmp_path / "j.xml"
    j.write_text(junit([("test/unit/test_a.gd", "test_one", "pass")]), encoding="utf-8")
    r = run(tmp_path, "--mode", "full", "--junit", str(j), "--no-base", "--report-only")
    assert r.returncode == 0
    assert "declared=2" in r.stdout and "ran=1" in r.stdout and "test_a.gd::test_two" in r.stdout


# --- gerçek depo ----------------------------------------------------------------------------------------------------------------


def test_real_repo_has_no_inner_test_classes_or_duplicate_ids():
    d = T.collect_declared(T.FsSource(ROOT))
    assert d.unsupported == [], "iç sınıf/parametreli test yok olgusu bozuldu"
    assert d.dups == []
    assert len(d.ids) > 2000


def test_real_repo_static_mode_is_green():
    r = subprocess.run([sys.executable, str(TOOL), "--mode", "static", "--no-base"], capture_output=True, text=True, cwd=ROOT, encoding="utf-8")
    assert r.returncode == 0, r.stderr


def test_committed_record_files_parse():
    assert T.parse_removed((ROOT / "tools/ci/removed_tests.txt").read_text(encoding="utf-8"))[1] == []
    assert T.parse_moved((ROOT / "tools/ci/moved_tests.txt").read_text(encoding="utf-8"))[1] == []


# --- eski kapı ile parite -------------------------------------------------------------------------------------------------------


def synth_junit(tmp_path, d, allowed, drop_file=None):
    """declared'dan gerçek biçimli JUnit üretir: izinli pending skipped, kalanı pass; drop_file'ın suite'i yok."""
    by_file = {}
    for i in sorted(d.ids):
        f, fn = i.split("::")
        if f != drop_file:
            by_file.setdefault(f, []).append((fn, "pending" if i in allowed else "pass"))
    out = ['<?xml version="1.0"?>', "<testsuites>"]
    for f, cs in by_file.items():
        skipped = sum(1 for _, s in cs if s == "pending")
        out.append(f'<testsuite name="{f}" tests="{len(cs)}" skipped="{skipped}">')
        for fn, st in cs:
            extra = '<skipped message="pending">x</skipped>' if st == "pending" else ""
            out.append(f'<testcase name="{fn}" status="{st}" classname="{f}">{extra}</testcase>')
        out.append("</testsuite>")
    out.append("</testsuites>")
    p = tmp_path / "synth.xml"
    p.write_text("\n".join(out), encoding="utf-8")
    return p


def test_parity_with_old_gate_on_the_real_tree(tmp_path):
    src = T.FsSource(ROOT)
    d = T.collect_declared(src)
    allowed = T.pending_allowed(src, d.ids) | T.parse_pending_allowed((ROOT / "tools/ci/pending_allowed.txt").read_text(encoding="utf-8"))[0]
    mins = json.loads((ROOT / "tools/gate_min_tests.json").read_text(encoding="utf-8"))
    # tam JUnit: iki kapı da yeşil (kimlik düzeyinde declared == ran ∪ izinli pending)
    full = synth_junit(tmp_path, d, allowed)
    assert check_junit.main(str(full), str(ROOT / "tools/gate_min_tests.json")) == 0
    assert T.verify(d, T.read_junit([full]), allowed) == []
    by_file = {}
    for i in d.ids:
        by_file.setdefault(i.split("::")[0], []).append(i)
    no_declared = sorted(f for f in mins if f not in by_file)
    assert len(no_declared) >= 0  # bilgi: tabloda olup declared'da dosyası olmayan girdi (rapora yazılır, kapıyı etkilemez)
    checked = 0
    for f, need in sorted(mins.items()):
        runnable = [i for i in by_file.get(f, []) if i not in allowed]
        if need == 0 or not runnable:
            continue  # sıfır asgari ya da tümü izinli pending: eski kapının sayısı kimlik düzeyine eşlenmez (raporda)
        broken = synth_junit(tmp_path, d, allowed, drop_file=f)
        assert check_junit.main(str(broken), str(ROOT / "tools/gate_min_tests.json")) == 1, f"eski kapı yeşil: {f}"
        assert T.verify(d, T.read_junit([broken]), allowed), f"yeni kapı yeşil: {f}"
        checked += 1
    assert checked > 150
