extends GutTest
## Stres senaryosunda deterministik iş sayaçları tools/perf_budget.json tavanlarının altında (zaman eşik değil).


func test_work_counters_stay_under_budget() -> void:
	var budget: Dictionary = KitDev.read_json("res://tools/perf_budget.json")
	var caps: Dictionary = budget
	var sc := StressScenario.new()
	var base := sc.sim.work.duplicate()
	var steps := StressScenario.STEPS
	for i in steps:
		sc.step(i)
	for k in caps.keys():
		var per_step := float(sc.sim.work[StringName(k)] - base[StringName(k)]) / steps
		assert_lte(
			per_step, float(caps[k]), "%s adım başına %.1f > tavan %s" % [k, per_step, caps[k]]
		)
	assert_eq(sc.sim.check_invariants(), PackedStringArray())
