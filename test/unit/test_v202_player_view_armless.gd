extends GutTest
## U2: PlayerView kolsuz rig (Zyfen): kol düğümleri gizli, 19 hücreli şerit, cast/gather/yürüme kare seçimi, avuç parlaması.

const DT := 1.0 / 60.0

var _rig_ref: Dictionary = {}
var _awm_backup: Variant = null


func before_each() -> void:
	ArtLoader._cache.clear()


func after_each() -> void:
	if _rig_ref.size() > 0:  # GameData önbelleği paylaşımlıdır: işin sonunda geri al
		_rig_ref["action_while_moving"] = _awm_backup
	_rig_ref = {}
	ArtLoader._cache.clear()


func _view(character: StringName = &"zyfen", awm: Variant = null) -> PlayerView:
	var sim := GameSim.new(11, character, {"end_mode": "timer", "end_time": 480.0})
	if awm != null:
		_rig_ref = sim.character.rig
		_awm_backup = _rig_ref.get("action_while_moving", false)
		_rig_ref["action_while_moving"] = awm
	var v := PlayerView.new()
	add_child_autofree(v)
	v.bind(sim)
	return v


func _walk(v: PlayerView, px_per_step: float, steps: int) -> void:
	for i in steps:
		v._sim.player_pos += Vector2(px_per_step, 0.0)
		v._sim.step_count += 1
		v.update_view(DT)


func _stand(v: PlayerView, steps: int) -> void:
	for i in steps:
		v._sim.step_count += 1
		v.update_view(DT)


func test_zyfen_has_hidden_arms_and_a_19_cell_strip() -> void:
	var v := _view()
	assert_true(v._strip_ready, "gerçek şerit yüklendi")
	assert_false(v.near_arm.visible)
	assert_false(v.far_arm.visible)
	assert_false(v.arm_rig.enabled())
	var mat := v.body.material as ShaderMaterial
	assert_eq(mat.get_shader_parameter("cells"), 19.0)


func test_gunslinger_arms_stay_visible() -> void:
	var v := _view(&"gunslinger")
	assert_true(v.near_arm.visible and v.far_arm.visible)
	assert_true(v.arm_rig.enabled())


func test_idle_shows_the_stand_cell() -> void:
	var v := _view()
	_stand(v, 30)
	assert_eq(v.anim.frame_a, 8)
	assert_eq(v.anim.frame_b, 8)


func test_walking_runs_through_the_8_walk_cells() -> void:
	var v := _view()
	var seen := {}
	for i in 120:
		_walk(v, 5.0, 1)
		seen[v.anim.frame_a] = true
	assert_true(v.anim.mode == PlayerAnim.Mode.WALK)
	for f in seen:
		assert_lt(f, 8, "yürürken yalnız yürüme hücreleri")
	assert_gte(seen.size(), 6)


func test_shot_while_idle_plays_the_cast_cell_and_flashes_at_the_palm() -> void:
	var v := _view()
	_stand(v, 20)
	var origin := PlayerRig.cast_point_world(v._sim.player_pos, false, v._rig)
	v._sim.bus.shot_fired.emit(0, origin, Vector2.RIGHT)
	_stand(v, 1)
	assert_eq(v.anim.frame_a, 12, "9 + fire_frame 3")
	assert_eq(v.muzzle_flash.points[0], origin - v.position)
	assert_true(v.muzzle_flash.cool, "kolsuzda soğuk parıltı")
	assert_gt(v.muzzle_flash.left[0], 0.0)
	_stand(v, 30)
	assert_eq(v.anim.frame_a, 8, "klip bitti: duruş")


func test_shot_while_walking_keeps_the_walk_cells_by_default() -> void:
	var v := _view()
	_walk(v, 5.0, 40)
	var origin := PlayerRig.cast_point_world(v._sim.player_pos, false, v._rig)
	v._sim.bus.shot_fired.emit(0, origin, Vector2.RIGHT)
	_walk(v, 5.0, 3)
	assert_lt(v.anim.frame_a, 8, "action_while_moving=false: yürüme sürer")


func test_action_while_moving_true_plays_cast_cells_while_walking() -> void:
	var v := _view(&"zyfen", true)
	_walk(v, 5.0, 40)
	var origin := PlayerRig.cast_point_world(v._sim.player_pos, false, v._rig)
	v._sim.bus.shot_fired.emit(0, origin, Vector2.RIGHT)
	_walk(v, 5.0, 1)
	assert_between(v.anim.frame_a, 9, 14, "cast hücreleri")
	var phase := v.anim.walk_phase
	_walk(v, 5.0, 3)
	assert_eq(v.anim.walk_phase, phase, "yürüme saati klip boyunca donar")


func test_reload_plays_the_gather_cells_when_idle() -> void:
	var v := _view()
	_stand(v, 10)
	var seen := {}
	v._sim.magazine.reloading = true
	v._sim.magazine.reload_total = 1.3
	v._sim.magazine.reload_left = 1.3
	for i in 80:
		v._sim.magazine.reload_left = maxf(0.0, 1.3 - float(i) * DT)
		_stand(v, 1)
		seen[v.anim.frame_a] = true
	assert_true(seen.has(15) and seen.has(18), "gather hücreleri: %s" % [seen.keys()])
	v._sim.magazine.reloading = false
	_stand(v, 2)
	assert_eq(v.anim.frame_a, 8)


func test_shoulder_and_muzzle_view_are_the_cast_point_for_armless() -> void:
	var v := _view()
	_stand(v, 5)
	var cp := v.position + PlayerRig.cast_point_world(Vector2.ZERO, false, v._rig)
	assert_almost_eq(v.muzzle_view(0).x, cp.x, 6.0)
	assert_almost_eq(v.shoulder_view(0).y, cp.y, 6.0)


func test_reload_while_walking_keeps_the_walk_cells_by_default() -> void:
	var v := _view()
	_walk(v, 5.0, 40)
	v._sim.magazine.reloading = true
	v._sim.magazine.reload_total = 1.3
	v._sim.magazine.reload_left = 1.3
	for i in 30:
		_walk(v, 5.0, 1)
		assert_lt(v.anim.frame_a, 8, "yürürken toplama karesi yok (kare %d)" % i)
	v._sim.magazine.reloading = false
	v._sim.magazine.reload_left = 0.0
