extends GutTest
## Sözleşme: GameSim'in gerçek (çalışan) gözlem kancaları ve sabit adım sırası.


func after_each() -> void:
	Stub.reset()


func _sim(seed_value: int = 7, opts: Dictionary = {}) -> GameSim:
	return GameSim.new(seed_value, &"gunslinger", opts)


func test_initial_state_from_character_data() -> void:
	var s := _sim()
	assert_eq(s.state, GameSim.State.RUNNING)
	assert_eq(s.step_count, 0)
	assert_eq(s.time, 0.0)
	assert_eq(s.level, 1)
	assert_eq(s.hp, 100.0)
	assert_eq(s.max_hp, 100.0)
	assert_eq(s.magazine.cap, 6)
	assert_eq(s.magazine.count, 6)
	assert_eq(s.player_pos, Vector2.ZERO)
	assert_eq(s.check_invariants(), PackedStringArray())


func test_unknown_character_does_not_crash() -> void:
	var s := GameSim.new(1, &"yok_boyle_karakter")
	assert_null(s.character)
	assert_eq(s.step_count, 0)


func test_empty_sims_with_same_seed_have_same_state_hash() -> void:
	assert_eq(_sim(42).state_hash(), _sim(42).state_hash())


func test_different_seeds_give_different_state_hash() -> void:
	assert_ne(_sim(1).state_hash(), _sim(2).state_hash())


func test_four_rng_streams_are_seeded_independently_and_deterministically() -> void:
	var a := _sim(5)
	var b := _sim(5)
	var rngs_a := [a.rng_spawn, a.rng_choice, a.rng_map, a.rng_combat]
	var rngs_b := [b.rng_spawn, b.rng_choice, b.rng_map, b.rng_combat]
	var firsts := []
	for i in 4:
		assert_eq(rngs_a[i].randi(), rngs_b[i].randi(), "akış %d aynı tohumla aynı" % i)
		firsts.append(rngs_a[i].state)
	for i in 4:
		for j in range(i + 1, 4):
			assert_ne(firsts[i], firsts[j], "akışlar farklı olmalı")


func test_consuming_one_stream_does_not_shift_another() -> void:
	var a := _sim(9)
	var b := _sim(9)
	for i in 100:
		a.rng_spawn.randi()
	assert_eq(a.rng_combat.randi(), b.rng_combat.randi())
	assert_eq(a.rng_choice.randi(), b.rng_choice.randi())
	assert_eq(a.rng_map.randi(), b.rng_map.randi())


func test_state_hash_reflects_rng_state() -> void:
	var a := _sim(3)
	var h0 := a.state_hash()
	a.rng_combat.randi()
	assert_ne(a.state_hash(), h0)


func test_step_runs_phases_in_fixed_order_and_advances_one_step() -> void:
	var s := _sim(7, {"trace_phases": true})
	s.step(Vector2.ZERO)
	assert_eq(s.step_count, 1)
	assert_almost_eq(s.time, GameSim.STEP, 1e-9)
	assert_eq(s.phase_trace, GameSim.PHASES, "10 aşama sabit sırada çağrılmalı")
	assert_eq(Stub.calls().size(), 0)
	assert_eq(GameSim.PHASES.size(), 10)


func test_step_is_noop_unless_running() -> void:
	for st in [GameSim.State.LEVEL_UP, GameSim.State.WON, GameSim.State.LOST]:
		var s := _sim()
		s.state = st
		s.step(Vector2.RIGHT)
		assert_eq(s.step_count, 0, "state %d iken step no-op" % st)
		assert_eq(Stub.calls().size(), 0)


func test_choose_invalid_returns_false_and_changes_nothing() -> void:
	var s := _sim()
	var h := s.state_hash()
	assert_false(s.choose(0), "RUNNING iken false")
	s.state = GameSim.State.LEVEL_UP
	assert_false(s.choose(-1))
	assert_false(s.choose(0), "seçenek yokken false")
	assert_false(s.choose(3))
	s.state = GameSim.State.WON
	assert_false(s.choose(0))
	s.state = GameSim.State.RUNNING
	assert_eq(s.state_hash(), h)
	assert_eq(Stub.calls().size(), 0, "geçersiz çağrı iskelete düşmez")


func test_pending_choices_is_empty_outside_level_up() -> void:
	assert_eq(_sim().pending_choices().size(), 0)


func test_work_counters_exist_and_start_at_zero() -> void:
	var w := _sim().work
	for k in GameSim.WORK_KEYS:
		assert_true(w.has(k), "work[%s]" % k)
		assert_eq(w[k], 0)
	assert_eq(GameSim.WORK_KEYS.size(), 7)


func test_event_log_is_off_by_default_and_on_with_option() -> void:
	var off := _sim()
	off.log_event(SimEvents.LEVEL_UP, {"level": 2})
	assert_eq(off.event_log.size(), 0)
	var on := _sim(1, {"log_events": true})
	on.log_event(SimEvents.LEVEL_UP, {"level": 2})
	assert_eq(on.event_log.size(), 1)
	assert_eq(on.event_log[0]["type"], SimEvents.LEVEL_UP)
	assert_eq(on.event_log[0]["step"], 0)
	assert_eq(on.event_log[0]["level"], 2)


func test_event_log_respects_max_log() -> void:
	var s := _sim(1, {"log_events": true, "max_log": 3})
	for i in 10:
		s.log_event(SimEvents.KILL, {"enemy_id": i})
	assert_eq(s.event_log.size(), 3)


func test_forced_choices_are_single_use() -> void:
	var s := _sim()
	assert_eq(s.take_forced_choices().size(), 0)
	s.debug_force_choices([&"seken_mermi", &"barut_kesesi"] as Array[StringName])
	assert_eq(s.take_forced_choices(), [&"seken_mermi", &"barut_kesesi"] as Array[StringName])
	assert_eq(s.take_forced_choices().size(), 0, "tek kullanımlık")


func test_options_end_mode_and_start_time() -> void:
	var s := _sim(1, {"end_mode": "timer", "end_time": 480.0, "start_time": 900.0})
	assert_eq(s.end_mode, "timer")
	assert_eq(s.end_time, 480.0)
	assert_eq(s.time, 900.0)
	assert_eq(_sim().end_mode, "lord")
	assert_eq(_sim().end_time, 1200.0)


func test_check_invariants_detects_violations() -> void:
	var s := _sim()
	s.hp = s.max_hp + 1.0
	assert_true(_has(s, "hp > max_hp"))
	s.hp = s.max_hp
	s.player_pos = Vector2(INF, 0)
	assert_true(_has(s, "player_pos"))
	s.player_pos = Vector2.ZERO
	s.xp = s.xp_to_next
	assert_true(_has(s, "xp >= xp_to_next"))
	s.state = GameSim.State.LEVEL_UP
	assert_false(_has(s, "xp >= xp_to_next"), "LEVEL_UP'ta xp eşiği aşabilir")
	s.state = GameSim.State.RUNNING
	s.xp = 0
	s.magazine.count = 7
	assert_true(_has(s, "magazine"))
	s.magazine.count = 6
	s.gems.dropped_total = 5
	assert_true(_has(s, "XP korunumu"))
	s.gems.dropped_total = 0
	assert_eq(s.check_invariants(), PackedStringArray())


func test_alive_ids_ascending_and_generation_checked() -> void:
	var s := _sim()
	# havuza doğrudan alan yazımı (spawn U1-1'de; burada yalnız kimlik/nesil kuralı)
	for i in [9, 2, 5]:
		s.enemies.alive[i] = 1
		s.enemies.gen[i] = 3
	var ids := s.alive_ids()
	assert_eq(ids.size(), 3)
	assert_eq(EnemyPool.index_of(ids[0]), 2)
	assert_eq(EnemyPool.index_of(ids[2]), 9)
	assert_true(s.enemies.is_alive(EnemyPool.make_id(3, 5)))
	assert_false(s.enemies.is_alive(EnemyPool.make_id(2, 5)), "nesil uyumsuzluğu false")
	assert_false(s.enemies.is_alive(EnemyPool.make_id(3, 6)))
	assert_eq(s.check_invariants(), PackedStringArray())
	var h := s.state_hash()
	s.enemies.pos[5] = Vector2(10, 0)
	assert_ne(s.state_hash(), h, "düşman konumu hash'e girer")


func test_state_hash_quantizes_positions() -> void:
	var a := _sim()
	var b := _sim()
	a.player_pos = Vector2(1.0, 0)
	b.player_pos = Vector2(1.0 + 1.0 / 256.0, 0)  # 1/64'ten küçük fark
	assert_eq(a.state_hash(), b.state_hash())
	b.player_pos = Vector2(1.0 + 1.0 / 32.0, 0)
	assert_ne(a.state_hash(), b.state_hash())


func _has(s: GameSim, part: String) -> bool:
	for e in s.check_invariants():
		if part in e:
			return true
	return false


func test_alive_ids_and_query_circle_share_one_ascending_order_across_generations() -> void:
	var s := _sim()
	s.enemies.alive[5] = 1
	s.enemies.gen[5] = 0
	s.enemies.alive[3] = 1
	s.enemies.gen[3] = 1
	s.enemies.alive[7] = 1
	s.enemies.gen[7] = 0x8000  # int32'de negatif id
	var ids := s.alive_ids()
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	assert_eq(ids, sorted_ids, "alive_ids artan id sırasında")
	var h := SpatialHash.new()
	for i in [5, 3, 7]:
		h.insert(EnemyPool.make_id(s.enemies.gen[i], i), Vector2.ZERO)
	var out := PackedInt32Array()
	h.query_circle(Vector2.ZERO, 10.0, out)
	assert_eq(out, ids, "query_circle ile aynı sıra")
	assert_true(s.enemies.is_alive(EnemyPool.make_id(0x8000, 7)))
