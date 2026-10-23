extends SceneTree
## Masaüstü mikro-ölçüm: stres senaryosunda deterministik iş sayaçları (adım başına) + bilgi amaçlı ms/adım.
## Kullanım: godot --headless -s res://tools/perf/micro.gd [-- --json]
## Zaman (ms) yalnız bilgidir; gate'e giren değerler sayaçlardır (tools/perf_budget.json).


func _init() -> void:
	var sc := StressScenario.new()
	var base := sc.sim.work.duplicate()
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	for i in StressScenario.STEPS:
		var a := Time.get_ticks_usec()
		sc.step(i)
		worst = maxf(worst, float(Time.get_ticks_usec() - a))
	var total_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var per_step := {}
	for k in GameSim.WORK_KEYS:
		per_step[String(k)] = snappedf(float(sc.sim.work[k] - base[k]) / StressScenario.STEPS, 0.01)
	var out := {
		"steps": StressScenario.STEPS,
		"enemies_end": sc.sim.enemies.count,
		"projectiles_end": sc.sim.projectiles.count,
		"per_step": per_step,
		"info_ms_per_step": snappedf(total_ms / StressScenario.STEPS, 0.001),
		"info_worst_step_ms": snappedf(worst / 1000.0, 0.001),
		"invariants": Array(sc.sim.check_invariants()),
	}
	print(JSON.stringify(out, "  "))
	quit()
