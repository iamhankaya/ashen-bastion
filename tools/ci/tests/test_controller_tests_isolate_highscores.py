"""F-106: GameController kuran her test dosyası Highscores yolunu enjekte eder (gerçek user://highscores.json'a dokunulmaz)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BUILD = re.compile(r"\b\w*Controller\.new\(")
INJECT = re.compile(r"\bhighscores\s*=\s*Highscores\.new\(")


def test_every_controller_test_injects_a_highscores_path():
    missing = []
    for p in sorted((ROOT / "test").rglob("*.gd")):
        src = p.read_text(encoding="utf-8")
        built, injected = len(BUILD.findall(src)), len(INJECT.findall(src))
        if built > injected:
            missing.append(f"{p.relative_to(ROOT).as_posix()}: {built} kurulum, {injected} enjeksiyon")
    assert not missing, "Highscores yolu enjekte edilmiyor:\n" + "\n".join(missing)
