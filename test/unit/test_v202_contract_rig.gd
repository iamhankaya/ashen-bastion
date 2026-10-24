extends GutTest
## S1 sözleşmesi: kolsuz rig (PlayerRig, RigFrames, CharacterDef) ve Gunslinger yolunun değişmezliği.

var data: GameData


func before_each() -> void:
	data = GameData.load_default()


func _zyfen_rig() -> Dictionary:
	return data.get_character(&"zyfen").rig


func _gunslinger_rig() -> Dictionary:
	return data.get_character(&"gunslinger").rig


func test_zyfen_character_data() -> void:
	var c := data.get_character(&"zyfen")
	assert_not_null(c)
	assert_true(c.armless)
	assert_eq(c.max_hp, 85.0)
	assert_eq(c.move_speed, 310.0)
	assert_eq(c.mag_cap, 8)
	assert_eq(c.reload_time, 1.3)
	assert_eq(c.attack_range, 750.0)
	assert_eq(c.starting_skill, &"ruzgar_kesigi")
	assert_eq(c.display_upper, "ZYFEN")
	assert_true(c.placeholder)
	assert_false(c.action_while_moving, "karar: varsayılan false, JSON'da açıkça yazılı")
	assert_true(c.rig.has("action_while_moving"))
	assert_eq(c.walk["frames"], 8, "U2: 8 yürüme karesi (kalite kapısı geçti)")
	assert_eq(c.cast["frames"], 6)
	assert_eq(c.cast["fire_frame"], 3)
	assert_eq(c.gather["frames"], 4)
	assert_eq(RigFrames.total_cells(c.rig), 19)
	assert_eq(c.unlock_achievement, &"", "baştan açık")


func test_gunslinger_is_not_armless() -> void:
	var c := data.get_character(&"gunslinger")
	assert_false(c.armless)
	assert_false(PlayerRig.is_armless(c.rig))
	assert_true(c.cast.is_empty() and c.gather.is_empty() and c.walk_cast.is_empty())


func test_cast_point_world_mirrors_x_keeps_y_and_magnitude() -> void:
	var rig := _zyfen_rig()
	var cp := data.get_character(&"zyfen").cast_point
	var p := Vector2(100, 50)
	var r := PlayerRig.cast_point_world(p, false, rig)
	var l := PlayerRig.cast_point_world(p, true, rig)
	var h := float(rig["display_height"])
	assert_almost_eq(r.x - p.x, cp.x * h, 0.001)
	assert_almost_eq(r.y - p.y, cp.y * h, 0.001)
	assert_almost_eq(l.x - p.x, -(r.x - p.x), 0.001, "x işareti tersine")
	assert_almost_eq(l.y, r.y, 0.001, "y aynı")
	assert_almost_eq(absf(l.x - p.x), absf(r.x - p.x), 0.001, "|x| korunur")


func test_shot_origin_armless_follows_target_side() -> void:
	var rig := _zyfen_rig()
	var p := Vector2(10, 10)
	for dx in [-60.0, -1.0, 1.0, 60.0, 500.0]:
		var target := p + Vector2(dx, -30.0)
		var origin := PlayerRig.shot_origin(0, p, target, rig)
		assert_eq(origin, PlayerRig.cast_point_world(p, dx < 0.0, rig), "dx=%s" % dx)
		assert_eq(PlayerRig.shot_origin(1, p, target, rig), origin, "kolsuzda tabanca ayrımı yok")
		assert_eq(
			PlayerRig.facing_left(p, target, target - origin, rig), dx < 0.0, "bakış hedefe göre"
		)


func test_shot_origin_for_armed_rig_is_the_old_formula() -> void:
	var rig := _gunslinger_rig()
	var p := Vector2(5, -7)
	for target in [Vector2(300, 20), Vector2(-250, 90), Vector2(20, -10), Vector2(-15, 4)]:
		for g in 2:
			var aim := PlayerRig.solve_aim(g, p, target, rig)
			var origin := PlayerRig.muzzle_world(g, p, aim, cos(aim) < 0.0, rig)
			var sh := PlayerRig.shoulder_world(g, p, target.x < p.x, rig)
			if target.distance_to(sh) < origin.distance_to(sh) * 1.3:
				origin = sh
			assert_eq(PlayerRig.shot_origin(g, p, target, rig), origin, "%s g%d" % [target, g])
	var dir := Vector2(1, 0.2)
	assert_eq(PlayerRig.facing_left(p, Vector2(-5, 0), dir, rig), false, "kollu: mermi yönü")
	assert_eq(PlayerRig.facing_left(p, Vector2(50, 0), Vector2(-1, 0), rig), true)


func test_solve_aim_armless_points_from_cast_point_to_target() -> void:
	var rig := _zyfen_rig()
	var p := Vector2.ZERO
	var target := Vector2(400, -100)
	var aim := PlayerRig.solve_aim(0, p, target, rig)
	var from := PlayerRig.cast_point_world(p, false, rig)
	assert_almost_eq(aim, (target - from).angle(), 0.0001)


func test_sim_shot_leaves_the_cast_point() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "character": &"zyfen", "pickups": false})
	var id := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(300, 0))
	sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
	SimKit.run(sim, 20)
	var shots := SimKit.events(sim, SimEvents.SHOT)
	assert_gt(shots.size(), 0, "Zyfen temel silahla ateş eder")
	var first: Dictionary = shots[0]
	assert_eq(first["origin"], PlayerRig.cast_point_world(sim.player_pos, false, _zyfen_rig()))


func test_rig_frames_cell_layout() -> void:
	var rig := {"walk": {"frames": 8}, "cast": {"frames": 6}, "gather": {"frames": 4}}
	assert_eq(RigFrames.total_cells(rig), 19)
	assert_eq(RigFrames.idle_index(rig), 8)
	assert_eq(RigFrames.cast_base(rig), 9)
	assert_eq(RigFrames.gather_base(rig), 15)
	assert_eq(RigFrames.walk_cast_base(rig), -1, "walk_cast yok")
	rig["walk_cast"] = {"frames": 5}
	assert_eq(RigFrames.total_cells(rig), 24, "walk_cast terimi")
	assert_eq(RigFrames.walk_cast_base(rig), 19)


func test_rig_frames_without_clips() -> void:
	assert_eq(RigFrames.total_cells({}), 1)
	assert_eq(RigFrames.idle_index({}), 0)
	assert_eq(RigFrames.cast_base({"walk": {"frames": 0}}), -1)
	assert_eq(RigFrames.gather_base({}), -1)
	var procedural := {"walk": {"frames": 0}, "cast": {"frames": 6}, "gather": {"frames": 4}}
	assert_eq(RigFrames.total_cells(procedural), 11, "walk.frames 0: duruş + cast + gather")
	assert_eq(RigFrames.cast_base(procedural), 1)
	assert_eq(RigFrames.gather_base(procedural), 7)
