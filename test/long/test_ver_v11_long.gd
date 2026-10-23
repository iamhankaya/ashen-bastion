extends GutTest
## Doğrulama (T20261023-98) uzun sürüm — GATE DIŞI (dakikalar sürer): `bash tools/verify_long.sh`.
## P20 tam hali: 20 dk bot koşuları (3 politika + eklenti toplayan bot) eklentili ve eklentisiz, her 60 adımda
## `check_invariants()` boş; ölümsüz mod 20 dk'yı tamamlar; bellek (statik) koşu boyunca sınırlı kalır.

const TWENTY_MIN := 72000
const GROWTH_BUDGET_BYTES := 16_000_000


func after_all() -> void:
	SimKit.remove_tmp()


func _policies(with_pickups: bool) -> Array[StringName]:
	var out: Array[StringName] = Bots.POLICIES.duplicate()
	if with_pickups:
		out.append_array(Bots.PICKUP_POLICIES)
	return out


func test_p20_full_20_minute_godmode_runs_keep_invariants_clean() -> void:
	for with_pickups in [true, false]:
		for policy in _policies(with_pickups):
			var r := (
				AbRunner
				. run(
					{
						"seed": 2000 + absi(hash(String(policy))) % 97,
						"policy": policy,
						"pickups": with_pickups,
						"max_steps": TWENTY_MIN,
						"check_every": 60,
						"godmode": true,
					}
				)
			)
			var tag := "%s pickups=%s" % [policy, with_pickups]
			assert_eq(r["violations"], PackedStringArray(), "20 dk ölümsüz " + tag)
			assert_eq(int(r["steps"]), TWENTY_MIN, "20 dk tamamlandı " + tag)
			assert_gte(int(r["checks"]), TWENTY_MIN / 60, "her 60 adımda denetim " + tag)
			(
				gut
				. p(
					(
						"%s: level %d, öldürme %d, skor %d, en çok %d düşman, eşzamanlı≥300 oranı %.2f"
						% [
							tag,
							r["level"],
							r["kills"],
							r["score"],
							r["max_alive"],
							float(r["late_crowd_steps"]) / maxf(float(r["late_steps"]), 1.0),
						]
					)
				)
			)


func test_p20_natural_runs_to_death_or_20_minutes_keep_invariants_clean() -> void:
	for with_pickups in [true, false]:
		for policy in _policies(with_pickups):
			for sd in [11, 12, 13]:
				var r := (
					AbRunner
					. run(
						{
							"seed": sd,
							"policy": policy,
							"pickups": with_pickups,
							"max_steps": TWENTY_MIN,
							"check_every": 60,
						}
					)
				)
				assert_eq(
					r["violations"],
					PackedStringArray(),
					"doğal koşu %s pickups=%s tohum %d" % [policy, with_pickups, sd]
				)


func test_static_memory_is_bounded_over_a_20_minute_run() -> void:
	var sim := SimKit.make(51, {"data_kind": "real", "log_events": false})
	var rng := Bots.make_rng(51)
	var mid := 0
	for half in 2:
		var done := 0
		while done < TWENTY_MIN / 2:
			if sim.state == GameSim.State.LEVEL_UP:
				Bots.choose(sim, rng)
				continue
			SimKit.godmode(sim)
			sim.step(Bots.move(&"kite", sim))
			done += 1
		if half == 0:
			mid = OS.get_static_memory_usage()
	var end := OS.get_static_memory_usage()
	gut.p("statik bellek: 10 dk %.1f MB -> 20 dk %.1f MB" % [mid / 1.0e6, end / 1.0e6])
	assert_lte(end - mid, GROWTH_BUDGET_BYTES, "ikinci 10 dk'da büyüme sınırlı")
	assert_eq(sim.check_invariants(), PackedStringArray())
