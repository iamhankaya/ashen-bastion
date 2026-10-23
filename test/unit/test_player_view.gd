extends GutTest
## PlayerView (D1-1): Rig düğümü (ayak pivotu), görünüm omzu/namlusu, shader uniform'ları, sim olaylarının PlayerAnim'e bağlanması.

const DT := 1.0 / 60.0


func _sim() -> GameSim:
	return GameSim.new(11, &"gunslinger", {"end_mode": "timer", "end_time": 480.0})


func _view(sim: GameSim) -> PlayerView:
	var v := PlayerView.new()
	add_child_autofree(v)
	v.bind(sim)
	return v


func _shader_param(v: PlayerView, name: String) -> Variant:
	return (v.body.material as ShaderMaterial).get_shader_parameter(name)


func test_rig_structure_and_foot_pivot() -> void:
	var sim := _sim()
	var v := _view(sim)
	var rig := v.get_node_or_null("Rig") as Node2D
	assert_not_null(rig)
	for n in ["FarArm", "Body", "NearArm"]:
		assert_not_null(rig.get_node_or_null(n), "Rig altında " + n)
	for n in ["Glow", "Shadow", "ReloadRing", "MuzzleFlash"]:
		assert_not_null(v.get_node_or_null(n), "Rig dışında " + n)
	var h := float(sim.character.rig["display_height"])
	v.update_view(DT)
	assert_almost_eq(rig.position.y, h * 0.5, 0.5, "pivot = ayak = gövde merkezi + H/2")
	assert_almost_eq(rig.position.x, 0.0, 0.01)


func test_standing_shoulders_match_sim_within_a_pixel() -> void:
	var sim := _sim()
	var v := _view(sim)
	for g in 2:
		for facing in [false, true]:
			sim.player_facing_left = facing
			for i in 3:
				v.update_view(DT)
			var want := PlayerRig.shoulder_world(g, sim.player_pos, facing, sim.character.rig)
			assert_lt(v.shoulder_view(g).distance_to(want), 1.5, "g=%d sol=%s" % [g, facing])


func test_shoulder_deviation_follows_lean_geometry() -> void:
	var sim := _sim()
	var v := _view(sim)
	for i in 40:
		sim.player_pos += Vector2(5.0, 0.0)  # 300 px/sn
		v.update_view(DT)
	var lean := v.anim.lean
	assert_gt(rad_to_deg(lean), 5.5)
	var h := float(sim.character.rig["display_height"])
	var want := PlayerRig.shoulder_world(0, sim.player_pos, false, sim.character.rig)
	var dev := v.shoulder_view(0).distance_to(want)
	# omuz ayaktan (1-0,2)·H yukarıda: sapma ~ sin(eğim) · 0,8H + bob/sallanma payı (plan: ±16 px bob/itme payı)
	assert_lte(dev, sin(lean) * 0.8 * h + PlayerAnim.BOB_PX + 3.0)


func test_muzzle_view_matches_sim_muzzle_when_standing() -> void:
	var sim := _sim()
	var v := _view(sim)
	sim.gun_aim[0] = -0.3
	sim.gun_aim[1] = 0.4
	for i in 3:
		v.update_view(DT)
	for g in 2:
		var aim := float(sim.gun_aim[g])
		var want := PlayerRig.muzzle_world(
			g, sim.player_pos, aim, cos(aim) < 0.0, sim.character.rig
		)
		assert_lt(v.muzzle_view(g).distance_to(want), 2.0, "namlu g=%d" % g)


func test_shot_starts_recoil_and_muzzle_flash_from_the_view_muzzle() -> void:
	var sim := _sim()
	var v := _view(sim)
	v.update_view(DT)
	sim.bus.shot_fired.emit(0, Vector2.ZERO, Vector2.RIGHT)
	assert_gt(v.muzzle_flash.left[0], 0.0)
	assert_almost_eq(v.muzzle_flash.left[0], Motion.sec(Motion.MUZZLE_FLASH), 1e-4)
	assert_lt(
		(v.position + v.muzzle_flash.points[0]).distance_to(v.muzzle_view(0)),
		3.0,
		"alev görünüm namlusunda"
	)
	var before := v.anim.arm_back[0]
	v.update_view(DT)
	v.update_view(DT)
	assert_gt(v.anim.arm_back[0], before + 5.0)
	assert_eq(v.anim.arm_back[1], 0.0, "ikinci tabanca bağımsız")
	for i in 10:
		v.update_view(DT)
	assert_eq(v.muzzle_flash.left[0], 0.0, "80 ms sonra söner")


func test_damage_event_flashes_and_shader_gets_uniforms() -> void:
	var sim := _sim()
	var v := _view(sim)
	v.update_view(DT)
	sim.bus.player_damaged.emit(10.0, 90.0)
	v.update_view(DT)
	assert_eq(_shader_param(v, "hit"), 1.0)
	assert_gt(float(_shader_param(v, "tint_amt")), 0.2)
	for i in 30:
		v.update_view(DT)
	assert_eq(_shader_param(v, "hit"), 0.0)
	assert_not_null(_shader_param(v, "scarf_amp"))
	assert_not_null(_shader_param(v, "walk_phase"))
	assert_not_null(_shader_param(v, "desat"))
	assert_eq(float(_shader_param(v, "cells")), 1.0, "kare yok: tek hücre")


func test_damage_direction_uses_the_nearest_enemy() -> void:
	var sim := _sim()
	var v := _view(sim)
	sim.debug_fill(&"curumus_piyade", 6, 300.0)
	var near := Vector2(200.0, 0.0) + sim.player_pos
	var idx := EnemyPool.index_of(sim.alive_ids()[0])
	for id in sim.alive_ids():
		sim.enemies.pos[EnemyPool.index_of(id)] = sim.player_pos + Vector2(0.0, 900.0)
	sim.enemies.pos[idx] = near
	sim.bus.player_damaged.emit(5.0, 95.0)
	assert_eq(v.anim.knock_dir.x < 0.0, true, "saldırgan sağda: itme sola")


func test_dt_zero_keeps_the_pose_still() -> void:
	var sim := _sim()
	var v := _view(sim)
	sim.bus.player_damaged.emit(10.0, 90.0)
	v.update_view(DT)
	var k := v.anim.knock_px
	v.update_view(0.0)
	v.update_view(0.0)
	assert_eq(v.anim.knock_px, k, "duraklatmada (view_dt 0) animasyon donuk")


func test_level_up_event_starts_the_ring() -> void:
	var sim := _sim()
	var v := _view(sim)
	sim.bus.level_up.emit(2)
	v.update_view(DT)
	assert_gte(v.anim.level_ring, 0.0)


func test_lost_run_plays_death_and_won_run_does_not() -> void:
	var sim := _sim()
	var v := _view(sim)
	sim.bus.run_ended.emit(false, {})
	assert_eq(v.anim.mode, PlayerAnim.Mode.DEAD)
	for i in 80:
		v.update_view(DT)
	assert_true(v.anim.death_done())
	assert_lt(v.rig_node.modulate.a, 0.05)
	var sim2 := _sim()
	var w := _view(sim2)
	sim2.bus.run_ended.emit(true, {})
	assert_ne(w.anim.mode, PlayerAnim.Mode.DEAD)
	v.bind(sim)
	assert_eq(v.anim.mode, PlayerAnim.Mode.IDLE, "yeniden bağlanınca sıfırlanır")
	assert_eq(v.rig_node.modulate.a, 1.0)


func test_death_tilts_the_rig_around_the_feet() -> void:
	var sim := _sim()
	var v := _view(sim)
	sim.bus.run_ended.emit(false, {})
	for i in 50:
		v.update_view(DT)
	assert_gt(absf(v.rig_node.rotation), deg_to_rad(60.0))
	var h := float(sim.character.rig["display_height"])
	assert_almost_eq(v.rig_node.position.y, h * 0.5 + v.anim.sink_px, 0.5, "ayak pivotu yerinde")


func test_aura_mask_follows_buff_timers_without_calling_stubs() -> void:
	var sim := _sim()
	var v := _view(sim)
	sim.buffs.left_steps[BuffManager.Kind.FIRE_RATE] = 100
	v.update_view(DT)
	assert_eq(v.anim.aura_mask, 2)
	sim.buffs.left_steps[BuffManager.Kind.FIRE_RATE] = 0
	sim.buffs.left_steps[BuffManager.Kind.UNLIMITED] = 5
	sim.buffs.left_steps[BuffManager.Kind.DAMAGE] = 5
	v.update_view(DT)
	assert_eq(v.anim.aura_mask, 5)


func test_reload_ring_follows_magazine_and_pulses_after_finish() -> void:
	var sim := _sim()
	var v := _view(sim)
	sim.magazine.start_reload(sim.stats)
	v.update_view(DT)
	assert_true(v.reload_ring.visible)
	sim.bus.reload_finished.emit()
	sim.magazine.reloading = false
	v.update_view(DT)
	assert_true(v.reload_ring.visible, "tamamlanınca 150 ms nabız")
	for i in 12:
		v.update_view(DT)
	assert_false(v.reload_ring.visible)


func test_frame_mode_without_a_strip_falls_back_to_procedural() -> void:
	var sim := _sim()
	sim.character.rig["walk"]["frames"] = 6
	var v := _view(sim)
	for i in 30:
		sim.player_pos += Vector2(5.0, 0.0)
		v.update_view(DT)
	assert_gt(v.anim.bob_px + v.anim.walk_phase, 0.0)
	assert_eq(float(_shader_param(v, "cells")), 1.0)
	assert_eq(v.anim.frame_a, 0, "şerit yok: kare indeksi yedek (0)")
