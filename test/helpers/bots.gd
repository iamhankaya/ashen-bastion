class_name Bots
extends RefCounted
## Deterministik bot politikaları. Bot kendi RNG'sini kullanır (seed + 1); sim'in `rng_choice`'una dokunmaz,
## koşu aynı tohumla tekrar oynatılabilir.

const IDLE := &"idle"
const KITE := &"kite"
const GREEDY := &"greedy"
const POLICIES: Array[StringName] = [IDLE, KITE, GREEDY]

const THREAT_RADIUS := 350.0
const GEM_RADIUS := 900.0


static func make_rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + 1
	return r


## Hareket vektörü (|v| <= 1).
static func move(policy: StringName, sim: GameSim) -> Vector2:
	if policy == IDLE:
		return Vector2.ZERO
	if policy == GREEDY:
		var g := _nearest_gem_dir(sim)
		if g != Vector2.ZERO:
			return g
	return _kite_dir(sim)


## Bekleyen kartlardan birini seçer: evrim varsa onu, yoksa bot RNG'siyle. true = seçim yapıldı.
static func choose(sim: GameSim, rng: RandomNumberGenerator) -> bool:
	var cards := sim.pending_choices()
	if cards.is_empty():
		return false
	var pick := rng.randi_range(0, cards.size() - 1)
	for i in cards.size():
		if cards[i].kind == Choice.KIND_EVOLUTION:
			pick = i
	return sim.choose(pick)


## `steps` adım oynar (LEVEL_UP'ta bot seçer; seçim adım sayılmaz). WON/LOST olursa durur.
## check_every > 0 ise her check_every adımda check_invariants() toplanır.
## Döner: {steps, violations: PackedStringArray, max_alive, choices_made, hp_min}
static func play(
	sim: GameSim, policy: StringName, steps: int, rng: RandomNumberGenerator, check_every: int = 0
) -> Dictionary:
	var violations := PackedStringArray()
	var max_alive := 0
	var choices_made := 0
	var hp_min := sim.hp
	var done := 0
	var guard := 0
	while done < steps and guard < steps * 4 + 64:
		guard += 1
		if sim.state == GameSim.State.LEVEL_UP:
			if not choose(sim, rng):
				break
			choices_made += 1
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		sim.step(move(policy, sim))
		done += 1
		max_alive = maxi(max_alive, sim.enemies.count)
		hp_min = minf(hp_min, sim.hp)
		if check_every > 0 and done % check_every == 0:
			violations.append_array(sim.check_invariants())
	return {
		"steps": done,
		"violations": violations,
		"max_alive": max_alive,
		"choices_made": choices_made,
		"hp_min": hp_min,
	}


static func _kite_dir(sim: GameSim) -> Vector2:
	var away := Vector2.ZERO
	for id in sim.alive_ids():
		var d: Vector2 = sim.player_pos - sim.enemies.pos[EnemyPool.index_of(id)]
		var l2 := d.length_squared()
		if l2 > 0.0001 and l2 < THREAT_RADIUS * THREAT_RADIUS:
			away += d / l2
	if away.length_squared() > 0.0:
		return away.normalized()
	var a := sim.time * 0.5
	return Vector2(cos(a), sin(a))


static func _nearest_gem_dir(sim: GameSim) -> Vector2:
	var best := GEM_RADIUS * GEM_RADIUS
	var dir := Vector2.ZERO
	for i in sim.gems.count:
		var d: Vector2 = sim.gems.pos[i] - sim.player_pos
		var l2 := d.length_squared()
		if l2 < best:
			best = l2
			dir = d
	return dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO
