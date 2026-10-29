extends GutTest
## SimProjectiles (R9b): mermi hareketi, çarpışma, delme/sekme ve süre sonu patlaması; GameSim._phase_projectiles ince kabuktur.


func _sim() -> GameSim:
	return GameSim.new(5, &"gunslinger", {"data": GameData.load_default()})


func _enemy(sim: GameSim, pos: Vector2) -> int:
	var id := sim.spawn_enemy(sim.data.enemy_ids[0], pos)
	sim._phase_rebuild_hash()
	return id


func test_step_moves_projectile_and_ages_life() -> void:
	var sim := _sim()
	sim.projectiles.spawn(Vector2.ZERO, Vector2(600.0, 0.0), 10.0, {"life": 1.0})
	SimProjectiles.step(sim)
	assert_almost_eq(sim.projectiles.pos[0].x, 600.0 * GameSim.STEP, 0.001)
	assert_almost_eq(sim.projectiles.life[0], 1.0 - GameSim.STEP, 0.0001)


func test_step_removes_projectile_when_life_ends() -> void:
	var sim := _sim()
	sim.projectiles.spawn(Vector2.ZERO, Vector2(10.0, 0.0), 10.0, {"life": 0.001})
	SimProjectiles.step(sim)
	assert_eq(sim.projectiles.count, 0)


func test_step_hit_damages_enemy_and_consumes_non_piercing_projectile() -> void:
	var sim := _sim()
	var id := _enemy(sim, Vector2(100.0, 0.0))
	var hp := sim.enemies.hp[EnemyPool.index_of(id)]
	sim.projectiles.spawn(Vector2(100.0, 0.0), Vector2(1.0, 0.0), 7.0, {"life": 1.0})
	SimProjectiles.step(sim)
	assert_eq(sim.projectiles.count, 0, "pierce 0: mermi tükenir")
	assert_lt(sim.enemies.hp[EnemyPool.index_of(id)], hp, "düşman hasar aldı")
	assert_eq(sim.w_collision_tests, 1)


func test_step_game_sim_phase_delegates_to_same_result() -> void:
	var a := _sim()
	var b := _sim()
	for s in [a, b]:
		_enemy(s, Vector2(100.0, 0.0))
		s.projectiles.spawn(Vector2(100.0, 0.0), Vector2(1.0, 0.0), 7.0, {"life": 1.0})
	SimProjectiles.step(a)
	b._phase_projectiles()
	assert_eq(a.projectiles.count, b.projectiles.count)
	assert_eq(a.w_proj_updates, b.w_proj_updates)
	assert_eq(a.state_hash(), b.state_hash())
