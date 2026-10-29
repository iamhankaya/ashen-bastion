extends GutTest
## PickupDirector: doğuş zamanlaması, tür/konum seçimi, ömür dolumu, skip_to, atlama (rng_pickup).

const SIM_OPTS := {"data_kind": "quiet", "log_events": true}


func _sim(seed_value: int = 1, opts: Dictionary = SIM_OPTS) -> GameSim:
	return SimKit.make(seed_value, opts)


func test_unarmed_without_config_and_does_not_touch_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var before := rng.state
	var d := PickupDirector.new({}, rng)
	assert_false(d.armed)
	assert_eq(rng.state, before)
	var off := _sim(3, {"data_kind": "quiet", "pickups": false})
	assert_false(off.pickup_director.armed)
	SimKit.run(off, 3000)
	assert_eq(off.pickups.count, 0)


func test_armed_with_real_data_and_first_spawn_within_window() -> void:
	var sim := _sim(7)
	assert_true(sim.pickup_director.armed)
	assert_between(sim.pickup_director.next_step, 30 * 60, 45 * 60)
	var first := sim.pickup_director.next_step
	SimKit.run_until(sim, func() -> bool: return sim.pickups.count > 0, first + 5)
	assert_eq(sim.step_count, first, "tam planlanan adımda doğar")
	assert_eq(SimKit.count_events(sim, SimEvents.PICKUP_SPAWN), 1)


func test_spawn_distance_and_clearance_over_many_seeds() -> void:
	for s in 12:
		var sim := _sim(100 + s)
		SimKit.run_until(
			sim, func() -> bool: return sim.pickups.count > 0, sim.pickup_director.next_step + 5
		)
		assert_eq(sim.pickups.count, 1)
		var d := sim.pickups.pos[0].distance_to(sim.player_pos)
		assert_between(d, 450.0 - 1.0, 700.0 + 41.0, "tohum %d" % s)
		var resolved := sim.map.resolve(sim.pickups.pos[0], 40.0)
		assert_lt(resolved.distance_to(sim.pickups.pos[0]), 0.5, "harabe içine düşmez")


func test_second_spawn_interval_and_max_alive_skip() -> void:
	var sim := _sim(11)
	var steps: Array[int] = []
	var seen := 0
	for _s in 60 * 60 * 4:
		sim.step(Vector2.ZERO)
		if SimKit.count_events(sim, SimEvents.PICKUP_SPAWN) > seen:
			seen += 1
			steps.append(sim.step_count)
		if sim.pickups.count > 0:
			sim.pickups.remove(0)  # toplanmış gibi: alive < max_alive
	assert_gt(steps.size(), 3)
	for k in range(1, steps.size()):
		assert_between(steps[k] - steps[k - 1], 45 * 60, 60 * 60, "aralık %d" % k)


func test_max_alive_skips_spawn_and_draws_next_interval() -> void:
	var sim := _sim(13)
	var rng_before := 0
	var due := sim.pickup_director.next_step
	SimKit.run_until(sim, func() -> bool: return sim.step_count >= due - 2, 4000)
	sim.debug_spawn_pickup(&"kizil_iksir", Vector2(5000, 5000))
	sim.debug_spawn_pickup(&"kizil_iksir", Vector2(5001, 5000))
	sim.step(Vector2.ZERO)
	rng_before = sim.rng_pickup.state
	sim.step(Vector2.ZERO)
	assert_eq(sim.step_count, due)
	assert_eq(sim.pickups.count, 2, "dolu: doğuş atlanır")
	assert_ne(sim.pickup_director.next_step, due, "sonraki aralık çekildi")
	assert_ne(sim.rng_pickup.state, rng_before)


func test_expiry_is_exactly_life_steps_and_emits_once() -> void:
	var sim := _sim(21)
	var i := sim.debug_spawn_pickup(&"cekim_tasi", Vector2(4000, 4000))
	assert_eq(i, 0)
	assert_eq(sim.pickups.left_steps[0], 1500)
	SimKit.run(sim, 1499)
	assert_eq(sim.pickups.count, 1)
	sim.step(Vector2.ZERO)
	assert_eq(sim.pickups.count, 0)
	var ev := SimKit.events(sim, SimEvents.PICKUP_EXPIRE)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0]["kind_id"], &"cekim_tasi")


func test_kind_distribution_follows_weights() -> void:
	var counts := {}
	var n := 200
	for s in n:
		var sim := _sim(1000 + s, {"data_kind": "quiet", "log_events": false})
		SimKit.run_until(
			sim, func() -> bool: return sim.pickups.count > 0, sim.pickup_director.next_step + 5
		)
		var id: StringName = sim.data.pickup_ids[sim.pickups.kind_idx[0]]
		counts[id] = int(counts.get(id, 0)) + 1
	var expect := {
		&"kizil_iksir": 0.30,
		&"cekim_tasi": 0.20,
		&"ofke_barutu": 0.15,
		&"kizgin_namlu": 0.15,
		&"kara_bomba": 0.15,
		&"sonsuz_tambur": 0.05,
	}
	for k in expect.keys():
		var frac := float(counts.get(k, 0)) / float(n)
		assert_almost_eq(frac, float(expect[k]), 0.09, "%s" % k)


func test_skip_to_pulls_stale_next_step_forward() -> void:
	var sim := _sim(5)
	var d := sim.pickup_director
	d.skip_to(10)
	assert_gt(d.next_step, 10, "geride değil: değişmez")
	sim.debug_set_time(900.0)
	sim.pickup_director.skip_to(54000)
	assert_eq(d.next_step, 54000)


func test_start_time_does_not_grant_free_pickup() -> void:
	var sim := _sim(9, {"data_kind": "quiet", "start_time": 900.0})
	SimKit.run(sim, 600)
	assert_eq(sim.pickups.count, 0, "ilk doğuş step_count'tan 30 sn sonra")
	assert_gte(sim.pickup_director.next_step, 30 * 60)


func test_progress_hash_is_next_step() -> void:
	var sim := _sim(2)
	assert_eq(sim.pickup_director.progress_hash(), sim.pickup_director.next_step)
