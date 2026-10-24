"""compare_baseline.py: sentetik koşularla bant/gürültü/ayrıştırma mantığı (tools/balance/, gate dışı araç)."""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
BAL = HERE.parents[1] / "balance"
sys.path.insert(0, str(BAL))
import compare_baseline as cb  # noqa: E402


def rows(seed0, n, scale=1.0, policies=("strong", "kite", "greedy", "idle"), char="gunslinger", survive_frac=0.0, rng_seed=0):
    rng = np.random.default_rng(rng_seed)
    out = []
    for pol in policies:
        for k in range(n):
            t = float(np.clip(rng.normal(500, 60) * scale, 60, 1100))
            alive = k < int(n * survive_frac)
            out.append({"character": char, "policy": pol, "seed": seed0 + k, "time": 1200.0 if alive else round(t, 1),
                        "hp_mid": 0.6 if alive else (0.2 if t >= 600 else -1.0)})
    return out


def test_metrics_censor_and_zero_dead():
    assert cb.survival({"time": 1199.9}) == 1200.0
    assert cb.survival({"time": 433.2}) == 433.2
    assert cb.hp_mid({"time": 800.0, "hp_mid": 0.5}) == 0.0  # öldü => 0
    assert cb.hp_mid({"time": 1200.0, "hp_mid": 0.5}) == 0.5
    assert cb.hp_mid({"time": 1200.0, "hp_mid": -1.0}) == 0.0
    assert cb.reach10({"time": 600.0}) == 1.0 and cb.reach10({"time": 599.9}) == 0.0


def test_identical_runs_pass_and_zero_diff():
    a = rows(1, 60)
    res = cb.compare(a, [dict(r) for r in a], boot=300)
    assert res["verdict"] == "PASS"
    e = res["policies"]["strong"]["metrics"]["survival"]
    assert e["paired"]["diff"] == 0.0 and e["in_band"]


def test_ten_percent_drop_fails_but_info_policy_does_not_decide():
    a = rows(1, 60)
    b = rows(1, 60, scale=0.88)
    res = cb.compare(a, b, boot=300)
    assert res["verdict"] == "FAIL"
    only_info = cb.compare(a, b, gate_policies=(), info_policies=("strong",), boot=100)
    assert only_info["verdict"] == "VERİ YOK"


def test_small_drop_inside_band_passes():
    a = rows(1, 60)
    b = rows(1, 60, scale=0.99)
    assert cb.compare(a, b, boot=300)["verdict"] == "PASS"


def test_noise_floor_over_limit_is_unmeasurable():
    a = rows(1, 60)
    noise = rows(2001, 60, scale=0.9, rng_seed=5)  # B kümesi A'dan ~%10 farklı => gürültü > %2,5
    res = cb.compare(a, [dict(r) for r in a], noise_rows=noise, boot=200)
    assert res["verdict"] == "ÖLÇÜLEMEDİ"
    assert res["policies"]["strong"]["metrics"]["survival"]["noise"]["over_limit"]


def test_decomposition_separates_dynamite_from_filter():
    a = rows(1, 60)
    nodyn = rows(1, 60, scale=0.95)
    new = rows(1, 60, scale=0.95)  # süzgeç etkisi yok: tüm kayıp dinamitten
    res = cb.compare(a, new, nodyn_rows=nodyn, boot=300)
    d = res["policies"]["kite"]["metrics"]["survival"]["decomposition"]
    assert d["dinamit_loss"]["diff"] < -0.03
    assert abs(d["filter_other"]["diff"]) < 1e-9


def test_character_filter_and_cli(tmp_path):
    allrows = rows(1, 60) + rows(1, 60, char="zyfen", scale=0.5)
    base = tmp_path / "base.jsonl"
    new = tmp_path / "new.jsonl"
    base.write_text("".join(json.dumps(r) + "\n" for r in allrows))
    new.write_text("".join(json.dumps(r) + "\n" for r in allrows))
    out = tmp_path / "r.md"
    r = subprocess.run([sys.executable, str(BAL / "compare_baseline.py"), str(base), str(new), "--boot", "100", "--out", str(out)],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    md = out.read_text()
    assert cb.DISCLAIMER in md and "PASS" in md
    assert cb.load(str(base), "zyfen")[0]["character"] == "zyfen"


def test_cli_input_errors(tmp_path):
    r = subprocess.run([sys.executable, str(BAL / "compare_baseline.py"), str(tmp_path / "yok"), str(tmp_path / "yok2")],
                       capture_output=True, text=True)
    assert r.returncode == 2
