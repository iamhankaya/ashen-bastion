"""F-028/M11: selftest senaryo -> grup tablosu (tools/ci/selftest_gate.sh) ve ci.yml matrisi tutarlılığı."""

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "selftest_gate.sh"
CI = ROOT / ".github" / "workflows" / "ci.yml"
SCENARIOS_V11 = 11  # F-028: 11 senaryo korunur


def table():
    out = {}
    for m in re.finditer(r"^GROUP\[(\w+)\]=(\d+)\s*$", SCRIPT.read_text(), re.M):
        assert m.group(1) not in out, f"çift satır: {m.group(1)}"
        out[m.group(1)] = int(m.group(2))
    return out


def defined():
    return set(re.findall(r"^scenario_(\w+)\(\)", SCRIPT.read_text(), re.M))


def matrix_groups():
    text = CI.read_text()
    job = text[text.index("  selftest:") : text.index("  export-debug:")]
    m = re.search(r"group:\s*\[([^\]]*)\]", job)
    assert m, "selftest işinde strategy.matrix.group yok"
    return [int(x) for x in m.group(1).split(",")]


def test_eleven_scenarios_are_kept():
    assert len(table()) == SCENARIOS_V11


def test_table_matches_defined_scenarios_exactly():
    assert set(table()) == defined()


def test_every_scenario_is_in_exactly_one_group():
    t = table()
    assert all(isinstance(g, int) and g >= 1 for g in t.values())
    # tablo adı başına tek satır (çift satır table() içinde yakalanır)
    assert len(t) == len(defined())


def test_groups_are_contiguous_from_one():
    groups = sorted(set(table().values()))
    assert groups == list(range(1, len(groups) + 1))


def test_matrix_covers_all_groups_and_nothing_else():
    assert sorted(matrix_groups()) == sorted(set(table().values()))


def test_matrix_is_fail_fast_false_and_timeout_within_limit():
    text = CI.read_text()
    job = text[text.index("  selftest:") : text.index("  export-debug:")]
    assert "fail-fast: false" in job
    timeout = int(re.search(r"timeout-minutes:\s*(\d+)", job).group(1))
    assert timeout <= 30
    assert "selftest_gate.sh --group ${{ matrix.group }}" in job


def test_full_gate_scenarios_do_not_share_a_group():
    # S0: tam-gate senaryoları (≈340 s) ayrı gruplarda; aynı grupta ikisi en uzun işi 11+ dk yapar.
    heavy = [
        "taban_yesil",
        "anlamsal_hata",
        "test_kimligi_kaybi",
        "stub_todo",
        "kosmayan_test",
        "gut_error",
    ]
    t = table()
    groups = [t[h] for h in heavy]
    assert len(set(groups)) == len(groups)


def test_list_option_prints_the_table():
    r = subprocess.run(["bash", str(SCRIPT), "--list"], capture_output=True, text=True, cwd=ROOT)
    assert r.returncode == 0
    listed = dict(line.split() for line in r.stdout.strip().splitlines())
    assert {k: int(v) for k, v in listed.items()} == table()


def test_unknown_group_is_rejected():
    r = subprocess.run(
        ["bash", str(SCRIPT), "--group", "99"], capture_output=True, text=True, cwd=ROOT
    )
    assert r.returncode == 2
