extends GutTest
## Karakterizasyon (plan Faz 4 madde 1-3, R9a): faz alt-hash (düşman, mermi, havuz, RNG), invariant hata çıktısı ve debug kancaları.
## Yalnız public alanları okur; GameSim bölünse de (hash/invariant/debug çıkarımı) değerler değişmez.
## Baz: test/characterization/baseline/rf_sim_*.json (refactor öncesi koddan üretilir).

const STEPS := 300
const SEEDS := [11, 37]
const CHARS := [&"gunslinger", &"zyfen"]


## Her faz çağrısından sonra bileşen alt-hash'lerini kendi faz hanesine katar (faz sırası = GameSim.PHASES).
class PhaseProbe:
	extends GameSim
	var acc: Array = []

	func _init(p_seed: int, character_id: StringName, opts: Dictionary = {}) -> void:
		super(p_seed, character_id, opts)
		for k in GameSim.PHASES.size():
			acc.append([0, 0, 0, 0])

	func _phase_ticks(m: Vector2) -> void:
		super(m)
		_fold(0)

	func _phase_player_move(m: Vector2) -> void:
		super(m)
		_fold(1)

	func _phase_rebuild_hash() -> void:
		super()
		_fold(2)

	func _phase_targeting_fire() -> void:
		super()
		_fold(3)

	func _phase_skills() -> void:
		super()
		_fold(4)

	func _phase_projectiles() -> void:
		super()
		_fold(5)

	func _phase_enemy_ai() -> void:
		super()
		_fold(6)

	func _phase_deaths_xp() -> void:
		super()
		_fold(7)

	func _phase_spawn() -> void:
		super()
		_fold(8)

	func _phase_status() -> void:
		super()
		_fold(9)

	func _fold(k: int) -> void:
		var subs := [_enemy_sub(), _projectile_sub(), _pool_sub(), _rng_sub()]
		for c in 4:
			acc[k][c] = hash([acc[k][c], subs[c]])

	func _enemy_sub() -> int:
		var h := PackedInt64Array()
		for id in enemies.alive_ids():
			var i := EnemyPool.index_of(id)
			h.append(i)
			h.append(GameSim._q(enemies.pos[i].x))
			h.append(GameSim._q(enemies.pos[i].y))
			h.append(GameSim._q(enemies.hp[i]))
			h.append(GameSim._q(enemies.ai_timer[i]))
			h.append(GameSim._q(enemies.ai_aux[i]))
			h.append(GameSim._q(enemies.ai_dir[i].x))
			h.append(GameSim._q(enemies.ai_dir[i].y))
		return hash(h)

	func _projectile_sub() -> int:
		var h := PackedInt64Array([projectiles.count])
		for i in projectiles.count:
			h.append(GameSim._q(projectiles.pos[i].x))
			h.append(GameSim._q(projectiles.pos[i].y))
			h.append(GameSim._q(projectiles.vel[i].x))
			h.append(GameSim._q(projectiles.vel[i].y))
			h.append(GameSim._q(projectiles.life[i]))
			h.append(GameSim._q(projectiles.dmg[i]))
			h.append(projectiles.flags[i])
			h.append(projectiles.pierce[i])
			h.append(projectiles.bounces[i])
		return hash(h)

	func _pool_sub() -> int:
		var h := PackedInt64Array([gems.count, gems.total_value(), gems.dropped_total])
		h.append(gems.collected_total)
		for i in gems.count:
			h.append(GameSim._q(gems.pos[i].x))
			h.append(GameSim._q(gems.pos[i].y))
			h.append(gems.value[i])
		h.append_array(zones.hash_items())
		h.append_array(V11State.hash_items(self))
		return hash(h)

	func _rng_sub() -> int:
		return hash(
			PackedInt64Array(
				[
					rng_spawn.state,
					rng_choice.state,
					rng_map.state,
					rng_combat.state,
					rng_pickup.state
				]
			)
		)


func _probe(seed_value: int, character: StringName) -> PhaseProbe:
	return PhaseProbe.new(seed_value, character, {"data": GameData.load_default()})


func _sim(seed_value: int = 11) -> GameSim:
	return GameSim.new(seed_value, &"gunslinger", {"data": GameData.load_default()})


func test_rf_phase_sub_hash_trail() -> void:
	var out := {}
	for c in CHARS:
		for s in SEEDS:
			var sim := _probe(s, c)
			var n := 0
			while n < STEPS and sim.state != GameSim.State.WON and sim.state != GameSim.State.LOST:
				if sim.state == GameSim.State.LEVEL_UP:
					sim.choose(0)
					continue
				sim.step(GoldenKit.move_at(n))
				n += 1
			out["%s_%d" % [c, s]] = {
				"steps": sim.step_count, "phases": sim.acc, "hash": sim.state_hash()
			}
			assert_gt(sim.step_count, 0, "sim ilerlemeli (karakter bulundu): %s" % c)
	RfBaseline.check(self, "rf_sim_phase_sub_hash", out)


func _corrupt(s: GameSim, key: String) -> void:
	match key:
		"hp_over":
			s.hp = s.max_hp + 1.0
		"hp_nan":
			s.hp = NAN
		"pos_inf":
			s.player_pos = Vector2(INF, 0.0)
		"xp_negative":
			s.xp = -1
		"xp_over":
			s.xp = s.xp_to_next
		"time_regressed":
			s._time_regressed = true
		"magazine_range":
			s.magazine.count = -1
		"gem_conservation":
			s.gems.dropped_total += 5
		"multi":
			s.hp = s.max_hp + 1.0
			s.xp = -1
			s._time_regressed = true


func test_rf_invariants_failure_snapshot() -> void:
	var out := {"healthy": Array(_sim().check_invariants())}
	var keys := [
		"hp_over",
		"hp_nan",
		"pos_inf",
		"xp_negative",
		"xp_over",
		"time_regressed",
		"magazine_range",
		"gem_conservation",
		"multi",
	]
	for key in keys:
		var sim := _sim()
		for n in 5:
			sim.step(GoldenKit.move_at(n))
		_corrupt(sim, key)
		out[key] = Array(sim.check_invariants())
		assert_gt((out[key] as Array).size(), 0, "bozuk durum bulgu verir: %s" % key)
	assert_eq(out["healthy"], [], "sağlam sim invariant üretmez")
	RfBaseline.check(self, "rf_sim_invariants_failure", out)


func test_rf_debug_hooks_snapshot() -> void:
	var data := GameData.load_default()
	var sim := _sim(23)
	for n in 30:
		sim.step(GoldenKit.move_at(n))
	var skill: StringName = data.skill_ids[0]
	var enemy: StringName = data.enemy_ids[0]
	sim.debug_grant(skill, 2)
	var made := sim.debug_fill(enemy, 12, 300.0)
	var spawned := sim.debug_spawn(enemy, sim.player_pos + Vector2(120.0, 0.0))
	var before := sim.time
	sim.debug_set_time(sim.time - 5.0)  # geri atlama yok sayılır
	var unchanged := sim.time == before
	sim.debug_set_time(45.0)
	sim.debug_add_xp(3)
	sim.debug_force_choices([skill])
	var forced := sim.take_forced_choices()
	var again := sim.take_forced_choices()
	for n in 20:
		sim.step(GoldenKit.move_at(n))
	var levels := {}
	for s in sim.loadout.actives():
		levels[str(s.id)] = s.level
	for s in sim.loadout.passives():
		levels[str(s.id)] = s.level
	var out := {
		"made": made,
		"spawned_ok": spawned >= 0,
		"time_back_ignored": unchanged,
		"time": snappedf(sim.time, 0.0001),
		"xp": sim.xp,
		"forced": Array(forced).map(func(f: Variant) -> String: return str(f)),
		"forced_again": again.size(),
		"levels": levels,
		"alive": sim.alive_ids().size(),
		"hash": sim.state_hash(),
	}
	RfBaseline.check(self, "rf_sim_debug_hooks", out)
