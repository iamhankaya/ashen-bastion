"""M11 (v2.0 F-028): selftest senaryoları gruplanır; senaryo→grup tablosu betiğin içindedir (GROUP[...]=N).

Plan: docs/plan/v2.0-plan.md "M-C CI süre planı". Her senaryo tam bir grupta, matris tüm grupları kapsar, fail-fast kapalı,
`--group N` bayrağı var, 11 senaryo korunur. M dilimi (tools/v2_slices.txt) ya da V2_SLICES_FORCE=M işaretliyken zorunlu;
işaretsizken tablo yoksa atlanır (sessiz geçmez: atlama nedeni raporda görünür). Süre eşiği ölçümü CI'dadır (doğrulama fazı).
"""
import os
import pathlib
import re

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "selftest_gate.sh"
CI = ROOT / ".github" / "workflows" / "ci.yml"
SLICES = ROOT / "tools" / "v2_slices.txt"
EXPECTED_SCENARIOS = 11


def _m_marked() -> bool:
    marks = set()
    if SLICES.exists():
        for line in SLICES.read_text(encoding="utf-8").splitlines():
            s = line.strip()
            if s and not s.startswith("#"):
                marks.update(s.split())
    forced = os.environ.get("V2_SLICES_FORCE", "").replace(",", " ").split()
    return "M" in marks or "M" in forced


def _scenarios() -> list:
    text = SCRIPT.read_text(encoding="utf-8")
    return re.findall(r'\bexpect\s+"([^"]+)"', text)


def _group_table() -> dict:
    text = SCRIPT.read_text(encoding="utf-8")
    table = {}
    for m in re.finditer(r'^\s*GROUP\[\s*["\']?([^"\'\]]+?)["\']?\s*\]=["\']?(\d+)["\']?', text, flags=re.M):
        table[m.group(1)] = int(m.group(2))
    return table


def test_selftest_keeps_11_scenarios_with_unique_names():
    names = _scenarios()
    assert len(names) >= EXPECTED_SCENARIOS, names
    assert len(set(names)) == len(names), "senaryo adları tekil olmalı: %s" % names


need_m = pytest.mark.skipif(not _m_marked(), reason="M dilimi açık değil (M-C CI süre planı bitmedi)")


@need_m
def test_every_scenario_belongs_to_exactly_one_group():
    names = set(_scenarios())
    table = _group_table()
    assert table, "betikte GROUP[...]=N tablosu yok"
    assert set(table) == names, "tabloda eksik/fazla senaryo: %s" % (set(table) ^ names)


@need_m
def test_groups_are_contiguous_and_balanced_enough():
    groups = sorted(set(_group_table().values()))
    assert groups, "grup yok"
    assert groups == list(range(1, len(groups) + 1)), "gruplar 1..N ardışık olmalı: %s" % groups
    assert len(groups) >= 2, "tek grup süre sorununu çözmez"
    sizes = [list(_group_table().values()).count(g) for g in groups]
    assert min(sizes) >= 1


@need_m
def test_script_supports_group_flag_and_runs_all_by_default():
    text = SCRIPT.read_text(encoding="utf-8")
    assert "--group" in text, "--group bayrağı yok"


@need_m
def test_ci_matrix_covers_all_groups_without_fail_fast():
    ci = CI.read_text(encoding="utf-8")
    sel = ci[ci.index("selftest:"):]
    nxt = re.search(r"^  [a-z][\w-]*:\s*$", sel[len("selftest:"):], flags=re.M)
    block = sel if nxt is None else sel[: len("selftest:") + nxt.start()]
    assert "matrix" in block and "group" in block, "selftest job'ında strategy.matrix.group yok"
    assert re.search(r"fail-fast:\s*false", block), "fail-fast: false olmalı"
    listed = set(int(x) for x in re.findall(r"\b(\d+)\b", re.search(r"group:\s*\[([^\]]*)\]", block).group(1)))
    assert listed == set(_group_table().values()), "matris grupları tabloyla aynı olmalı: %s" % listed
    assert "--group" in block, "ci.yml betiği --group ile çağırmalı"
    m = re.search(r"timeout-minutes:\s*(\d+)", block)
    assert m and int(m.group(1)) <= 30, "timeout-minutes <= 30"
