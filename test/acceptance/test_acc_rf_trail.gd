extends GutTest
## Karakterizasyon (plan Faz 4 madde 1, 3, 14): mutlak ara hash (her 60 adımda), olay günlüğü özeti, sim yan çıktıları.
## Baz: test/characterization/baseline/rf_trail_*.json (refactor öncesi koddan üretilir).

const EVERY := 60
const STEPS := 600
const SEEDS := [11, 23, 37]
const CHARS := [&"gunslinger", &"barutcu"]


func _drive(seed_value: int, character: StringName, log_events: bool) -> GameSim:
	return GameSim.new(
		seed_value, character, {"data": GameData.load_default(), "log_events": log_events}
	)


func _run(sim: GameSim, trail: Array) -> void:
	var n := 0
	while n < STEPS and sim.state != GameSim.State.WON and sim.state != GameSim.State.LOST:
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			continue
		sim.step(GoldenKit.move_at(n))
		n += 1
		if n % EVERY == 0:
			trail.append(sim.state_hash())


func test_rf_mid_hash_trail_every_60_steps() -> void:
	var out := {}
	for c in CHARS:
		for s in SEEDS:
			var sim := _drive(s, c, false)
			var trail: Array = []
			_run(sim, trail)
			out["%s_%d" % [c, s]] = {
				"trail": trail,
				"rng_combat": str(sim.rng_combat.state),
				"rng_spawn": str(sim.rng_spawn.state),
				"rng_choice": str(sim.rng_choice.state),
				"rng_map": str(sim.rng_map.state),
				"steps": sim.step_count,
			}
	RfBaseline.check(self, "rf_trail_mid_hash", out)


func test_rf_event_log_summary() -> void:
	var out := {}
	for s in SEEDS:
		var sim := _drive(s, &"gunslinger", true)
		_run(sim, [])
		var by_type := {}
		var acc := PackedStringArray()
		for e in sim.event_log:
			by_type[str(e["type"])] = int(by_type.get(str(e["type"]), 0)) + 1
			acc.append(var_to_str(e))
		out[str(s)] = {
			"count": sim.event_log.size(),
			"by_type": by_type,
			"payload_hash": hash("\n".join(acc)),
		}
	RfBaseline.check(self, "rf_trail_event_log", out)


func test_rf_sim_side_outputs() -> void:
	var out := {}
	for s in SEEDS:
		var sim := _drive(s, &"gunslinger", true)
		_run(sim, [])
		out[str(s)] = {
			"invariants": Array(sim.check_invariants()),
			"work_keys": sim.work.keys(),
			"work": sim.work,
			"kills": sim.kills,
			"level": sim.level,
			"state": sim.state,
			"hp": snappedf(sim.hp, 0.001),
		}
	RfBaseline.check(self, "rf_trail_side_outputs", out)
