extends GutTest
## FxRenderer v1.1 (D1-3): genel halka (12), kovan (16), parçacık (96), zemin kömürü (8); süre dolunca söner, taşmaz.


func _fx() -> FxRenderer:
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	return fx


func test_rings_cap_at_12_and_expire() -> void:
	var fx := _fx()
	for i in 30:
		fx.add_ring(Vector2(i, 0), 100.0, 0.45, Color.WHITE, 4.0)
	assert_eq(fx.ring_count(), FxRenderer.MAX_RINGS)
	fx.update_fx(0.2)
	assert_eq(fx.ring_count(), 12)
	assert_gt(fx.active_count(), 0)
	fx.update_fx(0.3)
	assert_eq(fx.ring_count(), 0)
	fx.update_fx(0.016)
	assert_eq(fx.active_count(), 0)


func test_ring_duration_is_clamped_positive() -> void:
	var fx := _fx()
	fx.add_ring(Vector2.ZERO, 50.0, 0.0, Color.WHITE, 3.0)
	assert_eq(fx.ring_count(), 1)
	fx.update_fx(0.05)
	assert_eq(fx.ring_count(), 0)


func test_shells_cap_at_16_and_last_350ms() -> void:
	var fx := _fx()
	for i in 40:
		fx.add_shell(Vector2(i, 0), Vector2.LEFT)
	assert_eq(fx.shell_count(), FxRenderer.MAX_SHELLS)
	fx.update_fx(0.30)
	assert_eq(fx.shell_count(), 16)
	fx.update_fx(0.06)
	assert_eq(fx.shell_count(), 0)


func test_shell_with_zero_dir_still_flies() -> void:
	var fx := _fx()
	fx.add_shell(Vector2.ZERO, Vector2.ZERO)
	assert_eq(fx.shell_count(), 1)


func test_particles_cap_at_96_kinds_and_unknown_ignored() -> void:
	var fx := _fx()
	for k in 150:
		fx.add_particle(&"dust", Vector2(k, 0), Vector2(0, -20), 0.5)
	assert_eq(fx.particle_count(), FxRenderer.MAX_PARTICLES)
	var fx2 := _fx()
	fx2.add_particle(&"plus", Vector2.ZERO, Vector2.UP, 0.5)
	fx2.add_particle(&"ember", Vector2.ZERO, Vector2.UP, 0.5)
	fx2.add_particle(&"dust", Vector2.ZERO, Vector2.UP, 0.5)
	fx2.add_particle(&"bilinmeyen", Vector2.ZERO, Vector2.UP, 0.5)
	assert_eq(fx2.particle_count(), 3)
	fx2.update_fx(0.6)
	assert_eq(fx2.particle_count(), 0)


func test_particles_move_and_embers_rise() -> void:
	var fx := _fx()
	fx.add_particle(&"ember", Vector2.ZERO, Vector2(10, 0), 1.0)
	fx.update_fx(0.1)
	assert_gt(fx._part_pos[0].x, 0.0)
	assert_lt(fx._part_pos[0].y, 0.0, "kor yükselir")


func test_char_caps_at_8_fades_in_4_seconds() -> void:
	var fx := _fx()
	for i in 20:
		fx.add_char(Vector2(i, 0), 320.0)
	assert_eq(fx.char_count(), FxRenderer.MAX_CHARS)
	fx.update_fx(3.9)
	assert_eq(fx.char_count(), 8)
	fx.update_fx(0.2)
	assert_eq(fx.char_count(), 0)
	assert_true(fx.char_layer.get_parent() == fx, "denetleyici katmanı taşıyana dek çocuktur")
	assert_null(fx.char_layer.material, "kömür normal karışımla çizilir")


func test_bomb_exploded_leaves_char_and_shock_ring() -> void:
	var sim := GameSim.new(21, &"gunslinger", {"end_mode": "lord"})
	var fx := _fx()
	fx.bind(sim, null)
	sim.bus.bomb_exploded.emit(Vector2(10, 10), 320.0)
	assert_eq(fx.char_count(), 1)
	assert_eq(fx.ring_count(), 1)
	fx.bind(null)
	assert_eq(fx.char_count(), 0, "yeniden bağlanınca temizlenir")
	assert_eq(fx.ring_count(), 0)


func test_elite_kill_adds_two_extra_puffs_but_normal_kill_one() -> void:
	var sim := GameSim.new(21, &"gunslinger", {"end_mode": "lord"})
	var fx := _fx()
	fx.bind(sim, null)
	sim.bus.enemy_killed.emit(&"curumus_piyade", Vector2.ZERO)
	fx.update_fx(0.0)
	assert_eq(fx.active_count(), 1)
	sim.bus.enemy_killed.emit(&"elit_piyade", Vector2.ZERO)
	fx.update_fx(0.0)
	assert_eq(fx.active_count(), 4)


func test_rebind_disconnects_old_sim_signals() -> void:
	var a := GameSim.new(21, &"gunslinger", {"end_mode": "lord"})
	var b := GameSim.new(22, &"gunslinger", {"end_mode": "lord"})
	var fx := _fx()
	fx.bind(a, null)
	fx.bind(b, null)
	a.bus.bomb_exploded.emit(Vector2.ZERO, 100.0)
	assert_eq(fx.char_count(), 0, "eski sim'in olayı artık etkisiz")
	b.bus.bomb_exploded.emit(Vector2.ZERO, 100.0)
	assert_eq(fx.char_count(), 1)
