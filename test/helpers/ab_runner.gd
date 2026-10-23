class_name AbRunner
extends RefCounted
## Doğrulama (v1.1): bot koşusu + ölçüm. Gate'teki kısa doğrulama testleri, uzun koşu testleri ve A/B betiği
## (`tools/balance/ab_run.gd`) aynı koşucuyu kullanır; sonuçlar yalnız sözleşme yüzeyinden (bus, havuz alanları) okunur.
## Sim'e ve bot RNG'sine dokunmaz; eklentili/eklentisiz fark yalnız `opts["pickups"]` bayrağıdır.

const STEP_SECS := 1.0 / 60.0
const MAX_STEPS_FULL := 90000  # 1500 sn: Lord dövüşü de ölçülür
const LATE_START := 870.0  # 14,5 dk
const LATE_CROWD := 300


## opts: seed, policy, pickups (true), max_steps (MAX_STEPS_FULL), check_every (0 = yok), godmode (false),
## start_time (0), data ("real"|"quiet").
## Döner: tek koşunun özet sözlüğü (JSON'a yazılabilir).
static func run(opts: Dictionary) -> Dictionary:
	var seed_value: int = int(opts.get("seed", 1))
	var policy: StringName = StringName(opts.get("policy", "kite"))
	var with_pickups: bool = bool(opts.get("pickups", true))
	var max_steps: int = int(opts.get("max_steps", MAX_STEPS_FULL))
	var check_every: int = int(opts.get("check_every", 0))
	var sim_opts := {"pickups": with_pickups, "data_kind": str(opts.get("data", "real"))}
	if opts.has("end_mode"):
		sim_opts["end_mode"] = opts["end_mode"]
	if opts.has("end_time"):
		sim_opts["end_time"] = opts["end_time"]
	if opts.has("start_time"):
		sim_opts["start_time"] = opts["start_time"]
	var sim := SimKit.make(seed_value, sim_opts.merged({"log_events": false}))
	var god: bool = bool(opts.get("godmode", false))
	var rng := Bots.make_rng(seed_value)

	var collected := {}
	var starts := {}
	var death := {"cause": "", "step": -1}
	var on_pickup := func(kind: StringName, _pos: Vector2) -> void:
		collected[String(kind)] = int(collected.get(String(kind), 0)) + 1
	var on_buff := func(kind: StringName, _d: float) -> void:
		starts[String(kind)] = int(starts.get(String(kind), 0)) + 1
	var on_damage := func(_a: float, _h: float) -> void: _note_cause(sim, death)
	sim.bus.pickup_collected.connect(on_pickup)
	sim.bus.buff_started.connect(on_buff)
	sim.bus.player_damaged.connect(on_damage)

	var steps := 0
	var violations := PackedStringArray()
	var check_count := 0
	var max_alive := 0
	var hp_min := 1.0
	var below_half := 0
	var late_steps := 0
	var late_crowd := 0
	var uptime := [0, 0, 0]
	var choices := 0
	var guard := 0
	while steps < max_steps and guard < max_steps * 4 + 64:
		guard += 1
		if sim.state == GameSim.State.LEVEL_UP:
			if not Bots.choose(sim, rng):
				break
			choices += 1
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		if god:
			SimKit.godmode(sim)  # seviye atlama max_hp'yi yeniden hesaplar; her adım yeniden uygula
		sim.step(Bots.move(policy, sim))
		steps += 1
		var alive := sim.enemies.count
		max_alive = maxi(max_alive, alive)
		var frac := sim.hp / maxf(sim.max_hp, 1.0)
		hp_min = minf(hp_min, frac)
		if frac < 0.5 and steps % 60 == 0:
			below_half += 1
		if sim.time >= LATE_START:
			late_steps += 1
			if alive >= LATE_CROWD:
				late_crowd += 1
		for k in BuffManager.COUNT:
			if sim.buffs.left_steps[k] > 0:
				uptime[k] += 1
		if check_every > 0 and steps % check_every == 0:
			check_count += 1
			for v in sim.check_invariants():
				violations.append("adım %d: %s" % [sim.step_count, v])
	if check_every > 0:
		check_count += 1
		for v in sim.check_invariants():
			violations.append("adım %d (son): %s" % [sim.step_count, v])
	# Lambdalar sim'i yakalar (sim -> bus -> lambda -> sim döngüsü): bırakılmazsa koşu sonunda sızar.
	sim.bus.pickup_collected.disconnect(on_pickup)
	sim.bus.buff_started.disconnect(on_buff)
	sim.bus.player_damaged.disconnect(on_damage)
	var result := ["running", "level_up", "won", "lost"][sim.state] as String
	var buff_uptime := {}
	for k in BuffManager.COUNT:
		buff_uptime[String(BuffManager.NAMES[k])] = snappedf(float(uptime[k]) * STEP_SECS, 0.1)
	return {
		"policy": String(policy),
		"seed": seed_value,
		"pickups": with_pickups,
		"result": result,
		"steps": steps,
		"time": snappedf(sim.time, 0.1),
		"level": sim.level,
		"kills": sim.kills,
		"score": sim.score.total(),
		"score_parts": sim.score.parts(),
		"best_mult": sim.score.best_mult,
		"max_alive": max_alive,
		"hp_min": snappedf(hp_min, 0.01),
		"secs_below_half": below_half,
		"late_steps": late_steps,
		"late_crowd_steps": late_crowd,
		"evolutions": sim.evolved_log.size(),
		"choices": choices,
		"pickups_collected": collected,
		"buff_starts": starts,
		"buff_uptime": buff_uptime,
		"death_cause": String(death["cause"]) if result == "lost" else "",
		"spawn_dropped": sim.spawn_dropped,
		"checks": check_count,
		"violations": violations,
		"state_hash": sim.state_hash(),
	}


## Hasar anında (adım içinde, konumlar o fazdakiyle aynı) oyuncuya değen en yüksek temas hasarlı düşmanın türü.
static func _note_cause(sim: GameSim, death: Dictionary) -> void:
	var pr := sim.character.collision_radius
	var best := -1.0
	var cause := &"?"
	for id in sim.enemies.alive_ids():
		var i := EnemyPool.index_of(id)
		var reach := pr + sim.enemies.radius[i]
		if sim.enemies.pos[i].distance_squared_to(sim.player_pos) <= reach * reach:
			if sim.enemies.contact[i] > best:
				best = sim.enemies.contact[i]
				cause = sim.enemies.def_of(i).id
	death["cause"] = cause
	death["step"] = sim.step_count
