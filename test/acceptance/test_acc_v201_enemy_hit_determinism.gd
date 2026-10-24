extends GutTest
## Kabul (v2.0.1 T76): `SimBus.enemy_hit` yalnız bildirimdir — dinleyici bağlı/bağsız aynı tohum aynı state_hash ve event_log.
## Matris: 2 karakter × 3 politika × 2 tohum × 1800 adım, her 300 adımda hash. İki simde de log_events=true.

const SEG := 300
const STEPS := 1800
const SEEDS := [101, 202]
const CHARS := [&"gunslinger", &"zyfen"]


func _sim(seed_value: int, character: StringName) -> GameSim:
	return SimKit.make(
		seed_value, {"data_kind": "real", "character": character, "log_events": true}
	)


## [hash dizisi, event_log]
func _play(sim: GameSim, policy: StringName) -> Array:
	var rng := Bots.make_rng(7)
	var hashes: Array[int] = []
	var done := 0
	var guard := 0
	while done < STEPS and guard < STEPS * 4:
		guard += 1
		if sim.state == GameSim.State.LEVEL_UP:
			if not Bots.choose(sim, rng):
				break
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		sim.step(Bots.move(policy, sim))
		done += 1
		if done % SEG == 0:
			hashes.append(sim.state_hash())
	hashes.append(sim.state_hash())
	return [hashes, sim.event_log]


func test_enemy_hit_listener_does_not_change_state_hash_or_event_log() -> void:
	var total_hits := 0
	for character in CHARS:
		for policy in Bots.POLICIES:
			for sd in SEEDS:
				var bare := _sim(sd, character)
				var obs := _sim(sd, character)
				var hits := [0]
				var scratch := RandomNumberGenerator.new()  # dinleyici kendi RNG'sini kullanır; sim RNG'sine dokunamaz
				obs.bus.enemy_hit.connect(
					func(_p: Vector2) -> void:
						hits[0] += 1
						scratch.randf()
				)
				var a := _play(bare, policy)
				var b := _play(obs, policy)
				var label := "%s/%s/%d" % [character, policy, sd]
				assert_eq(b[0], a[0], "%s: state_hash dizisi" % label)
				assert_true(b[1] == a[1], "%s: event_log bire bir" % label)
				total_hits += hits[0]
	assert_gt(total_hits, 0, "enemy_hit gerçekten yayınlandı (matris yolu çalıştı)")


func test_enemy_hit_same_seed_two_runs_agree_with_listener() -> void:
	for character in CHARS:
		var counts: Array[int] = []
		var hashes: Array = []
		for run in 2:
			var sim := _sim(SEEDS[0], character)
			var n := [0]
			sim.bus.enemy_hit.connect(func(_p: Vector2) -> void: n[0] += 1)
			hashes.append(_play(sim, Bots.KITE)[0])
			counts.append(n[0])
		assert_eq(hashes[1], hashes[0], "%s: aynı tohum aynı hash" % character)
		assert_eq(counts[1], counts[0], "%s: aynı tohum aynı isabet sayısı" % character)
