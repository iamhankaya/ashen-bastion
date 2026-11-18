"""F-106: GameController kuran her test dosyası Highscores yolunu enjekte eder (gerçek user://highscores.json'a dokunulmaz)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BUILD = re.compile(r"\b\w*Controller\.new\(")
INJECT = re.compile(r"\bhighscores\s*=\s*Highscores\.new\(")


ADD = re.compile(r"\badd_child\w*\((\w+)\)")
INJ_VAR = re.compile(r"^\s*(\w+)\.highscores\s*=\s*Highscores\.new\(")


def late_injections(lines):
    """Enjeksiyonu add_child'dan sonra gelen satırların 1 tabanlı numaraları."""
    late = []
    for i, ln in enumerate(lines):
        m = INJ_VAR.match(ln)
        if not m:
            continue
        for j in range(i - 1, -1, -1):
            if BUILD.search(lines[j]):
                break
            a = ADD.search(lines[j])
            if a and a.group(1) == m.group(1):
                late.append(i + 1)
                break
    return late


def test_injection_happens_before_add_child():
    # _ready varsayılan Highscores'ı yükler (v1 göçü .v1.bak yazabilir): yol add_child'dan ÖNCE verilmeli.
    late = []
    for p in sorted((ROOT / "test").rglob("*.gd")):
        lines = p.read_text(encoding="utf-8").splitlines()
        late += [p.relative_to(ROOT).as_posix() + ":" + str(n) for n in late_injections(lines)]
    assert not late, "enjeksiyon add_child'dan sonra:\n" + "\n".join(late)


def test_every_controller_test_injects_a_highscores_path():
    missing = []
    for p in sorted((ROOT / "test").rglob("*.gd")):
        src = p.read_text(encoding="utf-8")
        built, injected = len(BUILD.findall(src)), len(INJECT.findall(src))
        if built > injected:
            missing.append(f"{p.relative_to(ROOT).as_posix()}: {built} kurulum, {injected} enjeksiyon")
    assert not missing, "Highscores yolu enjekte edilmiyor:\n" + "\n".join(missing)


def test_late_injection_check_actually_triggers():
    # F-171: ADD deseni gerçek bir add_child satırını yakalamalı (önceden \b yerine U+0008 vardı, kontrol hiç tetiklenmiyordu).
    late = [
        "var c := GameController.new()",
        "add_child(c)",
        "c.highscores = Highscores.new(path)",
    ]
    ok = [
        "var c := GameController.new()",
        "c.highscores = Highscores.new(path)",
        "add_child(c)",
    ]
    assert late_injections(late) == [3]
    assert late_injections(ok) == []
    assert ADD.search("\tadd_child(c)") and ADD.search("add_child_autofree(c)")
    assert "\x08" not in ADD.pattern
