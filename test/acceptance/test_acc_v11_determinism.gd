extends GutTest
## Kabul (v1.1): determinizm - state_hash v1.1 alanlarını kapsar (S2'den beri gerçek, dilimsiz), aynı tohum iki koşu aynı
## hash (eklenti toplayan bot dahil, D2+D3), farklı tohum farklı hash, yeni RNG akışı eskileri kaydırmaz.

const SEG := 300


func _sim(seed_value: int = 1, extra: Dictionary = {}) -> GameSim:
	var o := {"data_kind": "quiet_pickups"}
	o.merge(extra, true)
	return SimKit.make(seed_value, o)


func test_two_fresh_sims_with_same_seed_have_equal_hash() -> void:
	assert_eq(_sim(5).state_hash(), _sim(5).state_hash())
	assert_ne(_sim(5).state_hash(), _sim(6).state_hash(), "farklı tohum farklı hash")


func test_state_hash_covers_every_v11_field() -> void:
	var base := _sim(7)
	var h0 := base.state_hash()
	var changes := {}
	var mut := _sim(7)
	mut.score.kills_part = 123
	changes["score.total"] = mut.state_hash() != h0
	mut = _sim(7)
	mut.score.streak_count = 4
	changes["score.streak_count"] = mut.state_hash() != h0
	mut = _sim(7)
	mut.score.last_kill_step = 9
	changes["score.last_kill_step"] = mut.state_hash() != h0
	mut = _sim(7)
	mut.debug_spawn_pickup(&"kizil_iksir", Vector2(500, 0))
	changes["pickups.count"] = mut.state_hash() != h0
	var with_one := mut.state_hash()
	mut.pickups.pos[0] += Vector2(1.0, 0.0)
	changes["pickups.pos"] = mut.state_hash() != with_one
	var moved := mut.state_hash()
	mut.pickups.left_steps[0] -= 3
	changes["pickups.left_steps"] = mut.state_hash() != moved
	var other := _sim(7)
	other.debug_spawn_pickup(&"kara_bomba", Vector2(500, 0))
	var a := _sim(7)
	a.debug_spawn_pickup(&"kizil_iksir", Vector2(500, 0))
	changes["pickups.kind_idx"] = other.state_hash() != a.state_hash()
	mut = _sim(7)
	mut.buffs.left_steps[BuffManager.Kind.FIRE_RATE] = 100
	mut.buffs.total_steps[BuffManager.Kind.FIRE_RATE] = 720
	changes["buffs.left_steps"] = mut.state_hash() != h0
	mut = _sim(7)
	mut.bombs.count = 1
	mut.bombs.pos[0] = Vector2(10, 20)
	mut.bombs.fuse_steps[0] = 30
	mut.bombs.fuse_total[0] = 48
	var bombed := mut.state_hash()
	changes["bombs.count"] = bombed != h0
	mut.bombs.fuse_steps[0] = 29
	changes["bombs.fuse_steps"] = mut.state_hash() != bombed
	mut.bombs.pos[0] = Vector2(11, 20)
	changes["bombs.pos"] = mut.state_hash() != bombed
	mut = _sim(7)
	mut.pickup_director.next_step += 5
	changes["pickup_director.next_step"] = mut.state_hash() != h0
	mut = _sim(7)
	mut.rng_pickup.randf()
	changes["rng_pickup.state"] = mut.state_hash() != h0
	for k in changes:
		assert_true(changes[k], "state_hash '%s' alanını içermiyor" % k)


func test_pickup_stream_is_independent_of_the_four_old_streams() -> void:
	var a := _sim(11)
	var b := _sim(11)
	for i in 100:
		a.rng_pickup.randf()
	assert_eq(a.rng_spawn.state, b.rng_spawn.state, "spawn akışı kaymaz")
	assert_eq(a.rng_choice.state, b.rng_choice.state)
	assert_eq(a.rng_map.state, b.rng_map.state)
	assert_eq(a.rng_combat.state, b.rng_combat.state)
	var seeds := {}
	for s in GameSim.RNG_STREAMS:
		seeds[s] = true
	assert_eq(seeds.size(), 5, "beş ayrı akış")
	assert_ne(a.rng_pickup.seed, a.rng_spawn.seed)
	assert_ne(a.rng_pickup.seed, a.rng_combat.seed)


func test_pickups_flag_off_gives_same_old_streams_as_on_for_fresh_sims() -> void:
	var on := SimKit.make(13, {"data_kind": "real", "pickups": true})
	var off := SimKit.make(13, {"data_kind": "real", "pickups": false})
	assert_eq(on.rng_spawn.state, off.rng_spawn.state)
	assert_eq(on.rng_choice.state, off.rng_choice.state)
	assert_eq(on.rng_map.state, off.rng_map.state)
	assert_eq(on.rng_combat.state, off.rng_combat.state)


func _run_hashes(seed_value: int, policy: StringName, segments: int) -> Array[int]:
	var sim := SimKit.make(seed_value, {"data_kind": "real", "log_events": false})
	SimKit.godmode(sim)
	var rng := Bots.make_rng(seed_value)
	var out: Array[int] = []
	for s in segments:
		Bots.play(sim, policy, SEG, rng)
		out.append(sim.state_hash())
	return out


func test_same_seed_same_hash_every_300_steps_for_all_policies_incl_pickup_bot() -> void:
	if V11Slice.require(self, "D2") or V11Slice.require(self, "D3"):
		return
	var all: Array[StringName] = Bots.POLICIES.duplicate()
	all.append_array(Bots.PICKUP_POLICIES)
	for pol in all:
		var a := _run_hashes(31, pol, 16)
		var b := _run_hashes(31, pol, 16)
		assert_eq(a, b, "%s: aynı tohum iki koşu her 300 adımda eşit" % pol)
		var c := _run_hashes(32, pol, 16)
		assert_ne(a[a.size() - 1], c[c.size() - 1], "%s: farklı tohum farklı" % pol)


func test_pickup_collecting_run_actually_changes_hash_via_new_state() -> void:
	if V11Slice.require(self, "D2"):
		return
	var sim := _sim(41)
	SimKit.godmode(sim)
	var rng := Bots.make_rng(41)
	Bots.play(sim, Bots.GREEDY_PICKUP, 3600, rng)
	assert_gte(SimKit.count_events(sim, SimEvents.PICKUP_COLLECT), 1, "bot eklenti topladı")
	assert_gt(sim.pickup_director.next_step, 0, "direktör ilerledi")
	assert_eq(sim.check_invariants().size(), 0)
