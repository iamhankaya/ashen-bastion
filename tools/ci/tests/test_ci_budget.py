"""CI süre bütçesi: ci_budget.json ile ci.yml iş sınırları tutarlı; check_budget.py eşiği doğru hesaplar."""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CI = ROOT / ".github" / "workflows" / "ci.yml"
BUDGET = json.loads((ROOT / "tools" / "ci" / "ci_budget.json").read_text(encoding="utf-8"))
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import check_budget  # noqa: E402


def job_timeout(job: str) -> int:
    text = CI.read_text(encoding="utf-8")
    start = text.index(f"  {job}:")
    nxt = re.search(r"^  [\w-]+:\s*$", text[start + 1:], re.M)
    block = text[start:start + 1 + nxt.start()] if nxt else text[start:]
    return int(re.search(r"timeout-minutes:\s*(\d+)", block).group(1))


def test_ci_yml_timeouts_match_budget_file():
    # F-044: tam gate parçalandı; gate_job_minutes tek süreçli tam gate'in bütçesi (yerel gate, selftest) olarak kalır
    assert job_timeout("static") == BUDGET["static_job_minutes"]
    assert job_timeout("gut") == BUDGET["gut_shard_job_minutes"]
    assert job_timeout("test") == BUDGET["verify_job_minutes"]
    assert job_timeout("selftest") == BUDGET["selftest_job_minutes"]


def test_threshold_math():
    pct, warn = check_budget.evaluate(12 * 60, BUDGET)  # 12 dk / 15 dk = %80
    assert round(pct) == 80 and warn
    pct, warn = check_budget.evaluate(11 * 60, BUDGET)
    assert pct < 80 and not warn


def test_total_seconds_parses_times_log():
    log = "12 sn  1. Godot kurulumu\n442 sn  6. Birim + kabul (GUT)\nbaşka satır\n"
    assert check_budget.total_seconds(log) == 454


def test_cli_warns_and_strict_exit(tmp_path):
    log = tmp_path / "times.log"
    log.write_text("800 sn  6. Birim + kabul (GUT)\n", encoding="utf-8")
    tool = ROOT / "tools" / "ci" / "check_budget.py"
    r = subprocess.run([sys.executable, str(tool), str(log)], capture_output=True, text=True)
    assert r.returncode == 0 and "BÜTÇE UYARISI" in r.stdout
    assert subprocess.run([sys.executable, str(tool), str(log), "--strict"], capture_output=True, text=True).returncode == 4
    log.write_text("100 sn  x\n", encoding="utf-8")
    r2 = subprocess.run([sys.executable, str(tool), str(log), "--strict"], capture_output=True, text=True)
    assert r2.returncode == 0 and "UYARISI" not in r2.stdout
    assert subprocess.run([sys.executable, str(tool), str(tmp_path / "yok")], capture_output=True, text=True).returncode == 2
