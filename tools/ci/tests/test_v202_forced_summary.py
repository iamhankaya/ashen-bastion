"""v202 zorlu koşu özeti: aşama 1 (tek süreç) ile aşama 2 (dosya başına süreç) farkı = sızıntı; aşama 2 kırmızısı = gerçek."""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE.parent / "v202_forced_summary.py"
sys.path.insert(0, str(HERE.parent))
import v202_forced_summary as vs  # noqa: E402

CLS = "res://test/acceptance/test_acc_v202_wind_skills.gd"


def _case(name, status="pass", cls=CLS):
    inner = {"pass": "", "fail": '<failure message="x"/>', "pending": '<skipped message="p"/>'}[status]
    return f'<testcase name="{name}" classname="{cls}" status="{status}" time="0.1">{inner}</testcase>'


def _xml(*cases):
    return '<testsuites><testsuite name="s" tests="%d">%s</testsuite></testsuites>' % (len(cases), "".join(cases))


def test_leak_is_stage1_red_but_stage2_green():
    s1 = vs.load(_xml(_case("test_e1_a", "fail"), _case("test_e2_b")))
    s2 = vs.load(_xml(_case("test_e1_a"), _case("test_e2_b")))
    r = vs.summarize(s1, s2)
    assert r["leak"] == [f"{CLS}::test_e1_a"]
    assert r["real"] == {} and r["pending"] == []


def test_real_red_counted_per_symbol_with_letter_suffix():
    s2 = vs.load(_xml(_case("test_e5b_x", "fail"), _case("test_z1_y", "fail"), _case("test_z2_y", "fail"), _case("test_p1_ok")))
    r = vs.summarize(s2, s2)
    assert {k: len(v) for k, v in r["real"].items()} == {"E": 1, "Z": 2}


def test_symbol_over_10_is_deferred_total_over_30_is_flagged():
    many = [_case(f"test_w{i}_x", "fail") for i in range(11)]
    r = vs.summarize(vs.load(_xml(*many)), vs.load(_xml(*many)))
    assert r["deferred"] == ["W"]
    spread = [_case(f"test_{s}{i}_x", "fail") for s in "prwzea" for i in range(6)]  # 36 toplam, simge başına 6
    r = vs.summarize(vs.load(_xml(*spread)), vs.load(_xml(*spread)))
    assert r["total_real"] == 36 and r["total_over"] and r["deferred"] == []  # toplam aşımı hangi simgenin düşeceğini seçmez: insan karar verir


def test_pending_in_stage2_is_reported():
    s2 = vs.load(_xml(_case("test_r1_x", "pending")))
    assert vs.summarize(s2, s2)["pending"] == [f"{CLS}::test_r1_x"]


def test_cli_prints_json(tmp_path):
    (tmp_path / "a.xml").write_text(_xml(_case("test_e1_a")), encoding="utf-8")
    r = subprocess.run([sys.executable, str(SCRIPT), str(tmp_path / "a.xml"), str(tmp_path / "a.xml")], capture_output=True, text=True)
    assert r.returncode == 0 and '"total_real": 0' in r.stdout
