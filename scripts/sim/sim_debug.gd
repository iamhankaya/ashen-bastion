class_name SimDebug
extends RefCounted
## GameSim.debug_* kancalarının mantıklı olanları (R9a çıkarımı; testler/bot/araçlar GameSim.debug_* üzerinden çağırır).


## Yuva sınırına uyar; evrim kimliği verilirse koşulsuz uygulanır.
static func grant(sim: GameSim, skill_id: StringName, lvl: int) -> void:
	var def := sim.data.get_skill(skill_id)
	if def == null:
		return
	if def.kind == SkillDef.KIND_EVOLUTION:
		sim.loadout.apply_evolution(skill_id)
		sim.evolved_log.append(skill_id)
	else:
		for k in lvl:
			sim.loadout.add_or_upgrade(skill_id)
	sim._refresh_stats()


## Stres/perf: n düşmanı halkaya koyar; doğan sayıyı döndürür.
static func fill(sim: GameSim, type_id: StringName, n: int, ring_radius: float) -> int:
	var made := 0
	for k in n:
		var a := TAU * float(k) / float(maxi(n, 1))
		if sim.spawn_enemy(type_id, sim.player_pos + Vector2.from_angle(a) * ring_radius) >= 0:
			made += 1
	return made


## Yalnızca ileri atlama; atlanan aralıktaki `at` olayları tetiklenmez.
static func set_time(sim: GameSim, t: float) -> void:
	if t <= sim.time:
		return
	sim.time = t
	sim._last_time = t
	sim.spawn_director.skip_to(t)
	sim.pickup_director.skip_to(sim.step_count)
