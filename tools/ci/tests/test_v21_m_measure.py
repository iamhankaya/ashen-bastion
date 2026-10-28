"""v2.1 U1a (M dilimi): ölçüm aracı — eşleştirme anahtarı, mod bazlı sabitler, mid_report istatistikleri, ham çıktı hijyeni."""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BAL = ROOT / "tools" / "balance"
sys.path.insert(0, str(BAL))
import compare_baseline as cb  # noqa: E402
import merge_rows  # noqa: E402
import mid_report as mr  # noqa: E402


def row(mode="normal", diff="hard", seed=1, policy="strong_lord", char="gunslinger", **kw):
    r = {"mode": mode, "diff": diff, "character": char, "policy": policy, "seed": seed, "time": 700.0, "hp_mid": 0.5,
         "kills5": 400, "hp_early": 0.8, "result": "lost", "won": False, "milestone_won": False, "end_reason": "died",
         "reached_lord": False, "lord_spawn_t": -1.0, "lord_alive_secs": 0.0, "lord_end": "none", "lord_hp_frac_end": -1.0,
         "lord_hit_frac": 0.0, "lords_killed": 0, "post_lord_secs": 0.0, "level_at_1200": -1, "level_at_end": 12}
    r.update(kw)
    return r


def lord_row(seed, killed, mode="normal", diff="easy", alive=60.0, hit=0.3, hp_end=0.0):
    return row(mode, diff, seed, reached_lord=True, lord_spawn_t=1190.0, lord_end="killed" if killed else "player_died",
               lord_alive_secs=alive, lord_hit_frac=hit, lord_hp_frac_end=hp_end, won=killed, lords_killed=1 if killed else 0)


# --- compare_baseline: eşleştirme anahtarı ve mod bazlı sabitler ---


def test_m1_legacy_rows_without_mode_normalize_to_normal_hard_and_key_has_five_parts():
    r = cb.normalize({"character": "gunslinger", "policy": "strong", "seed": 7, "time": 1200.0})
    assert (r["mode"], r["diff"]) == ("normal", "hard")
    assert cb.row_key(r) == ("normal", "hard", "gunslinger", "strong", 7)


def test_m2_survival_cap_is_per_mode():
    assert cb.survival(row("quick", "normal", time=599.5)) == 600.0
    assert cb.survival(row("normal", "normal", time=599.5)) == 599.5
    assert cb.survival(row("normal", "hard", time=1199.0)) == 1200.0
    assert cb.reach10(row("quick", "normal", time=300.0)) == 1.0  # Hızlı'da orta oyun eşiği 300 sn
    assert cb.reach10(row("normal", "normal", time=300.0)) == 0.0


def test_m3_values_never_mix_cells_with_same_seed():
    rows = [row("normal", "easy", s, time=1200.0) for s in range(1, 6)] + [row("normal", "hard", s, time=100.0) for s in range(1, 6)]
    easy = cb.values(rows, "strong_lord", "survival", ("normal", "easy"))
    hard = cb.values(rows, "strong_lord", "survival", ("normal", "hard"))
    assert set(easy.values()) == {1200.0} and set(hard.values()) == {100.0}


def test_m4_compare_between_cells_pairs_by_seed_and_detects_the_shift():
    base = [row("normal", "hard", s, policy="strong_lord", time=500.0 + s) for s in range(1, 41)]
    new = [row("normal", "easy", s, policy="strong_lord", time=800.0 + s) for s in range(1, 41)]
    res = cb.compare(base + new, base + new, gate_policies=("strong_lord",), info_policies=(), boot=200,
                     base_cell=("normal", "hard"), new_cell=("normal", "easy"))
    e = res["policies"]["strong_lord"]["metrics"]["survival"]
    assert e["n_base"] == 40 and e["n_new"] == 40
    assert e["paired"]["diff"] > 0.5 and res["verdict"] == "FAIL"  # bant dışı


def test_m5_default_cells_keep_legacy_behavior():
    a = [row(seed=s, policy="strong", time=500.0 + s) for s in range(1, 41)]
    assert cb.compare(a, [dict(x) for x in a], gate_policies=("strong",), info_policies=(), boot=100)["verdict"] == "PASS"


# --- mid_report ---


def test_m6_win_reach_and_lord_time_only_from_killed_runs_with_censored_count():
    rows = [lord_row(1, True, alive=50.0), lord_row(2, True, alive=70.0), lord_row(3, False, alive=999.0), row("normal", "easy", 4)]
    s = mr.cell_stats(rows)
    assert s["n"] == 4 and s["win_pct"] == 50.0 and s["reach_pct"] == 75.0
    assert s["lord_secs_median"] == 60.0 and s["lord_censored"] == 1
    assert abs(s["hit_frac_mean"] - 0.3) < 1e-9


def test_m7_difference_ci_of_win_rate_between_two_cells():
    a = [lord_row(s, True, diff="easy") for s in range(1, 31)]
    b = [lord_row(s, False, diff="hard") for s in range(1, 31)]
    d = mr.diff_ci(a, b, lambda r: 1.0 if r["won"] else 0.0, boot=300)
    assert d == {"diff": 1.0, "lo": 1.0, "hi": 1.0}


def test_m8_quick_to_normal_level_ratio_uses_end_vs_1200():
    quick = [row("quick", "normal", s, level_at_end=14) for s in range(1, 6)]
    normal = [row("normal", "normal", s, level_at_1200=20) for s in range(1, 6)]
    assert mr.level_ratio(quick, normal) == 0.7
    assert mr.level_ratio(quick, [row("normal", "normal", 1)]) is None  # level_at_1200 hiç yok


def test_m9_sanity_checks_median_lord_hp_frac_end_of_easy_runs_that_reached_lord():
    ok = [lord_row(s, False, hp_end=0.3) for s in range(1, 8)]
    bad = [lord_row(s, False, hp_end=0.9) for s in range(1, 8)]
    assert mr.sanity(ok)["pass"] is True
    res = mr.sanity(bad)
    assert res["pass"] is False and res["median"] == 0.9
    assert mr.sanity([row("normal", "easy", 1)])["pass"] is None  # Lord'a ulaşan yok => karar yok


def test_m10_legacy_table_still_renders_rows_without_new_fields(tmp_path, capsys):
    legacy = {"character": "gunslinger", "policy": "strong", "seed": 1, "time": 1200.0, "hp_early": 0.7, "hp_mid": 0.6, "kills5": 100, "level5": 9}
    (tmp_path / "a.jsonl").write_text(json.dumps(legacy) + "\n", encoding="utf-8")
    assert mr.main([str(tmp_path)]) == 0
    out = capsys.readouterr().out
    assert "| strong | gunslinger | 1 |" in out and "| 1 |" in out.splitlines()[2]  # 20dk'ya ulaşan = 1


def test_m11_sanity_flag_sets_exit_code(tmp_path):
    (tmp_path / "a.jsonl").write_text("\n".join(json.dumps(lord_row(s, False, hp_end=0.9)) for s in range(1, 6)) + "\n", encoding="utf-8")
    assert mr.main([str(tmp_path), "--sanity", "--policy", "strong_lord"]) == 1


# --- merge_rows ---


def test_m12_merge_sorts_by_key_and_rejects_duplicates(tmp_path):
    (tmp_path / "x.jsonl").write_text(json.dumps(row(seed=2)) + "\n" + json.dumps(row(seed=1)) + "\n", encoding="utf-8")
    out = tmp_path / "out.jsonl"
    assert merge_rows.main([str(tmp_path), str(out)]) == 0
    assert [json.loads(line)["seed"] for line in out.read_text(encoding="utf-8").splitlines()] == [1, 2]
    (tmp_path / "y.jsonl").write_text(json.dumps(row(seed=1)) + "\n", encoding="utf-8")
    assert merge_rows.main([str(tmp_path), str(tmp_path / "o2.jsonl")]) == 1


# --- kaynak/hijyen sabitleri ---


def _src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_m13_max_steps_cover_lord_fight_and_endless():
    assert re.search(r"const MAX_STEPS := 144000\b", _src("tools/balance/mid_run.gd"))
    assert re.search(r"const MAX_STEPS_ENDLESS := 216000\b", _src("tools/balance/mid_run.gd"))
    assert re.search(r"const MAX_STEPS := 144000\b", _src("tools/balance/sim_run.gd"))


def test_m14_raw_output_dir_is_gitignored_and_runs_never_touch_user_dir():
    assert ".balance/" in _src(".gitignore").splitlines()
    for rel in ("tools/balance/mid_run.gd", ".github/workflows/balance.yml", "tools/balance/mid_all.sh"):
        assert "user://" not in _src(rel), rel


def test_m15_mid_run_has_two_strong_branches_and_new_output_fields():
    src = _src("tools/balance/mid_run.gd")
    assert "strong_lord" in src
    for f in ("end_reason", "reached_lord", "lord_spawn_t", "lord_alive_secs", "lord_end", "lord_hp_frac_end", "lord_hit_frac",
              "lords_killed", "post_lord_secs", "level_at_1200", "level_at_end", "milestone_won"):
        assert f'"{f}"' in src, f


def test_m16_balance_workflow_is_dispatch_only_and_splits_into_100_seed_jobs():
    wf = _src(".github/workflows/balance.yml")
    assert re.search(r"^on:\s*\n\s+workflow_dispatch:", wf, re.M) and "schedule:" not in wf and "push:" not in wf
    assert "merge_rows.py" in wf and "mid_all.sh" in wf


# --- review düzeltmeleri ---


def test_m17_endless_milestone_counts_as_win_in_reports():
    rows = [dict(lord_row(1, True, mode="endless"), won=False, milestone_won=True), lord_row(2, False, mode="endless")]
    assert mr.cell_stats(rows)["win_pct"] == 50.0
    d = mr.diff_ci(rows[:1], rows[1:], mr.is_win, boot=50)
    assert d["diff"] == 1.0


def test_m18_level_ratio_ignores_quick_runs_that_died_before_the_lord():
    quick = [row("quick", "normal", s, level_at_end=14, time=600.0) for s in range(1, 4)] + [
        row("quick", "normal", 9, level_at_end=3, time=200.0)]
    normal = [row("normal", "normal", s, level_at_1200=20) for s in range(1, 4)]
    assert mr.level_ratio(quick, normal) == 0.7


def test_m19_sanity_only_looks_at_strong_lord_rows():
    rows = [lord_row(s, False, hp_end=0.2) for s in range(1, 6)] + [
        dict(lord_row(s, False, hp_end=1.0), policy="kite") for s in range(6, 16)]
    assert mr.sanity(rows)["pass"] is True


def test_m20_compare_cli_reports_duplicate_seed_as_input_error(tmp_path, capsys):
    f = tmp_path / "a.jsonl"
    f.write_text(json.dumps(row(policy="strong", seed=1)) + "\n" + json.dumps(row(policy="strong", seed=1)) + "\n", encoding="utf-8")
    assert cb.main([str(f), str(f)]) == 2


def test_m21_mid_run_exits_nonzero_on_profile_error():
    src = _src("tools/balance/mid_run.gd")
    assert 'result.has("error")' in src and "quit(1)" in src
