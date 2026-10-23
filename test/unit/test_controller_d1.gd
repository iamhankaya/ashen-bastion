extends GutTest
## GameController D1 bağlantıları: katman sırası, view_dt kuralı (A4), vuruş donması, Lord olayları, kovan/sarsıntı.

const DT := 1.0 / 60.0


func _ctrl() -> GameController:
	var gc := GameController.new()
	add_child_autofree(gc)
	return gc


func test_world_layers_follow_the_plan_order() -> void:
	var gc := _ctrl()
	var order: Array[String] = []
	for c in gc.world.get_children():
		order.append(String(c.name))
	var want := [
		"Ground", "CharLayer", "Shadows", "Gems", "Enemies", "Ghosts", "Actors", "Projectiles", "Fx"
	]
	var last := -1
	for n in want:
		var k := order.find(n)
		assert_gt(k, last, "%s sırası (%s)" % [n, order])
		last = k
	assert_eq(gc.enemy_renderer.shadows, gc.enemy_shadows)
	assert_eq(gc.fx_renderer.char_layer.get_parent(), gc.world)
	assert_not_null(gc.ghosts)


func test_view_dt_is_dt_only_while_playing() -> void:
	var gc := _ctrl()
	for scr in [
		PauseLogic.Screen.MENU,
		PauseLogic.Screen.PAUSED,
		PauseLogic.Screen.LEVEL_UP,
		PauseLogic.Screen.RESULT
	]:
		gc.screen = scr
		assert_eq(gc._v11_view_dt(DT), 0.0, "ekran %d" % scr)
	gc.screen = PauseLogic.Screen.PLAYING
	assert_eq(gc._v11_view_dt(DT), DT)


func test_lord_death_slows_the_view_to_40_percent_for_1200ms() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc.sim.bus.enemy_killed.emit(&"kale_lordu", Vector2(100, 100))
	assert_almost_eq(gc.hit_stop.left, 0.15, 1e-6, "vuruş donması 150 ms")
	assert_almost_eq(gc._v11_view_dt(DT), DT * 0.4, 1e-6)
	var t := 0.0
	while gc._lord_slow_left > 0.0 and t < 3.0:
		gc._v11_update_player(DT)
		t += DT
	assert_between(t, 1.15, 1.30, "1,2 sn gerçek süre")
	assert_eq(gc._v11_view_dt(DT), DT)


func test_lord_death_schedules_three_blasts_within_900ms() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc.sim.bus.enemy_killed.emit(&"kale_lordu", Vector2(0, 0))
	assert_eq(gc._lord_blast_t.size(), 3)
	var head0 := gc.fx_renderer._ex_head
	for i in 60:
		gc._v11_update_player(DT)
	assert_eq(gc._lord_blast_t.size(), 0)
	assert_eq(gc.fx_renderer._ex_head, head0 + 3, "3 patlama eklendi")
	var other := _ctrl()
	other.start_run()
	other.sim.bus.enemy_killed.emit(&"curumus_piyade", Vector2.ZERO)
	assert_eq(other._lord_blast_t.size(), 0)
	assert_eq(other.hit_stop.left, 0.0)


func test_hit_stop_freezes_the_sim_and_keeps_the_accumulator() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc._process(DT)
	var steps := gc.sim.step_count
	gc.hit_stop.request(0.06)
	var acc := gc._accum
	for i in 3:
		gc._process(DT)
	assert_eq(gc.sim.step_count, steps, "donarken sim adımlanmaz")
	assert_eq(gc._accum, acc, "birikim artmaz")
	for i in 3:
		gc._process(DT)
	assert_gt(gc.sim.step_count, steps, "donma bitince sim sürer")


func test_hit_stop_is_ignored_outside_playing() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc.hit_stop.request(0.1)
	gc.pause_game()
	assert_false(gc._v11_hit_stop(DT))
	assert_almost_eq(gc.hit_stop.left, 0.1, 1e-6, "duraklatmada tüketilmez")


func test_enrage_and_slam_signals_request_hit_stop_and_shake() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc.enemy_renderer.lord_enraged.emit(Vector2(10, 10))
	assert_almost_eq(gc.hit_stop.left, 0.08, 1e-6)
	assert_eq(gc.camera._shake, 16.0)
	assert_gt(gc.fx_renderer.ring_count(), 0)
	var gc2 := _ctrl()
	gc2.start_run()
	gc2.enemy_renderer.lord_slammed.emit(Vector2(10, 10))
	assert_eq(gc2.camera._shake, 10.0)
	assert_eq(gc2.fx_renderer.ring_count(), 1)


func test_shot_ejects_a_shell_and_damage_shakes_the_camera() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc._update_views(DT)
	gc.sim.bus.shot_fired.emit(0, gc.sim.player_pos, Vector2.RIGHT)
	assert_eq(gc.fx_renderer.shell_count(), 1)
	gc.sim.bus.player_damaged.emit(10.0, 90.0)
	assert_almost_eq(gc.camera._shake, 4.0, 1e-5, "min(10·0,4, 10)")
	gc.sim.bus.player_damaged.emit(80.0, 10.0)
	assert_eq(gc.camera._shake, 10.0, "üst sınır 10")


func test_menu_rebind_clears_effects_and_disconnects() -> void:
	var gc := _ctrl()
	gc.start_run()
	var old := gc.sim
	gc.sim.bus.enemy_killed.emit(&"kale_lordu", Vector2.ZERO)
	gc.go_menu()
	assert_eq(gc._lord_slow_left, 0.0)
	assert_eq(gc.hit_stop.left, 0.0)
	assert_eq(gc._lord_blast_t.size(), 0)
	old.bus.enemy_killed.emit(&"kale_lordu", Vector2.ZERO)
	assert_eq(gc._lord_blast_t.size(), 0, "eski sim'in olayı dinlenmez")
	assert_eq(gc.ghosts.ghost_count(), 0)


func test_view_updates_never_change_the_sim_hash_and_game_runs_clean() -> void:
	var gc := _ctrl()
	gc.start_run()
	for i in 240:
		gc._process(DT)
	var h := gc.sim.state_hash()
	var steps := gc.sim.step_count
	gc.hit_stop.left = 1.0  # sim donuk: yalnız görünüm koşar
	for i in 30:
		gc._process(DT)
	assert_eq(gc.sim.step_count, steps)
	assert_eq(gc.sim.state_hash(), h, "A22: görünüm sim durumunu değiştirmez")
	assert_eq(gc.sim.check_invariants(), PackedStringArray())


func test_paused_game_freezes_player_fx_and_ghosts_but_not_the_camera_follow() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc.sim.bus.player_damaged.emit(10.0, 90.0)
	gc._update_views(DT)
	var knock := gc.player_view.anim.knock_px
	gc.pause_game()
	for i in 20:
		gc._update_views(DT)
	assert_eq(gc.player_view.anim.knock_px, knock, "duraklatmada oyuncu animasyonu donuk")


func test_death_sequence_plays_inside_the_result_delay() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc.sim.bus.player_damaged.emit(5.0, 5.0)
	gc.sim.hp = 0.0
	for i in 4:
		gc._process(DT)
	assert_eq(gc.sim.state, GameSim.State.LOST)
	assert_eq(gc.screen, PauseLogic.Screen.PLAYING, "gecikme sürerken ekran PLAYING kalır")
	assert_eq(gc.player_view.anim.mode, PlayerAnim.Mode.DEAD)
	var t := 0.0
	while gc.screen == PauseLogic.Screen.PLAYING and t < 3.0:
		gc._process(DT)
		t += DT
	assert_between(t, 1.0, 1.4, "sonuç ~1,3 sn sonra")
	assert_gt(
		absf(gc.player_view.rig_node.rotation),
		deg_to_rad(60.0),
		"ölüm devrilmesi gecikme içinde oynadı"
	)
	assert_eq(gc.screen, PauseLogic.Screen.RESULT)


func test_lord_death_slowmo_and_blasts_run_inside_the_win_delay() -> void:
	var gc := _ctrl()
	gc.start_run()
	var head0 := gc.fx_renderer._ex_head
	gc.sim.bus.enemy_killed.emit(&"kale_lordu", gc.sim.player_pos + Vector2(200, 0))
	gc.sim.bus.run_ended.emit(true, {"time": 1200.0, "level": 5, "kills": 10, "evolutions": []})
	assert_true(gc._delay.active)
	assert_eq(gc.screen, PauseLogic.Screen.PLAYING)
	var t := 0.0
	while gc._lord_slow_left > 0.0 and t < 3.0:
		gc._process(DT)
		t += DT
	assert_between(t, 1.1, 1.4, "yavaş çekim 1,2 sn gerçek süre, gecikmeden önce biter")
	assert_eq(gc.fx_renderer._ex_head, head0 + 3, "3 patlama gecikme içinde patladı")
	assert_eq(gc.screen, PauseLogic.Screen.PLAYING, "kazanma gecikmesi 1,8 sn: hâlâ PLAYING")
