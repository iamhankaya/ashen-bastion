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


# --- v1.1: beşinci akış, hash/değişmez eklemeleri, eklenti kancaları, StatBlock -------------------


func test_pickup_stream_is_the_fifth_and_independent_of_the_other_four() -> void:
	var a := _sim(5)
	var b := _sim(5)
	assert_eq(a.rng_pickup.randi(), b.rng_pickup.randi(), "aynı tohumla aynı")
	var firsts := [a.rng_spawn.state, a.rng_choice.state, a.rng_map.state, a.rng_combat.state]
	assert_false(firsts.has(_sim(5).rng_pickup.state), "pickup akışı diğerlerinden farklı")
	for i in 100:
		a.rng_pickup.randi()
	assert_eq(a.rng_spawn.state, b.rng_spawn.state, "pickup akışı tüketimi diğerlerini kaydırmaz")
	assert_eq(a.rng_combat.state, b.rng_combat.state)
	assert_eq(a.rng_map.state, b.rng_map.state)
	assert_eq(a.rng_choice.state, b.rng_choice.state)
	assert_ne(_sim(1).rng_pickup.state, _sim(2).rng_pickup.state)


func test_original_four_rng_streams_are_bit_identical_to_v1() -> void:
	# v1 (sözleşme öncesi) değerleri: eski dört akış eklentilerle kaymaz.
	var s := _sim(42)
	assert_eq(s.rng_spawn.state, 510336135068039531)
	assert_eq(s.rng_choice.state, 5934793932216903214)
	assert_eq(s.rng_map.state, 8303414694259264612)
	assert_eq(s.rng_combat.state, -5824027413901770946)
	var t := _sim(42)
	for i in 600:
		t.step(Vector2.RIGHT)
	assert_eq(t.rng_spawn.state, -8493515420973163873)
	assert_eq(t.rng_choice.state, 5934793932216903214)
	assert_eq(t.rng_map.state, 8303414694259264612)
	assert_eq(t.rng_combat.state, -5824027413901770946)
	assert_eq(t.enemies.count, 5)
	assert_eq(Stub.calls().size(), 0, "v1 yolu iskelet gövdelere düşmez")


func test_pickups_option_defaults_to_on_and_does_not_shift_the_other_streams() -> void:
	var on := _sim(9)
	var off := _sim(9, {"pickups": false})
	for i in 300:
		on.step(Vector2.LEFT)
		off.step(Vector2.LEFT)
	assert_eq(on.rng_spawn.state, off.rng_spawn.state)
	assert_eq(on.rng_choice.state, off.rng_choice.state)
	assert_eq(on.rng_map.state, off.rng_map.state)
	assert_eq(on.rng_combat.state, off.rng_combat.state)
	assert_eq(on.enemies.count, off.enemies.count)
	assert_eq(Stub.calls().size(), 0)


func test_state_hash_covers_the_v11_state() -> void:
	var base := _sim(3).state_hash()
	var mutators := {
		"skor": func(s: GameSim) -> void: s.score.kills_part = 10,
		"seri": func(s: GameSim) -> void: s.score.streak_count = 4,
		"son öldürme": func(s: GameSim) -> void: s.score.last_kill_step = 99,
		"eklenti sayısı":
		func(s: GameSim) -> void: s.debug_spawn_pickup(&"kizil_iksir", Vector2(500, 0)),
		"etki sayaçları": func(s: GameSim) -> void: s.buffs.left_steps[1] = 30,
		"bomba": func(s: GameSim) -> void: s.bombs.count = 1,
		"direktör": func(s: GameSim) -> void: s.pickup_director.next_step = 1800,
		"rng_pickup": func(s: GameSim) -> void: s.rng_pickup.randi(),
	}
	for k in mutators.keys():
		var s := _sim(3)
		mutators[k].call(s)
		assert_ne(s.state_hash(), base, "hash %s alanını içermeli" % k)
	var a := _sim(3)
	var b := _sim(3)
	a.debug_spawn_pickup(&"kara_bomba", Vector2(100, 200))
	b.debug_spawn_pickup(&"kara_bomba", Vector2(100, 200))
	assert_eq(a.state_hash(), b.state_hash())
	b.pickups.pos[0] = Vector2(100 + 1.0 / 32.0, 200)
	assert_ne(a.state_hash(), b.state_hash(), "eklenti konumu 1/64 px nicemlenir")
	b.pickups.pos[0] = Vector2(100 + 1.0 / 256.0, 200)
	assert_eq(a.state_hash(), b.state_hash())


func test_v11_invariants_detect_violations() -> void:
	var s := _sim()
	assert_eq(s.check_invariants(), PackedStringArray(), "temiz başlangıç")
	s.buffs.total_steps[0] = 10
	s.buffs.left_steps[0] = 11
	assert_true(_has(s, "buff 0"))
	s.buffs.left_steps[0] = 0
	s.buffs.total_steps[0] = 0
	s.buffs.left_steps[2] = 5
	s.buffs.total_steps[2] = 5
	s.magazine.count = 3
	assert_true(_has(s, "sınırsız"), "sınırsız etkinken magazine.count == cap")
	s.magazine.count = s.magazine.cap
	s.buffs.left_steps[2] = 0
	s.buffs.total_steps[2] = 0
	s.bombs.count = 5
	assert_true(_has(s, "bombs.count > CAP"))
	s.bombs.count = 0
	s.bombs.count = 1
	s.bombs.fuse_total[0] = 48
	s.bombs.fuse_steps[0] = 49
	assert_true(_has(s, "bomba 0"))
	s.bombs.count = 0
	s.score.mult = 6
	assert_true(_has(s, "SERİ çarpanı"), "çarpan tablo üst sınırını aşamaz")
	s.score.mult = 0
	assert_true(_has(s, "SERİ çarpanı"))
	s.score.mult = 5
	assert_false(_has(s, "SERİ çarpanı"))
	s.score.mult = 1
	s.score.kills_part = -1
	assert_true(_has(s, "skor bileşeni"))
	s.score.kills_part = 100
	assert_false(_has(s, "geriye"))
	s.score.kills_part = 50
	assert_true(_has(s, "skor geriye gitti"), "toplam skor monoton azalmaz")
	s.score.kills_part = 100
	assert_eq(s.check_invariants(), PackedStringArray())
	s.pickups.count = 9
	assert_true(_has(s, "pickups.count > CAP"))
	s.pickups.count = 0
	assert_eq(s.check_invariants(), PackedStringArray())


func test_debug_spawn_pickup_places_a_real_pickup_and_reports_it() -> void:
	var s := _sim(1, {"log_events": true})
	var seen: Array = []
	s.bus.pickup_spawned.connect(func(id: StringName, pos: Vector2) -> void: seen.append([id, pos]))
	var i := s.debug_spawn_pickup(&"kizil_iksir", Vector2(300, 40))
	assert_eq(i, 0)
	assert_eq(s.pickups.count, 1)
	assert_eq(s.pickups.pos[0], Vector2(300, 40))
	assert_eq(s.pickups.kind_idx[0], 0, "kinds dizi sırası")
	assert_eq(s.pickups.left_steps[0], 1500, "ömür 25 sn = 1500 adım")
	assert_eq(s.pickups.age_steps[0], 0)
	assert_eq(seen, [[&"kizil_iksir", Vector2(300, 40)]])
	var ev := s.event_log.filter(
		func(e: Dictionary) -> bool: return e["type"] == SimEvents.PICKUP_SPAWN
	)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0]["kind_id"], &"kizil_iksir")
	assert_eq(s.debug_spawn_pickup(&"yok_boyle", Vector2.ZERO), -1, "bilinmeyen tür")
	assert_eq(s.pickups.count, 1)
	assert_eq(s.debug_spawn_pickup(&"sonsuz_tambur", Vector2(1, 1)), 1)
	assert_eq(s.pickups.uid[1], s.pickups.uid[0] + 1, "uid monoton artar")
	for k in 6:
		s.debug_spawn_pickup(&"cekim_tasi", Vector2(k, 0))
	assert_eq(s.pickups.count, PickupPool.CAP)
	assert_eq(s.debug_spawn_pickup(&"cekim_tasi", Vector2.ZERO), -1, "havuz dolu")
	assert_eq(s.check_invariants(), PackedStringArray())
	assert_eq(Stub.calls().size(), 0)


func test_debug_collect_pickups_is_idle_without_pickups_and_hits_the_skeleton_with_one() -> void:
	var s := _sim()
	s.debug_collect_pickups()
	assert_eq(Stub.calls().size(), 0, "boşta no-op")
	s.debug_spawn_pickup(&"kizil_iksir", s.player_pos)
	s.debug_collect_pickups()
	assert_eq(
		Stub.calls(),
		[&"PickupSystem.collect"] as Array[StringName],
		"iskelet gövde başarısızlık kaydeder"
	)


func test_skeleton_hooks_are_idle_in_a_plain_run_and_never_reach_stubs() -> void:
	var s := _sim(11, {"end_mode": "timer", "end_time": 40.0})
	s.debug_set_time(5.0)
	for i in 1800:
		if s.state == GameSim.State.LEVEL_UP:
			s.choose(0)
		s.step(Vector2.RIGHT)
	assert_eq(
		Stub.calls().size(), 0, "v1 koşusunda hiçbir v1.1 iskeleti çağrılmaz: %s" % [Stub.calls()]
	)


func test_score_gained_becomes_a_bus_signal_and_an_event() -> void:
	var s := _sim(1, {"log_events": true})
	var got: Array = []
	s.bus.score_changed.connect(func(sc: int, m: int, g: int) -> void: got.append([sc, m, g]))
	s.score.kills_part = 40
	s.score.mult = 2
	s.score.gained.emit(40, &"kill")
	assert_eq(got, [[40, 2, 40]])
	var ev := s.event_log.filter(func(e: Dictionary) -> bool: return e["type"] == SimEvents.SCORE)
	assert_eq(ev.size(), 1)
	assert_eq([ev[0]["gain"], ev[0]["total"], ev[0]["mult"], ev[0]["source"]], [40, 40, 2, &"kill"])
	var streaks: Array = []
	s.bus.streak_changed.connect(func(m: int, left: float) -> void: streaks.append([m, left]))
	s.score.streak_changed.emit(1, 0.0)
	assert_eq(streaks, [[1, 0.0]])


func test_run_ended_carries_the_score_fields_next_to_the_v1_ones() -> void:
	var s := _sim(1, {"end_mode": "timer", "end_time": 2.0})
	var got: Array = []
	s.bus.run_ended.connect(func(won: bool, st: Dictionary) -> void: got.append([won, st]))
	for i in 130:
		s.step(Vector2.ZERO)
	assert_eq(got.size(), 1)
	var st: Dictionary = got[0][1]
	for k in ["time", "level", "kills", "evolutions", "score", "score_parts", "best_mult"]:
		assert_true(st.has(k), "run_ended.%s" % k)
	assert_eq(st["score"], 10, "boşta yalnız hayatta kalma: 130 adım x 5 / 60 = 10 (D3-1)")
	assert_eq(st["best_mult"], 1)
	var parts: Dictionary = st["score_parts"]
	assert_eq(parts.keys(), ["kills", "streak", "evolution", "survival", "lord"])
	assert_eq(Stub.calls().size(), 0)


func test_debug_set_time_forwards_to_the_pickup_director_without_skeleton_calls() -> void:
	var s := _sim()
	s.debug_set_time(120.0)
	assert_eq(s.time, 120.0)
	assert_eq(Stub.calls().size(), 0)


func test_stat_block_separates_base_from_effective_values() -> void:
	var st := StatBlock.new()
	assert_eq(st.buff_dmg_mult, 1.0)
	assert_eq(st.buff_rate_mult, 1.0)
	st.set_buffs(1.5, 1.4)
	assert_almost_eq(st.bullet_dmg_mult, 1.5, 1e-6)
	assert_almost_eq(st.explosion_dmg_mult, 1.5, 1e-6, "hasar patlamayı da çarpar")
	assert_almost_eq(st.fire_rate_mult, 1.4, 1e-6)
	assert_eq(st.reload_time_mult, 1.0, "diğer alanlar etkilenmez")
	st.set_buffs(1.0, 1.0)
	assert_eq(st.bullet_dmg_mult, 1.0)
	assert_eq(st.fire_rate_mult, 1.0)


func test_stat_block_rebuild_keeps_the_active_buffs_on_top_of_new_passives() -> void:
	var s := _sim()
	s.debug_grant(&"barut_kesesi", 3)  # explosion_dmg_mult pasifi
	var base3 := s.stats.explosion_dmg_mult
	assert_gt(base3, 1.0)
	s.stats.set_buffs(1.5, 1.4)
	assert_almost_eq(s.stats.explosion_dmg_mult, base3 * 1.5, 1e-6)
	s.debug_grant(&"barut_kesesi", 1)  # seviye 4: rebuild; etki korunur, taban güncellenir
	var ref := _sim()
	ref.debug_grant(&"barut_kesesi", 4)
	assert_gt(ref.stats.explosion_dmg_mult, base3, "seviye 4 tabanı daha yüksek")
	assert_almost_eq(s.stats.explosion_dmg_mult, ref.stats.explosion_dmg_mult * 1.5, 1e-6)
	assert_almost_eq(s.stats.fire_rate_mult, ref.stats.fire_rate_mult * 1.4, 1e-6)
	s.stats.set_buffs(1.0, 1.0)
	assert_almost_eq(
		s.stats.explosion_dmg_mult,
		ref.stats.explosion_dmg_mult,
		1e-6,
		"etki kalkınca taban görünür"
	)
	assert_eq(s.check_invariants(), PackedStringArray())
