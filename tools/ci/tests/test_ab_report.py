"""tools/balance/ab_report.py: sentetik satırlarla tablo üretimi (alan adı kayması sessiz boş tablo vermesin)."""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "balance"))
import ab_report  # noqa: E402


def row(policy, seed, pickups, time, cause="elit_piyade"):
    return {
        "policy": policy, "seed": seed, "pickups": pickups, "result": "lost", "time": time, "level": 10,
        "kills": 100, "score": 5000, "score_parts": {}, "best_mult": 5, "max_alive": 50, "hp_min": 0.0,
        "secs_below_half": 4, "late_steps": 0, "late_crowd_steps": 0, "pickups_collected": {"kizil_iksir": 2},
        "buff_uptime": {"damage": 1.0, "fire_rate": 2.0, "unlimited": 0.0}, "death_cause": cause, "violations": [],
    }


def test_tables_and_paired_difference(tmp_path):
    rows = []
    for s in range(1, 11):
        rows.append(row("kite", s, False, 300.0))
        rows.append(row("kite", s, True, 330.0, "curumus_piyade"))
    json.dump(rows[:10], open(tmp_path / "a.json", "w"))
    json.dump(rows[10:], open(tmp_path / "b.json", "w"))
    out = tmp_path / "t.md"
    ab_report.main(str(tmp_path), str(out), str(tmp_path / "combined.json"))
    text = out.read_text()
    assert "| kite | eklentili | 10 |" in text
    assert "| kite | eklentisiz | 10 |" in text
    assert "+30.0" in text  # eşli medyan fark
    assert "10 / 0" in text  # hepsi daha uzun
    assert "curumus_piyade" in text and "elit_piyade" in text


def test_quantile_and_empty_inputs():
    assert ab_report.q([1, 2, 3, 4, 5], 0.5) == 3
    assert ab_report.q([], 0.5) != ab_report.q([], 0.5)  # NaN
