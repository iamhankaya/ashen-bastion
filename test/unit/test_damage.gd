extends GutTest
## Zırh formülü, alan hasarının zırhı yok saymasi, temas tick'i (ilk tick hemen, sonra 0,6 sn, en çok 4).


func test_armor_formula() -> void:
	assert_almost_eq(DamageSystem.after_armor(15.0, 3.0), 12.0, 1e-6)
	assert_almost_eq(DamageSystem.after_armor(10.0, 9.0), 2.0, 1e-6, "en az %20")
	assert_almost_eq(DamageSystem.after_armor(10.0, 0.0), 10.0, 1e-6)


func test_bullet_uses_armor_but_explosion_ignores_it() -> void:
	var s := KitDev.sim()
	var id := s.debug_spawn(&"sovalye_hayaleti", Vector2(500, 0))
	var i := EnemyPool.index_of(id)
	var hp0 := s.enemies.hp[i]
	s.damage_enemy(id, 15.0, &"bullet")
	assert_almost_eq(s.enemies.hp[i], hp0 - 12.0, 1e-4)
	s.damage_enemy(id, 15.0, &"explosion")
	assert_almost_eq(s.enemies.hp[i], hp0 - 27.0, 1e-4)


func test_kill_drops_gem_counts_and_invalidates_id() -> void:
	var s := KitDev.sim()
	var id := s.debug_spawn(&"curumus_piyade", Vector2(500, 0))
	s.damage_enemy(id, 9999.0, &"bullet")
	assert_false(s.enemies.is_alive(id))
	assert_eq(s.kills, 1)
	assert_eq(s.gems.count, 1)
	assert_eq(s.gems.value[0], 1)
	assert_eq(KitDev.events(s, SimEvents.KILL).size(), 1)
	assert_eq(s.check_invariants(), PackedStringArray())
	s.damage_enemy(id, 5.0, &"bullet")  # ölü kimlik: etkisiz
	assert_eq(s.kills, 1)


func _contact_sim(n_enemies: int) -> GameSim:
	var s := KitDev.sim()
	for k in n_enemies:
		s.debug_spawn(&"curumus_piyade", Vector2(10 + k, 0))
	s.grid.clear()
	for i in EnemyPool.CAP:
		if s.enemies.alive[i] == 1:
			s.grid.insert(EnemyPool.make_id(s.enemies.gen[i], i), s.enemies.pos[i])
	return s


func test_contact_first_tick_is_immediate_then_every_0_6_seconds() -> void:
	var s := _contact_sim(1)
	var dmg := s.enemies.contact[0]
	assert_almost_eq(s.damage.contact_tick(s, 1.0 / 60.0), dmg, 1e-6)
	var hits := 0
	for i in 60:
		if s.damage.contact_tick(s, 1.0 / 60.0) > 0.0:
			hits += 1
	assert_eq(hits, 1, "1 sn içinde yalnız bir tick daha (0,6 sn sonra)")


func test_contact_counts_at_most_four_enemies() -> void:
	var s := _contact_sim(7)
	var each := s.enemies.contact[0]
	assert_almost_eq(s.damage.contact_tick(s, 1.0 / 60.0), 4.0 * each, 1e-4)


func test_no_contact_keeps_timer_ready() -> void:
	var s := KitDev.sim()
	assert_eq(s.damage.contact_tick(s, 1.0 / 60.0), 0.0)
	assert_eq(s.damage.contact_timer, 0.0)


func test_contact_multiplier_is_computed_at_tick_time_not_spawn_time() -> void:
	var s := _contact_sim(1)
	var base := s.enemies.contact[0]
	s.debug_set_time(600.0)  # 10. dk: enemy_dmg_mult = 1,4 (düşman t=0'da doğdu)
	assert_almost_eq(
		s.damage.contact_tick(s, 1.0 / 60.0), base * Difficulty.enemy_dmg_mult(600.0), 1e-4
	)


func test_unscaled_enemy_contact_ignores_the_difficulty_multiplier() -> void:
	var s := KitDev.sim()
	s.debug_spawn(&"curumus_piyade", Vector2(10, 0))
	var i := EnemyPool.index_of(s.alive_ids()[0])
	s.enemies.def_of(i).scales_with_time = false
	s.grid.clear()
	s.grid.insert(s.alive_ids()[0], s.enemies.pos[i])
	s.debug_set_time(600.0)
	assert_almost_eq(s.damage.contact_tick(s, 1.0 / 60.0), s.enemies.contact[i], 1e-4)
	s.enemies.def_of(i).scales_with_time = true
