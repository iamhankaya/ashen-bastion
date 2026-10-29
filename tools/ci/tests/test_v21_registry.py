"""v2.1 sözleşme (C): dilim dosyası, gate bağlantıları, profil fixture'larının güncelliği, referans karma iş akışı, şema belgesi."""
import importlib.util
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))
import check_slices  # noqa: E402


def _read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_slice_file_parses_and_has_separated_closed_symbol_lines():
    text = _read("tools/v21_slices.txt")
    ok, marks, errors = check_slices.parse(text, check_slices.V21_SYMBOLS)
    assert ok, errors
    assert marks == ["M", "S", "K", "A", "B"], "T-tur 1: tüm dilimler açık"
    lines = text.splitlines()
    idx = [i for i, ln in enumerate(lines) if re.fullmatch(r"#?[MSKAB]", ln.strip())]
    assert len(idx) == 5, "her dilim için bir simge satırı"
    assert all(b - a >= 2 for a, b in zip(idx, idx[1:])), "simge satırları bitişik olmamalı (birleşme dostu)"


def test_gate_checks_v21_slices_in_both_places():
    gate = _read("tools/gate.sh")
    assert gate.count("check_slices.py --v21 tools/v21_slices.txt") == 2
    assert "tools/v21_slices.txt .gate/junit.xml" in gate


def _gen_module():
    spec = importlib.util.spec_from_file_location("gen_profile_fixtures", HERE.parent / "gen_profile_fixtures.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_profile_fixtures_are_up_to_date_with_the_generator():
    gen = _gen_module()
    for code, fn in gen.CASES.items():
        path = ROOT / "test" / "fixtures" / f"profile_bad_{code.removeprefix('profile_')}" / "run_profiles.json"
        assert json.loads(path.read_text(encoding="utf-8")) == gen.mutate(fn), code
    assert (ROOT / "test/fixtures/profile_bad_file_missing").is_dir()
    assert not (ROOT / "test/fixtures/profile_bad_file_missing/run_profiles.json").exists()


def test_profile_fixture_dirs_do_not_use_the_data_bad_prefix():
    # test_game_data.gd her data_bad_* dizinini GameData hata kodu sayar
    assert not list((ROOT / "test" / "fixtures").glob("data_bad_profile_*"))


def test_run_catalog_data_is_one_file_per_entry_mergeable():
    # R7: modlar/zorluklar tek dosya = tek kayıt (paralel eklemede satır çakışması yok); run_profiles.json yalnız v + Lord kademeleri
    for sub, names in (("run_modes", ("quick", "normal", "endless")), ("difficulties", ("easy", "normal", "hard"))):
        for name in names:
            assert json.loads(_read(f"data/{sub}/{name}.json"))["id"] == name, (sub, name)
    json.loads(_read("data/run_profiles.json"))


def test_golden_ref_workflow_is_manual_only():
    wf = _read(".github/workflows/golden_ref.yml")
    head = wf.split("jobs:")[0]
    assert "workflow_dispatch" in head
    assert not re.search(r"^\s*(push|pull_request|schedule):", head, re.M)
    assert "gen_v21_ref.gd" in wf and "v21_ref_kit.gd" in wf


def test_schema_doc_has_run_profiles_sections():
    doc = _read("docs/data-schema.md")
    for h in (
        "## Koşu profilleri — `run_profiles.json` (v2.1)",
        "### Sim ve veri (U2)",
        "### Kayıt, skor ve başarım (U3)",
        "### Arayüz (U4a/U4b)",
    ):
        assert h in doc, h
