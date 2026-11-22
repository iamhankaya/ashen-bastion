"""F-ashen-bastion-178: mid_all.sh içe aktarma kontrolü yalnız `.godot/imported` varlığına değil, içeriğine de bakar.

Yarım/boş import (dizin var, içi boş ya da sınıf önbelleği yok) sessizce boş çıktı üretirdi. Betik geçici bir kopyada,
sahte `GODOT_BIN` (/usr/bin/true) ile koşar: gerçek Godot'a ya da gerçek `.godot` dizinine dokunulmaz.
"""
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "balance" / "mid_all.sh"


def _run(tmp_path: pathlib.Path, *, imported: str, class_cache: bool):
    """imported: 'yok' | 'bos' | 'dolu'."""
    repo = tmp_path / "repo"
    (repo / "tools" / "balance").mkdir(parents=True)
    shutil.copy(SCRIPT, repo / "tools" / "balance" / "mid_all.sh")
    (repo / "data" / "characters").mkdir(parents=True)
    godot = repo / ".godot"
    if imported != "yok":
        (godot / "imported").mkdir(parents=True)
        if imported == "dolu":
            (godot / "imported" / "x.ctex").write_bytes(b"1")
    if class_cache:
        godot.mkdir(exist_ok=True)
        (godot / "global_script_class_cache.cfg").write_text("[x]\n", encoding="utf-8")
    env = {"PATH": "/usr/bin:/bin", "GODOT_BIN": "/usr/bin/true"}
    return subprocess.run(
        ["bash", str(repo / "tools" / "balance" / "mid_all.sh"), str(tmp_path / "out"), "1", "0", "1"],
        capture_output=True,
        text=True,
        env=env,
        cwd=repo,
    )


def test_missing_import_dir_fails(tmp_path):
    r = _run(tmp_path, imported="yok", class_cache=False)
    assert r.returncode == 1 and "HATA" in r.stderr


def test_empty_import_dir_fails(tmp_path):
    r = _run(tmp_path, imported="bos", class_cache=True)
    assert r.returncode == 1 and "HATA" in r.stderr


def test_import_without_class_cache_fails(tmp_path):
    r = _run(tmp_path, imported="dolu", class_cache=False)
    assert r.returncode == 1 and "HATA" in r.stderr


def test_complete_import_passes_the_check(tmp_path):
    r = _run(tmp_path, imported="dolu", class_cache=True)
    assert "HATA" not in r.stderr, r.stderr
    assert r.returncode == 0, r.stderr
