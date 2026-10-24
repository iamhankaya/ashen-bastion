extends GutTest
## U2: Rüzgar Kesiği (Zyfen temel saldırısı) ve hilal çizim kuralları.


func _sim(character: StringName = &"zyfen") -> GameSim:
	return SimKit.make(1, {"data_kind": "quiet", "character": character, "pickups": false})


func test_shot_is_a_wide_piercing_crescent() -> void:
	var sim := _sim()
	var id := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(300, 0))
	sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
	SimKit.run_until(sim, func() -> bool: return sim.projectiles.count > 0, 30)
	var pr := sim.projectiles
	assert_gt(pr.count, 0, "Zyfen ateş eder")
	assert_eq(pr.pierce[0], ProjectilePool.PIERCE_ALL)
	assert_true(pr.flags[0] & ProjectilePool.FLAG_WIND != 0, "hilal bayrağı")
	assert_eq(pr.rad[0], WindUtil.CRESCENT_RADIUS)
	assert_eq(pr.dmg[0], 12.0, "seviye 1 hasarı JSON'dan")


func test_gunslinger_shot_is_untouched() -> void:
	var sim := _sim(&"gunslinger")
	var id := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(300, 0))
	sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
	SimKit.run_until(sim, func() -> bool: return sim.projectiles.count > 0, 30)
	assert_gt(sim.projectiles.count, 0)
	assert_eq(sim.projectiles.flags[0] & ProjectilePool.FLAG_WIND, 0)
	assert_eq(sim.projectiles.rad[0], ProjectilePool.DEFAULT_RADIUS)


func test_modify_shot_only_raises() -> void:
	var b := preload("res://scripts/sim/skills/ruzgar_kesigi.gd").new()
	var ctx := ShotContext.new()
	ctx.radius = 30.0
	ctx.flags = ProjectilePool.FLAG_SPLIT
	b.modify_shot(ctx)
	assert_eq(ctx.radius, 30.0, "daha geniş yarıçap kısılmaz")
	assert_eq(
		ctx.flags, ProjectilePool.FLAG_SPLIT | ProjectilePool.FLAG_WIND, "mevcut bayrak korunur"
	)
	assert_eq(ctx.pierce, ProjectilePool.PIERCE_ALL)


func test_one_cut_hits_each_enemy_in_line_exactly_once() -> void:
	var sim := _sim()
	sim.gun_interval = 1000.0  # tek kesik: sonraki atış çok sonra
	# kesik avuç noktasından +x yönünde uçar: düşmanlar o yükseklikte dizilir (cast_point JSON'dan)
	var cp := PlayerRig.cast_point_world(sim.player_pos, false, sim.character.rig)
	var ids: Array[int] = []
	for k in 15:
		var id := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(cp.x + 60.0 + 40.0 * k, cp.y))
		sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
		ids.append(id)
	SimKit.run(sim, 60)
	assert_eq(SimKit.count_events(sim, SimEvents.SHOT), 1)
	for id in ids:
		assert_eq(SimKit.enemy_hp(sim, id), 30.0 - 12.0, "düşman %d tam 1 kez vuruldu" % id)


func test_zyfen_run_is_deterministic_with_the_crescent() -> void:
	var a := _sim()
	var b := _sim()
	for k in 5:
		SimKit.add_enemy(a, &"curumus_piyade", Vector2.from_angle(float(k)) * 220.0)
		SimKit.add_enemy(b, &"curumus_piyade", Vector2.from_angle(float(k)) * 220.0)
	SimKit.run(a, 600, Vector2.RIGHT)
	SimKit.run(b, 600, Vector2.RIGHT)
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.check_invariants().size(), 0)


func test_crescent_render_color_and_scale_follow_the_flag_and_radius() -> void:
	var wind := ProjectilePool.FLAG_WIND
	assert_eq(ProjectileRenderer.color_for_flags(wind), ProjectileRenderer.COLOR_WIND)
	assert_eq(ProjectileRenderer.scale_for(wind, 14.0), 14.0 / ProjectilePool.DEFAULT_RADIUS)
	assert_gt(ProjectileRenderer.scale_for(wind, 20.0), ProjectileRenderer.scale_for(wind, 14.0))
	assert_eq(ProjectileRenderer.scale_for(0, 8.0), 1.0)
	assert_eq(ProjectileRenderer.scale_for(ProjectilePool.FLAG_EXPLODES, 8.0), 1.4)
	assert_eq(
		ProjectileRenderer.color_for_flags(0),
		ProjectileRenderer.COLOR_BASIC,
		"bayraksız mermi aynı"
	)


func test_no_shell_signal_connected_target_for_armless() -> void:
	# kovan korumasının dayandığı kural: kolsuz rig ve kollu rig ayrımı
	var z := _sim()
	var g := _sim(&"gunslinger")
	assert_true(PlayerRig.is_armless(z.character.rig))
	assert_false(PlayerRig.is_armless(g.character.rig))
