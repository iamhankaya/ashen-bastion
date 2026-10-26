"""v2.0.3 sözleşme (N4): paralel A/B/C/D fazları için ortak kayıt dosyalarında ayrılmış satırlar/ad alanları."""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))
import check_slices  # noqa: E402

PHASES = ("a", "b", "c", "d")
SENTINELS = (
    "test/unit/test_v203_a_zz_contract.gd",
    "test/unit/test_v203_b_zz_contract.gd",
    "test/unit/test_v203_c_zz_schema.gd",
    "test/unit/test_v203_c_zz_store.gd",
    "test/unit/test_v203_d_zz_contract.gd",
)


def _read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_slice_file_parses_and_separates_symbols():
    text = _read("tools/v203_slices.txt")
    ok, marks, errors = check_slices.parse(text, ("A", "B", "C", "D"))
    assert ok, errors
    assert set(marks) <= {"A", "B", "C", "D"}, "dilim işaretini yalnız ilgili faz açar"
    lines = text.splitlines()
    idx = [i for i, ln in enumerate(lines) if re.fullmatch(r"#?[ABCD]", ln.strip())]
    assert len(idx) == 4, "her faz için bir simge satırı (açık: 'D', kapalı: '#D')"
    assert all(b - a >= 2 for a, b in zip(idx, idx[1:])), "simge satırları bitişik olmamalı (birleşme dostu)"


def test_gate_checks_v203_slices_in_both_places():
    gate = _read("tools/gate.sh")
    assert gate.count("tools/v203_slices.txt") >= 4
    assert gate.count("V203_SLICES_FORCE") >= 2


def test_every_phase_has_its_own_user_verify_file():
    for p in PHASES:
        assert (ROOT / f"docs/dev/user-verify/v2.0.3-{p}.md").is_file(), p


def test_schema_doc_has_separate_sections_per_phase():
    doc = _read("docs/data-schema.md")
    for h in (
        "## Başarım — aile/kademe (v2.0.3)",
        "### C fazı notları",
        "## Karakter ve ayar alanları (v2.0.3)",
        "### A fazı notları",
    ):
        assert h in doc, h


def test_video_output_dir_is_ignored():
    assert re.search(r"^art/source/\*/video/$", _read(".gitignore"), re.M)


def test_sentinel_rows_exist_in_registries():
    mins = json.loads(_read("tools/gate_min_tests.json"))
    weights = json.loads(_read("tools/ci/shard_weights.json"))
    for s in SENTINELS:
        assert mins.get(s, 0) >= 1, s
        assert s in weights, s
    keys = sorted(mins)
    pos = {s: keys.index(s) for s in SENTINELS}
    assert pos[SENTINELS[0]] < pos[SENTINELS[1]] < pos[SENTINELS[2]] < pos[SENTINELS[4]], "a < b < c < d sırası"
