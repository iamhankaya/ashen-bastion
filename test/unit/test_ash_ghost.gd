extends GutTest
## AshGhostRenderer (D1-3): enemy_killed → hayalet, halka tampon 64, ömürler, LOD, tampon düzeni, sim'e dokunmaz.


func _sim() -> GameSim:
	return GameSim.new(11, &"gunslinger", {"end_mode": "lord"})


func _setup(sim: GameSim) -> Array:
	var er := EnemyRenderer.new()
	add_child_autofree(er)
	er.bind(sim)
	var g := AshGhostRenderer.new()
	add_child_autofree(g)
	g.bind(sim, er)
	return [g, er]


func test_kill_event_adds_one_ghost_and_it_expires_after_its_life() -> void:
	var sim := _sim()
	var g: AshGhostRenderer = _setup(sim)[0]
	assert_eq(g.ghost_count(), 0)
	sim.bus.enemy_killed.emit(&"curumus_piyade", Vector2(100, 50))
	assert_eq(g.ghost_count(), 1)
	g.update_ghosts(0.0)
	assert_eq(g.multimesh.visible_instance_count, 1)
	g.update_ghosts(0.2)
	assert_eq(g.ghost_count(), 1)
	g.update_ghosts(0.25)
	assert_eq(g.ghost_count(), 0, "420 ms sonra söner")
	g.update_ghosts(0.0)
	assert_eq(g.multimesh.visible_instance_count, 0)


func test_lifetimes_follow_the_death_data() -> void:
	var sim := _sim()
	var g: AshGhostRenderer = _setup(sim)[0]
	assert_almost_eq(g.life_of(&"curumus_piyade"), 0.42, 1e-4)
	assert_almost_eq(g.life_of(&"les_kargasi"), 0.42, 1e-4)
	assert_almost_eq(g.life_of(&"sovalye_hayaleti"), 0.70, 1e-4)
	assert_almost_eq(g.life_of(&"elit_piyade"), 0.90, 1e-4)
	assert_almost_eq(g.life_of(&"kale_lordu"), 0.90, 1e-4)


func test_ring_buffer_replaces_the_oldest_on_the_65th() -> void:
	var sim := _sim()
	var g: AshGhostRenderer = _setup(sim)[0]
	for k in 64:
		sim.bus.enemy_killed.emit(&"sovalye_hayaleti", Vector2(k, 0))
	assert_eq(g.ghost_count(), 64)
	g.update_ghosts(0.5)
	sim.bus.enemy_killed.emit(&"sovalye_hayaleti", Vector2(999, 0))
	assert_eq(g.ghost_count(), 64, "taşmaz")
	g.update_ghosts(0.0)
	assert_eq(g.multimesh.visible_instance_count, 64)
	var found := false
	for k in 64:
		if is_equal_approx(g.multimesh.buffer[k * AshGhostRenderer.STRIDE + 3], 999.0):
			found = true
	assert_true(found, "en yeni girdi yazıldı")
	var old := 0
	for k in 64:
		if is_equal_approx(g.multimesh.buffer[k * AshGhostRenderer.STRIDE + 3], 0.0):
			old += 1
	assert_eq(old, 0, "en eski (0. girdi) değişti")


func test_many_alive_enemies_switch_to_150ms_flat_fade() -> void:
	var sim := _sim()
	var g: AshGhostRenderer = _setup(sim)[0]
	sim.debug_fill(&"curumus_piyade", 160, 500.0)
	assert_gt(sim.enemies.count, AshGhostRenderer.LOD_ALIVE)
	sim.bus.enemy_killed.emit(&"sovalye_hayaleti", Vector2(10, 10))
	g.update_ghosts(0.0)
	assert_lt(g.multimesh.buffer[AshGhostRenderer.STRIDE * 0 + 15], 0.0, "LOD işareti: tohum < 0")
	g.update_ghosts(0.14)
	assert_eq(g.ghost_count(), 1)
	g.update_ghosts(0.02)
	assert_eq(g.ghost_count(), 0, "150 ms")


func test_buffer_layout_age_cell_and_mirror() -> void:
	var sim := _sim()
	var parts := _setup(sim)
	var g: AshGhostRenderer = parts[0]
	var er: EnemyRenderer = parts[1]
	sim.player_pos = Vector2.ZERO
	sim.bus.enemy_killed.emit(&"curumus_piyade", Vector2(300, 0))  # oyuncunun sağında: sola bakar
	g.update_ghosts(0.21)
	var b := g.multimesh.buffer
	assert_lt(b[0], 0.0, "oyuncuya bakar (ayna)")
	assert_almost_eq(b[12], 0.5, 0.01, "yaş = 210/420")
	var t := sim.data.enemy_ids.find(&"curumus_piyade")
	assert_eq(int(round(b[13])), er.cell_of(t))
	assert_between(b[15], 0.0, 1.0, "tohum")
	assert_almost_eq(b[11], 0.52, 0.01, "çözülme başlangıcı çöküş bitişinde")
	# çöküş: sy 0,55'e yaklaşır
	var q := er.quad_size(t)
	var sy_len := Vector2(b[1], b[5]).length() / q.y
	assert_lt(sy_len, 1.0)
	assert_gt(sy_len, 0.5)


func test_fall_death_drops_and_rotates() -> void:
	var sim := _sim()
	var parts := _setup(sim)
	var g: AshGhostRenderer = parts[0]
	var er: EnemyRenderer = parts[1]
	sim.player_pos = Vector2.ZERO
	sim.bus.enemy_killed.emit(&"les_kargasi", Vector2(-300, 0))
	g.update_ghosts(0.0)
	var y0 := g.multimesh.buffer[7]
	g.update_ghosts(0.3)
	var b := g.multimesh.buffer
	assert_gt(b[7], y0 + 10.0, "düşer")
	assert_gt(absf(b[4]), 0.1, "döner")
	var t := sim.data.enemy_ids.find(&"les_kargasi")
	assert_gt(er.quad_size(t).x, 0.0)


func test_rise_death_goes_up() -> void:
	var sim := _sim()
	var g: AshGhostRenderer = _setup(sim)[0]
	sim.bus.enemy_killed.emit(&"sovalye_hayaleti", Vector2(0, 500))
	g.update_ghosts(0.0)
	var y0 := g.multimesh.buffer[7]
	g.update_ghosts(0.5)
	assert_lt(g.multimesh.buffer[7], y0 - 5.0, "kül yukarı akar")


func test_paused_view_time_freezes_ghosts_and_rebind_clears() -> void:
	var sim := _sim()
	var g: AshGhostRenderer = _setup(sim)[0]
	sim.bus.enemy_killed.emit(&"curumus_piyade", Vector2.ZERO)
	g.update_ghosts(0.1)
	var age := g.multimesh.buffer[12]
	for k in 20:
		g.update_ghosts(0.0)
	assert_eq(g.multimesh.buffer[12], age, "view_dt 0: donuk")
	g.bind(null, null)
	assert_eq(g.ghost_count(), 0)
	g.update_ghosts(0.1)
	assert_eq(g.multimesh.visible_instance_count, 0)


func test_unknown_type_and_unbound_are_safe_and_sim_untouched() -> void:
	var sim := _sim()
	var g: AshGhostRenderer = _setup(sim)[0]
	sim.bus.enemy_killed.emit(&"yok_boyle_tur", Vector2.ZERO)
	assert_eq(g.ghost_count(), 0)
	sim.bus.enemy_killed.emit(&"curumus_piyade", Vector2.ZERO)
	var h := sim.state_hash()
	g.update_ghosts(0.2)
	assert_eq(sim.state_hash(), h)
	var lone := AshGhostRenderer.new()
	add_child_autofree(lone)
	lone.update_ghosts(0.1)
	assert_eq(lone.ghost_count(), 0)
