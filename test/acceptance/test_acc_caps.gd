extends GutTest
## Kabul: havuz üst sınırları (CAP 400/600/300), kalabalık sahne (300+ düşman, yüzlerce mermi), XP korunumu.


func test_enemy_pool_fills_to_400_and_refuses_more() -> void:
	var sim := SimKit.make(141)
	SimKit.godmode(sim)
	assert_eq(sim.debug_fill(&"curumus_piyade", 400, 1000.0), 400)
	assert_eq(sim.enemies.count, EnemyPool.CAP)
	assert_eq(sim.debug_fill(&"curumus_piyade", 10, 1000.0), 0, "dolu havuza ek doğuş yok")
	assert_eq(sim.debug_spawn(&"curumus_piyade", Vector2(100, 100)), -1, "dolu havuz => -1")
	var ids := sim.alive_ids()
	assert_eq(ids.size(), 400)
	for i in range(1, ids.size()):
		assert_gt(ids[i], ids[i - 1], "alive_ids artan sırada")
	assert_eq(sim.check_invariants(), PackedStringArray())
	SimKit.run(sim, 120)
	assert_lte(sim.enemies.count, EnemyPool.CAP)
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_reusing_a_slot_changes_the_id_and_invalidates_the_old_one() -> void:
	var sim := SimKit.make(142)
	var old := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(900, 0))
	assert_ne(old, -1)
	sim.enemies.kill(old)
	assert_false(sim.enemies.is_alive(old), "ölen kimlik geçersiz")
	var fresh := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(-900, 0))
	assert_ne(fresh, -1)
	assert_ne(fresh, old, "aynı slot yeniden kullanılsa da kimlik (nesil) farklı")
	assert_false(sim.enemies.is_alive(old), "eski kimlik yeni düşmanı işaret etmez")
	assert_true(sim.enemies.is_alive(fresh))


func test_projectile_pool_caps_at_600() -> void:
	var sim := SimKit.make(143)
	var ok := 0
	var refused := 0
	for i in 700:
		var id := sim.spawn_projectile(Vector2(4000 + i, 4000), Vector2(10, 0), 1.0, {"life": 5.0})
		if id >= 0:
			ok += 1
		else:
			refused += 1
	assert_eq(ok, ProjectilePool.CAP)
	assert_eq(refused, 100, "CAP aşılınca spawn -1")
	assert_eq(sim.projectiles.count, ProjectilePool.CAP)
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_gem_pool_merges_at_cap_and_conserves_xp() -> void:
	var sim := SimKit.make(144)
	var total := 0
	for i in 450:
		var v := 1 + (i % 5)
		total += v
		sim.gems.drop(Vector2((i % 40) * 20.0, (i / 40) * 20.0), v)
	assert_lte(sim.gems.count, GemPool.CAP, "taş sayısı CAP'i aşmaz")
	assert_eq(sim.gems.total_value(), total, "birleşmede toplam XP değeri korunur")
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_crowd_scene_300_plus_enemies_and_hundreds_of_projectiles() -> void:
	var sim := SimKit.make(145, {"start_time": 900.0})
	SimKit.godmode(sim)
	assert_gte(Difficulty.alive_cap(900.0), 300)
	assert_eq(sim.debug_fill(&"curumus_piyade", 330, 1000.0), 330)
	var spawned := 0
	for i in 450:
		var pos := Vector2.from_angle(float(i) * 0.7) * (300.0 + float(i % 10) * 20.0)
		if sim.spawn_projectile(pos, Vector2(40, 0), 1.0, {"life": 5.0}) >= 0:
			spawned += 1
	assert_eq(spawned, 450)
	var violations := PackedStringArray()
	for i in 20:
		SimKit.run(sim, 10)
		violations.append_array(sim.check_invariants())
	assert_eq(violations, PackedStringArray())
	assert_gte(sim.enemies.count, 300, "300+ düşman aynı anda sahnede")
	assert_gte(sim.projectiles.count, 400, "yüzlerce mermi aynı anda sahnede")
	assert_eq(sim.state, GameSim.State.RUNNING)


func test_full_spawn_ring_keeps_the_simulation_alive_under_the_hard_cap() -> void:
	var sim := SimKit.make(146, {"data_kind": "real", "start_time": 1190.0})
	SimKit.godmode(sim)
	assert_eq(sim.debug_fill(&"curumus_piyade", 399, 1100.0), 399)
	SimKit.run(sim, 600)
	assert_gt(sim.enemies.count, 300, "kalabalık sürer")
	assert_lte(sim.enemies.count, EnemyPool.CAP)
	assert_eq(sim.check_invariants(), PackedStringArray())
