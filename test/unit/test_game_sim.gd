extends GutTest
## GameSim bütünleştirme: ateş ritmi, doldurma, seviye atlama kuyruğu, oyun sonu, doğurma, determinizm.


func _near_enemy(s: GameSim, d: float = 300.0) -> int:
	return s.debug_spawn(&"curumus_piyade", s.player_pos + Vector2(d, 0))


func test_no_target_means_no_shot_and_no_ammo_use() -> void:
	var s := KitDev.sim()
	KitDev.run(s, 120)
	assert_eq(KitDev.events(s, SimEvents.SHOT).size(), 0)
	assert_eq(s.magazine.count, 6)


func test_two_pistols_alternate_with_half_interval_phase() -> void:
	var s := KitDev.sim()
	s.debug_spawn(&"sovalye_hayaleti", Vector2(400, 0))
	s.debug_spawn(&"sovalye_hayaleti", Vector2(400, 40))
	KitDev.run(s, 46)  # 0,75 sn
	var shots := KitDev.events(s, SimEvents.SHOT)
	assert_eq(shots.size(), 6, "sv1: 6 kurşun yaklaşık 0,75 sn'de biter")
	var guns := []
	for e in shots:
		guns.append(e["gun"])
	assert_eq(guns, [0, 1, 0, 1, 0, 1])
	assert_eq(shots[0]["index_in_mag"], 1)
	assert_true(shots[5]["is_last"])
	assert_false(shots[4]["is_last"])
	var gap0: int = shots[2]["step"] - shots[0]["step"]
	assert_between(gap0, 17, 19, "tabanca başına aralık 0,30 sn")
	var phase: int = shots[1]["step"] - shots[0]["step"]
	assert_between(phase, 8, 10, "yarım aralık faz farkı")


func test_empty_magazine_reloads_one_second_then_fires_again() -> void:
	var s := KitDev.sim()
	s.debug_spawn(&"sovalye_hayaleti", Vector2(400, 0))
	KitDev.run(s, 300)
	var starts := KitDev.events(s, SimEvents.RELOAD_START)
	var ends := KitDev.events(s, SimEvents.RELOAD_END)
	assert_gt(starts.size(), 0)
	assert_almost_eq(starts[0]["duration"], 1.0, 1e-4)
	assert_between(ends[0]["step"] - starts[0]["step"], 59, 61)
	var shots := KitDev.events(s, SimEvents.SHOT)
	for e in shots:
		assert_false(
			e["step"] > starts[0]["step"] and e["step"] < ends[0]["step"], "doldururken ateş yok"
		)
	assert_gt(shots.size(), 6, "doldurma sonrası ateş sürer")


func test_dry_fire_while_reloading_with_target() -> void:
	var s := KitDev.sim()
	s.debug_spawn(&"sovalye_hayaleti", Vector2(400, 0))
	KitDev.run(s, 150)
	var dry := KitDev.events(s, SimEvents.DRY_FIRE)
	assert_gt(dry.size(), 0)
	assert_lte(dry.size(), 6, "tabanca başına 0,5 sn'de bir")


func test_bullets_damage_and_kill_enemy_and_drop_gem() -> void:
	var s := KitDev.sim()
	_near_enemy(s)
	KitDev.run(s, 60)
	assert_eq(s.kills, 1)
	assert_gt(KitDev.events(s, SimEvents.DAMAGE).size(), 1)
	assert_eq(s.check_invariants(), PackedStringArray())


func test_gem_in_pickup_radius_is_collected_and_gives_xp() -> void:
	var s := KitDev.sim()
	s.gems.drop(Vector2(80, 0), 3)
	KitDev.run(s, 30)
	assert_eq(s.gems.count, 0)
	assert_eq(s.xp, 3)
	assert_eq(KitDev.events(s, SimEvents.GEM_COLLECTED).size(), 1)
	assert_eq(s.check_invariants(), PackedStringArray())


func test_gem_outside_pickup_radius_stays() -> void:
	var s := KitDev.sim()
	s.gems.drop(Vector2(400, 0), 3)
	KitDev.run(s, 30)
	assert_eq(s.gems.count, 1)


func test_level_up_freezes_sim_and_offers_choices() -> void:
	var s := KitDev.sim()
	s.debug_add_xp(12)
	s.step(Vector2.ZERO)
	assert_eq(s.state, GameSim.State.LEVEL_UP)
	assert_eq(s.level, 2)
	assert_eq(s.xp, 0)
	assert_eq(s.xp_to_next, XpCurve.need(2))
	assert_eq(s.pending_choices().size(), 3)
	var steps := s.step_count
	s.step(Vector2.RIGHT)
	assert_eq(s.step_count, steps, "LEVEL_UP'ta sim donuk")
	assert_true(s.choose(0))
	assert_eq(s.state, GameSim.State.RUNNING)
	assert_eq(KitDev.events(s, SimEvents.LEVEL_UP).size(), 1)
	assert_eq(KitDev.events(s, SimEvents.CHOICES).size(), 1)
	assert_eq(KitDev.events(s, SimEvents.CHOICE_MADE).size(), 1)


func test_multiple_levels_in_one_step_queue_choices() -> void:
	var s := KitDev.sim()
	s.debug_add_xp(12 + 16 + 20 + 3)
	s.step(Vector2.ZERO)
	assert_eq(s.level, 4)
	assert_eq(s.pending_levels, 3)
	assert_eq(s.xp, 3)
	assert_true(s.choose(0))
	assert_eq(s.state, GameSim.State.LEVEL_UP)
	assert_eq(s.pending_levels, 2)
	assert_true(s.choose(0))
	assert_true(s.choose(0))
	assert_eq(s.state, GameSim.State.RUNNING)
	assert_false(s.choose(0), "RUNNING iken false")


func test_choosing_a_passive_updates_stats_and_magazine() -> void:
	var s := KitDev.sim()
	s.debug_force_choices([&"fazladan_mermi"] as Array[StringName])
	s.debug_add_xp(12)
	s.step(Vector2.ZERO)
	assert_eq(s.pending_choices()[0].skill_id, &"fazladan_mermi")
	assert_true(s.choose(0))
	assert_eq(s.loadout.level_of(&"fazladan_mermi"), 1)
	assert_eq(s.magazine.cap, 7)
	assert_eq(s.magazine.count, 7)
	assert_eq(s.stats.mag_add, 1)


func test_choosing_max_hp_pickup_raises_current_hp_too() -> void:
	var s := KitDev.sim()
	s.debug_grant(&"saglam_yelek")
	assert_eq(s.max_hp, 115.0)
	assert_eq(s.hp, 115.0)


func test_heal_card_restores_quarter_of_max_hp() -> void:
	var s := KitDev.sim()
	s.hp = 40.0
	s.state = GameSim.State.LEVEL_UP
	s.pending_levels = 1
	var heal := Choice.new()
	heal.kind = Choice.KIND_HEAL
	heal.skill_id = Loadout.HEAL_ID
	s._choices = [heal]
	assert_true(s.choose(0))
	assert_almost_eq(s.hp, 65.0, 1e-4)


func test_death_ends_run_lost_and_cancels_pending_level_up() -> void:
	var s := KitDev.sim()
	s.debug_add_xp(12)
	s.hp = 0.0
	s.step(Vector2.ZERO)
	assert_eq(s.state, GameSim.State.LOST)
	assert_eq(s.pending_levels, 0)
	assert_eq(s.pending_choices().size(), 0)
	var run_end := KitDev.events(s, SimEvents.RUN_END)
	assert_eq(run_end.size(), 1)
	assert_false(run_end[0]["won"])
	assert_false(s.choose(0))
	var steps := s.step_count
	s.step(Vector2.ZERO)
	assert_eq(s.step_count, steps)


func test_timer_mode_wins_at_end_time_but_death_in_same_step_loses() -> void:
	var s := KitDev.sim({"end_mode": "timer", "end_time": 1.0})
	KitDev.run(s, 61)
	assert_eq(s.state, GameSim.State.WON)
	var s2 := KitDev.sim({"end_mode": "timer", "end_time": 1.0})
	KitDev.run(s2, 59)
	s2.hp = 0.0
	s2.step(Vector2.ZERO)
	assert_eq(s2.state, GameSim.State.LOST)


func test_run_ended_signal_carries_stats() -> void:
	var s := KitDev.sim()
	watch_signals(s.bus)
	s.hp = 0.0
	s.step(Vector2.ZERO)
	assert_signal_emitted(s.bus, "run_ended")
	var params = get_signal_parameters(s.bus, "run_ended")
	assert_false(params[0])
	assert_eq(params[1]["level"], 1)
	assert_true(params[1].has("time") and params[1].has("kills") and params[1].has("evolutions"))


func test_movement_uses_speed_and_stat() -> void:
	var s := KitDev.sim()
	KitDev.run(s, 60, Vector2.RIGHT)
	assert_almost_eq(s.player_pos.x, 300.0, 0.5)
	assert_false(s.player_facing_left)
	KitDev.run(s, 60, Vector2.LEFT)
	assert_true(s.player_facing_left)
	var d := KitDev.sim()
	d.debug_grant(&"cevik_cizme", 5)
	KitDev.run(d, 60, Vector2.RIGHT)
	assert_almost_eq(d.player_pos.x, 390.0, 0.5)


func test_move_vector_is_clamped_to_unit_length() -> void:
	var s := KitDev.sim()
	KitDev.run(s, 60, Vector2(5, 0))
	assert_almost_eq(s.player_pos.x, 300.0, 0.5)


func test_spawning_grows_over_time_and_respects_alive_cap() -> void:
	var s := KitDev.sim()
	KitDev.run(s, 60 * 20)
	assert_gt(KitDev.events(s, SimEvents.SPAWN).size(), 10)
	assert_lte(s.enemies.count, Difficulty.alive_cap(s.time))
	var early := KitDev.events(s, SimEvents.SPAWN).size()
	assert_gt(early, 0)


func test_spawned_enemies_appear_on_the_ring_around_player() -> void:
	var s := KitDev.sim()
	KitDev.run(s, 60 * 3)
	for e in KitDev.events(s, SimEvents.SPAWN):
		assert_almost_eq(e["pos"].distance_to(Vector2.ZERO), SpawnDirector.RING_RADIUS, 200.0)


func test_enemies_chase_player_and_contact_hurts() -> void:
	var s := KitDev.sim()
	s.debug_spawn(&"curumus_piyade", Vector2(60, 0))
	s.gun_target = PackedInt32Array([-1, -1])
	# oyuncuyu ateş edemeyecek hale getir: şarjörü boşalt ve doldurmayı uzat
	s.magazine.count = 0
	s.magazine.reloading = true
	s.magazine.reload_left = 100.0
	KitDev.run(s, 90)
	assert_lt(s.hp, 100.0)
	assert_gt(KitDev.events(s, SimEvents.DAMAGE).size(), 0)


func test_far_enemy_is_recycled_toward_movement_direction() -> void:
	var s := KitDev.sim()
	var id := s.debug_spawn(&"curumus_piyade", Vector2(-3000, 0))
	KitDev.run(s, 2, Vector2.RIGHT)
	var p := s.enemies.pos[EnemyPool.index_of(id)]
	assert_lt(p.distance_to(s.player_pos), 1500.0)


func test_debug_fill_and_spawn_loss_counter() -> void:
	var s := KitDev.sim()
	assert_eq(s.debug_fill(&"curumus_piyade", 400, 900.0), 400)
	assert_eq(s.enemies.count, 400)
	assert_eq(s.debug_fill(&"curumus_piyade", 10, 900.0), 0)
	assert_eq(s.spawn_dropped, 10)
	assert_eq(KitDev.events(s, SimEvents.SPAWN_DROPPED).size(), 10)
	assert_eq(s.check_invariants(), PackedStringArray())


func test_debug_set_time_only_moves_forward_and_scales_difficulty() -> void:
	var s := KitDev.sim()
	s.debug_set_time(900.0)
	assert_eq(s.time, 900.0)
	s.debug_set_time(100.0)
	assert_eq(s.time, 900.0)
	var id := s.debug_spawn(&"curumus_piyade", Vector2(500, 0))
	assert_almost_eq(s.enemies.max_hp[EnemyPool.index_of(id)], 30.0 * 3.9625, 1e-3)
	var s2 := KitDev.sim({"start_time": 900.0})
	assert_eq(s2.time, 900.0)


func test_last_bullet_explosion_with_son_mermi_patlar() -> void:
	var s := KitDev.sim()
	s.debug_grant(&"son_mermi_patlar")
	s.debug_spawn(&"sovalye_hayaleti", Vector2(400, 0))
	KitDev.run(s, 60)
	var ex := KitDev.events(s, SimEvents.EXPLOSION)
	assert_eq(ex.size(), 1, "yalnız son kurşun patlar")
	assert_eq(ex[0]["dmg"], 50.0)
	assert_eq(ex[0]["radius"], 100.0)
	var shots := KitDev.events(s, SimEvents.SHOT)
	assert_true(shots[5]["is_last"])


func test_barut_kesesi_scales_explosion() -> void:
	var s := KitDev.sim()
	s.debug_grant(&"son_mermi_patlar")
	s.debug_grant(&"barut_kesesi", 5)
	s.debug_spawn(&"sovalye_hayaleti", Vector2(400, 0))
	KitDev.run(s, 60)
	var ex := KitDev.events(s, SimEvents.EXPLOSION)
	assert_almost_eq(ex[0]["radius"], 160.0, 1e-3)
	assert_almost_eq(ex[0]["dmg"], 70.0, 1e-3)


func test_explosion_ignores_armor_and_hits_area() -> void:
	var s := KitDev.sim()
	var a := s.debug_spawn(&"sovalye_hayaleti", Vector2(500, 0))
	var b := s.debug_spawn(&"sovalye_hayaleti", Vector2(560, 0))
	var far := s.debug_spawn(&"sovalye_hayaleti", Vector2(900, 0))
	s.grid.clear()
	for i in EnemyPool.CAP:
		if s.enemies.alive[i] == 1:
			s.grid.insert(EnemyPool.make_id(s.enemies.gen[i], i), s.enemies.pos[i])
	s.explode(Vector2(520, 0), 100.0, 50.0, &"test")
	assert_almost_eq(s.enemies.hp[EnemyPool.index_of(a)], 170.0, 1e-3)
	assert_almost_eq(s.enemies.hp[EnemyPool.index_of(b)], 170.0, 1e-3)
	assert_almost_eq(s.enemies.hp[EnemyPool.index_of(far)], 220.0, 1e-3)


func test_ricochet_bullet_hits_several_enemies_once_each() -> void:
	var s := KitDev.sim()
	s.debug_grant(&"seken_mermi", 5)
	var ids := [
		s.debug_spawn(&"sovalye_hayaleti", Vector2(300, 0)),
		s.debug_spawn(&"sovalye_hayaleti", Vector2(380, 160)),
		s.debug_spawn(&"sovalye_hayaleti", Vector2(260, -170)),
	]
	s.grid.clear()
	for i in EnemyPool.CAP:
		if s.enemies.alive[i] == 1:
			s.grid.insert(EnemyPool.make_id(s.enemies.gen[i], i), s.enemies.pos[i])
	var pid := s.projectiles.spawn(
		Vector2(250, 0),
		Vector2(900, 0),
		10.0,
		{"bounces": 4, "flags": ProjectilePool.FLAG_RICOCHET}
	)
	assert_eq(pid, 0)
	for k in 40:
		s.step(Vector2.ZERO)
		s.grid.clear()
	var per_target := {}
	for e in KitDev.events(s, SimEvents.DAMAGE):
		if e["kind"] == &"bullet" and e["target"] in ids:
			per_target[e["target"]] = int(per_target.get(e["target"], 0)) + 1
	assert_gte(per_target.size(), 2, "sekme birden çok düşmana vurur")


func test_state_hash_equal_for_same_seed_and_differs_for_other_seed() -> void:
	var a := KitDev.sim({}, 11)
	var b := KitDev.sim({}, 11)
	var c := KitDev.sim({}, 12)
	for i in 600:
		var mv := Vector2(sin(i * 0.05), cos(i * 0.05))
		for sim in [a, b, c]:
			if sim.state == GameSim.State.LEVEL_UP:
				sim.choose(0)
			sim.step(mv)
		if i % 100 == 0:
			assert_eq(a.state_hash(), b.state_hash(), "adım %d" % i)
	assert_eq(a.state_hash(), b.state_hash())
	assert_ne(a.state_hash(), c.state_hash())


func test_invariants_hold_over_a_long_run() -> void:
	var s := KitDev.sim({"end_mode": "timer", "end_time": 600.0})
	s.debug_set_time(300.0)
	for i in 60 * 40:
		if s.state == GameSim.State.LEVEL_UP:
			s.choose(i % 3 % s.pending_choices().size())
		s.step(Vector2.from_angle(i * 0.01))
		if i % 60 == 0:
			var errs := s.check_invariants()
			assert_eq(errs, PackedStringArray(), "adım %d" % i)
			if not errs.is_empty():
				break
	assert_lte(s.enemies.count, EnemyPool.CAP)


func test_work_counters_grow() -> void:
	var s := KitDev.sim()
	_near_enemy(s)
	KitDev.run(s, 30)
	assert_gt(s.work[&"hash_inserts"], 0)
	assert_gt(s.work[&"enemy_updates"], 0)
	assert_gt(s.work[&"proj_updates"], 0)
	assert_gt(s.work[&"collision_tests"], 0)


func test_pistols_stay_half_interval_apart_after_idle_period() -> void:
	var s := KitDev.sim()
	KitDev.run(s, 30)  # hedefsiz bekleyiş
	s.debug_spawn(&"sovalye_hayaleti", Vector2(400, 0))
	KitDev.run(s, 40)
	var shots := KitDev.events(s, SimEvents.SHOT)
	assert_gte(shots.size(), 4)
	var guns := []
	for e in shots.slice(0, 4):
		guns.append(e["gun"])
	assert_eq(guns, [0, 1, 0, 1])
	assert_between(shots[1]["step"] - shots[0]["step"], 8, 10)


func test_level_counted_and_invariants_clean_when_run_ends_with_xp_pending() -> void:
	var s := KitDev.sim()
	s.debug_add_xp(12)
	s.hp = 0.0
	s.step(Vector2.ZERO)
	assert_eq(s.state, GameSim.State.LOST)
	assert_eq(s.level, 2)
	assert_eq(s.pending_levels, 0)
	assert_eq(s.check_invariants(), PackedStringArray())
