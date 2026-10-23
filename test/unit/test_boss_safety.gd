extends GutTest
## Kod incelemesi düzeltmeleri: Lord her koşulda doğar, doğuş rezervi, elit/Lord itilmez, state_hash AI durumunu kapsar.


func _lord_spawned(sim: GameSim) -> bool:
	return SimKit.count_events(sim, SimEvents.BOSS_SPAWN) > 0


func test_lord_spawns_even_when_the_pool_is_full() -> void:
	var sim := SimKit.make(201, {"data_kind": "fixture_waves", "start_time": 1198.0})
	SimKit.godmode(sim)
	assert_eq(sim.debug_fill(&"curumus_piyade", 400, 1100.0), 400)
	# Havuz HER adım başında yeniden doldurulur: doğal boşalma (geri taşıma/öldürme) Lord'a yer açamaz, Lord yeniden
	# denemeyle de doğamaz (satır bir kez denenir); yalnız `_make_room` açarsa test geçer (F-ver-006).
	for i in 400:
		if sim.enemies.count < EnemyPool.CAP:
			sim.debug_fill(&"curumus_piyade", EnemyPool.CAP - sim.enemies.count, 1100.0)
		SimKit.godmode(sim)
		sim.step(Vector2.ZERO)
	assert_true(
		_lord_spawned(sim), "havuz doluyken Lord yine de doğar (en uzak sıradan düşman yer açar)"
	)
	assert_eq(SimKit.count_events(sim, SimEvents.BOSS_SPAWN), 1, "Lord bir kez doğar")


func test_lord_spawns_when_time_was_skipped_past_it() -> void:
	var sim := SimKit.make(202, {"data_kind": "fixture_waves", "start_time": 1300.0})
	SimKit.godmode(sim)
	SimKit.run(sim, 30)
	assert_true(_lord_spawned(sim), "atlanmış Lord satırı kazanmayı imkânsız kılmaz")


func test_continuous_spawning_leaves_boss_reserve() -> void:
	var sim := SimKit.make(203, {"data_kind": "fixture_waves", "start_time": 1100.0})
	SimKit.godmode(sim)
	for i in 600:
		sim.step(Vector2.ZERO)
		assert_lte(
			sim.enemies.count,
			EnemyPool.CAP - SpawnDirector.BOSS_RESERVE + 60,
			"sürekli doğuş rezervi korur"
		)


func test_elites_are_not_pushed_back() -> void:
	var sim := SimKit.make(204)
	SimKit.godmode(sim)
	var id := SimKit.add_enemy(sim, &"elit_piyade", Vector2(300, 0))
	var i := EnemyPool.index_of(id)
	sim.enemies.speed[i] = 0.0
	var before := sim.enemies.pos[i]
	sim.debug_grant(&"gurleyen_yelpaze")
	SimKit.run(sim, 40)
	assert_lte(absf(sim.enemies.pos[i].x - before.x), 1.0, "elit geri itilmez")


func test_state_hash_covers_ai_state() -> void:
	var a := SimKit.make(205)
	var b := SimKit.make(205)
	var ia := EnemyPool.index_of(a.debug_spawn(&"elit_karga", Vector2(900, 0)))
	var ib := EnemyPool.index_of(b.debug_spawn(&"elit_karga", Vector2(900, 0)))
	assert_eq(a.state_hash(), b.state_hash())
	b.enemies.ai_timer[ib] += 1.0
	assert_ne(a.state_hash(), b.state_hash(), "AI zamanlayıcısı hash'e girer")
	assert_eq(ia, ib)
