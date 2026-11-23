"""F-ashen-bastion-062: export_presets.cfg `exclude_filter` art/ ve docs/'u APK dışı bırakır ve çalışma zamanı bu dizinlere
bağlı değildir (aksi halde dışlanan dosya APK'da eksik kalır). Gerçek dosya ve mutasyon (süzgeçten dizin çıkarma) sınanır."""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[3]
PRESETS = ROOT / "export_presets.cfg"
MUST_EXCLUDE = ("art", "docs")
RUNTIME = ["scripts", "data", "scenes", "themes"]
RUNTIME_FILES = ["project.godot", "default_bus_layout.tres"]


def excluded_dirs(cfg_text: str) -> set[str]:
    """Her preset'in exclude_filter desenlerinden `dizin/*` biçimli olanların dizin adları (preset başına kesişim)."""
    sets = []
    for m in re.finditer(r'^exclude_filter="([^"]*)"', cfg_text, re.M):
        pats = [p.strip() for p in m.group(1).split(",") if p.strip()]
        sets.append({p[:-2] for p in pats if p.endswith("/*")})
    assert sets, "export_presets.cfg'de exclude_filter yok"
    return set.intersection(*sets)


def test_real_presets_exclude_art_and_docs():
    ex = excluded_dirs(PRESETS.read_text(encoding="utf-8"))
    for d in MUST_EXCLUDE:
        assert d in ex, f"exclude_filter '{d}/*' içermiyor: APK'ya girer"


def test_removing_a_dir_from_the_filter_is_detected():
    text = PRESETS.read_text(encoding="utf-8").replace("docs/*, ", "")
    assert "docs" not in excluded_dirs(text)


def test_runtime_does_not_reference_excluded_dirs():
    pat = re.compile(r"res://(%s)/" % "|".join(MUST_EXCLUDE))
    hits = []
    files = [ROOT / f for f in RUNTIME_FILES]
    for d in RUNTIME:
        files += [p for p in (ROOT / d).rglob("*") if p.is_file() and p.suffix in {".gd", ".json", ".tscn", ".tres", ".cfg", ".gdshader"}]
    for p in files:
        if not p.is_file():
            continue
        for n, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if pat.search(line):
                hits.append(f"{p.relative_to(ROOT)}:{n}")
    assert not hits, "çalışma zamanı APK'dan dışlanan dizine bağlı: " + ", ".join(hits)
