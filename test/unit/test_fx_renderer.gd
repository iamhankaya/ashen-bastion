extends GutTest
## FxRenderer: sabit tamponlar, süre dolunca söner, sinyallere bağlanır; Atmosphere shader parametresi.


func _sim() -> GameSim:
	return GameSim.new(21, &"gunslinger", {"end_mode": "lord"})


func test_effects_expire_and_never_exceed_buffers() -> void:
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	for i in FxRenderer.MAX_EXPLOSIONS * 3:
		fx.add_explosion(Vector2(i, 0), 100.0)
	fx.update_fx(0.016)
	assert_eq(fx.active_count(), FxRenderer.MAX_EXPLOSIONS, "halka tampon taşmaz")
	fx.update_fx(FxRenderer.EXPLOSION_TIME + 0.1)
	fx.update_fx(0.016)
	assert_eq(fx.active_count(), 0, "süre dolunca söner")


func test_bound_sim_signals_create_effects() -> void:
	var sim := _sim()
	var cam := CameraRig.new()
	add_child_autofree(cam)
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	fx.bind(sim, cam)
	sim.bus.explosion.emit(Vector2(10, 10), 200.0)
	sim.bus.enemy_killed.emit(&"curumus_piyade", Vector2(5, 5))
	sim.bus.gem_collected.emit(1)
	sim.fx.beam_fired.emit(Vector2.ZERO, Vector2(100, 0))
	fx.update_fx(0.016)
	assert_eq(fx.active_count(), 4)
	fx.bind(null)
	fx.update_fx(0.016)
	assert_eq(fx.active_count(), 0, "bağ kopunca efektler temizlenir")


func test_atmosphere_follows_camera() -> void:
	var a := Atmosphere.new()
	add_child_autofree(a)
	a.follow(Vector2(100, 200), Vector2(1080, 2400))
	assert_true(a.material is ShaderMaterial)
	assert_eq((a.material as ShaderMaterial).get_shader_parameter("cam_pos"), Vector2(100, 200))
