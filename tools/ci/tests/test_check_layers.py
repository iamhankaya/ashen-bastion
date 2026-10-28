"""S-layers: check_layers.py — katman matrisi, istisna kaydı (ratchet), eşlenmemiş dizin, ilk taban üretimi."""

import itertools
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "tools" / "ci" / "check_layers.py"
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import check_layers as L  # noqa: E402

PROJECT = '[autoload]\n\nEvents="*res://scripts/autoload/events.gd"\nSettings="*res://scripts/autoload/settings.gd"\n'

# Planın "Bileşenler" matrisi (satır, sütundaki katmana bağımlı olabilir). Bağımsız yazıldı: araçtaki tablo bununla birebir olmalı.
PLAN = {
    "sim": {"sim"},
    "store": {"sim", "store"},
    "domain": {"sim", "domain", "store"},
    "validate": {"sim", "validate"},
    "view": {"sim", "domain", "view"},
    "autoload": {"sim", "domain", "store", "autoload"},
    "ui": {"sim", "domain", "view", "autoload", "ui"},
    "ctrl": {"sim", "domain", "store", "validate", "view", "autoload", "ui", "ctrl"},
}


def tree(root, files):
    (root / "project.godot").write_text(PROJECT, encoding="utf-8")
    for rel, text in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8", newline="\n")
    return root


def cls(name, body="", extends="RefCounted"):
    return f"class_name {name}\nextends {extends}\n{body}"


def messages(root, exceptions="", base=None):
    return L.check(root, L.parse_exceptions(exceptions), None if base is None else L.parse_exceptions(base))[0]


def test_matrix_equals_the_plan():
    assert {k: set(v) for k, v in L.ALLOWED.items()} == PLAN


@pytest.mark.parametrize("src,dst", list(itertools.product(PLAN, PLAN)))
def test_every_layer_pair(tmp_path, src, dst):
    tree(tmp_path, {f"scripts/{src}/a.gd": "extends RefCounted\nvar x: Dst\n", f"scripts/{dst}/b.gd" if src != dst else "scripts/zz/ignored.txt": cls("Dst")})
    if src == dst:
        (tmp_path / f"scripts/{dst}/b.gd").write_text(cls("Dst"), encoding="utf-8")
    msgs = messages(tmp_path)
    if dst in PLAN[src]:
        assert msgs == []
    else:
        assert msgs == [f"LAYER_VIOLATION: scripts/{src}/a.gd -> Dst ({src} -> {dst})"]


@pytest.mark.parametrize("line", [
    "extends Dst",
    "var x: Dst",
    "func f() -> Dst:\n\treturn null",
    "var x := y as Dst",
    "var ok := y is Dst",
    "var d := Dst.new()",
    "var v := Dst.helper()",
    'const P := preload("res://scripts/ui/dst.gd")',
    'var s := load("res://scripts/ui/dst.gd")',
])
def test_edge_forms_are_detected(tmp_path, line):
    first = line if line.startswith("extends") else "extends RefCounted\n" + line
    tree(tmp_path, {"scripts/sim/a.gd": first + "\n", "scripts/ui/dst.gd": cls("Dst")})
    assert messages(tmp_path) == ["LAYER_VIOLATION: scripts/sim/a.gd -> Dst (sim -> ui)"]


def test_preload_of_file_without_class_name_reports_the_path(tmp_path):
    tree(tmp_path, {"scripts/sim/a.gd": 'extends RefCounted\nconst P := preload("res://scripts/ui/plain.gd")\n', "scripts/ui/plain.gd": "extends RefCounted\n"})
    assert messages(tmp_path) == ["LAYER_VIOLATION: scripts/sim/a.gd -> scripts/ui/plain.gd (sim -> ui)"]


def test_comments_and_strings_are_not_edges(tmp_path):
    tree(tmp_path, {
        "scripts/sim/a.gd": 'extends RefCounted\n# Dst burada yorum\nvar s := "Dst ve # Dst"\nvar t := "kaçış \\" Dst"\nvar u := 1  # Dst\n',
        "scripts/ui/dst.gd": cls("Dst"),
    })
    assert messages(tmp_path) == []


def test_member_access_and_own_class_are_not_edges(tmp_path):
    tree(tmp_path, {"scripts/sim/a.gd": cls("Own", "var q := thing.Dst\nvar r := Own.new()\n"), "scripts/ui/dst.gd": cls("Dst")})
    assert messages(tmp_path) == []


def test_autoload_names_resolve_to_the_autoload_layer(tmp_path):
    tree(tmp_path, {
        "scripts/autoload/settings.gd": "extends Node\n",
        "scripts/autoload/events.gd": "extends Node\n",
        "scripts/sim/a.gd": "extends RefCounted\nvar s := Settings.value\n",
        "scripts/ui/b.gd": "extends Control\nvar s := Settings.value\n",
    })
    assert messages(tmp_path) == ["LAYER_VIOLATION: scripts/sim/a.gd -> Settings (sim -> autoload)"]


def test_dir_audio_maps_to_view_and_debug_to_ctrl(tmp_path):
    tree(tmp_path, {
        "scripts/audio/a.gd": "extends RefCounted\nvar x: Ui\n",
        "scripts/debug/b.gd": "extends RefCounted\nvar x: Ui\n",
        "scripts/ui/u.gd": cls("Ui"),
    })
    assert messages(tmp_path) == ["LAYER_VIOLATION: scripts/audio/a.gd -> Ui (view -> ui)"]


def test_unmapped_directory_is_reported_once(tmp_path):
    tree(tmp_path, {"scripts/yeni/a.gd": "extends RefCounted\n", "scripts/yeni/b.gd": "extends RefCounted\n", "scripts/top.gd": "extends RefCounted\n"})
    assert messages(tmp_path) == ["LAYER_UNMAPPED: scripts (üst düzey dosya: scripts/top.gd)", "LAYER_UNMAPPED: scripts/yeni (matriste yok)"]


def test_ignored_directories_are_not_scanned(tmp_path):
    files = {f"{d}/scripts/sim/a.gd": "extends RefCounted\nvar x: Ui\n" for d in (".claude/worktrees/w", ".godot", ".gate")}
    files["scripts/ui/u.gd"] = cls("Ui")
    tree(tmp_path, files)
    assert messages(tmp_path) == []


def test_listed_exception_silences_the_violation_and_stale_is_red(tmp_path):
    tree(tmp_path, {"scripts/sim/a.gd": "extends RefCounted\nvar x: Dst\n", "scripts/ui/dst.gd": cls("Dst")})
    assert messages(tmp_path, "scripts/sim/a.gd -> Dst\n") == []
    assert messages(tmp_path, "scripts/sim/a.gd -> Dst\nscripts/sim/gone.gd -> Dst  # eski\n") == ["LAYER_STALE: scripts/sim/gone.gd -> Dst"]


def test_exception_that_is_no_longer_a_violation_is_stale(tmp_path):
    tree(tmp_path, {"scripts/ui/a.gd": "extends RefCounted\nvar x: Dst\n", "scripts/sim/dst.gd": cls("Dst")})
    assert messages(tmp_path, "scripts/ui/a.gd -> Dst\n") == ["LAYER_STALE: scripts/ui/a.gd -> Dst"]


def test_new_exception_versus_base_is_red(tmp_path):
    tree(tmp_path, {"scripts/sim/a.gd": "extends RefCounted\nvar x: Dst\n", "scripts/sim/b.gd": "extends RefCounted\nvar x: Dst\n", "scripts/ui/dst.gd": cls("Dst")})
    exc = "scripts/sim/a.gd -> Dst\nscripts/sim/b.gd -> Dst\n"
    assert messages(tmp_path, exc, base="scripts/sim/a.gd -> Dst\n") == ["LAYER_NEW_EXCEPTION: scripts/sim/b.gd -> Dst"]
    assert messages(tmp_path, exc, base=exc) == []


def test_malformed_exception_line_is_reported(tmp_path):
    tree(tmp_path, {"scripts/sim/a.gd": "extends RefCounted\n"})
    assert messages(tmp_path, "bozuk satır\n")[0].startswith("LAYER_FORMAT:")


def test_dynamic_load_is_reported_as_info_not_error(tmp_path):
    tree(tmp_path, {"scripts/sim/a.gd": "extends RefCounted\nfunc f(p):\n\treturn load(p)\n", "scripts/sim/b.gd": 'extends RefCounted\nvar t := preload("res://x.tres")\n'})
    msgs, info = L.check(tmp_path, {}, None)
    assert msgs == []
    assert info == ["LAYER_DYNAMIC: scripts/sim/a.gd: 1 dinamik load(değişken) yok sayıldı"]


def test_emit_baseline_round_trips(tmp_path):
    tree(tmp_path, {
        "scripts/sim/a.gd": "extends RefCounted\nvar x: Dst\nvar y: Dst\n",
        "scripts/store/s.gd": "extends RefCounted\nvar y: Dst\n",
        "scripts/ui/dst.gd": cls("Dst"),
    })
    r = subprocess.run([sys.executable, str(TOOL), "--root", str(tmp_path), "--emit-baseline"], capture_output=True, text=True, encoding="utf-8")
    assert r.returncode == 0, r.stderr
    lines = [l for l in r.stdout.splitlines() if l and not l.startswith("#")]
    assert lines == ["scripts/sim/a.gd -> Dst", "scripts/store/s.gd -> Dst"]
    exc = tmp_path / "exc.txt"
    exc.write_text(r.stdout, encoding="utf-8")
    ok = subprocess.run([sys.executable, str(TOOL), "--root", str(tmp_path), "--exceptions", str(exc)], capture_output=True, text=True, encoding="utf-8")
    assert ok.returncode == 0, ok.stderr


def test_cli_red_on_violation_with_stderr_label(tmp_path):
    tree(tmp_path, {"scripts/sim/a.gd": "extends RefCounted\nvar x: Dst\n", "scripts/ui/dst.gd": cls("Dst")})
    exc = tmp_path / "exc.txt"
    exc.write_text("", encoding="utf-8")
    r = subprocess.run([sys.executable, str(TOOL), "--root", str(tmp_path), "--exceptions", str(exc)], capture_output=True, text=True, encoding="utf-8")
    assert r.returncode == 1 and "LAYER_VIOLATION: scripts/sim/a.gd -> Dst" in r.stderr


def test_real_repo_is_green_with_committed_baseline():
    r = subprocess.run([sys.executable, str(TOOL)], capture_output=True, text=True, cwd=ROOT, encoding="utf-8")
    assert r.returncode == 0, r.stderr


def test_committed_baseline_is_what_the_tool_emits():
    emitted = subprocess.run([sys.executable, str(TOOL), "--emit-baseline"], capture_output=True, text=True, cwd=ROOT, encoding="utf-8").stdout
    committed = (ROOT / "tools/ci/layer_exceptions.txt").read_text(encoding="utf-8")
    assert [l for l in committed.splitlines() if l and not l.startswith("#")] == [l for l in emitted.splitlines() if l and not l.startswith("#")]
