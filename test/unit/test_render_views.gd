extends GutTest
## Görünüm (U1-7): tür başına tek MultiMesh, visible_instance_count = canlı sayı, tampon düzeni; rig yardımcıları.


func _sim() -> GameSim:
	return GameSim.new(11, &"gunslinger", {"end_mode": "timer", "end_time": 480.0})


func test_enemy_renderer_counts_alive_and_writes_flash() -> void:
	var sim := _sim()
	var r := EnemyRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	r.refresh()
	assert_eq(r.visible_count(), 0)
	var n := sim.debug_fill(&"curumus_piyade", 25, 400.0)
	assert_gt(n, 0)
	var first := EnemyPool.index_of(sim.alive_ids()[0])
	sim.enemies.flash[first] = 0.75
	r.refresh()
	assert_eq(r.visible_count(), n)
	assert_eq(r.multimesh.instance_count, EnemyPool.CAP)
	var buf := r.multimesh.buffer
	assert_eq(buf.size(), EnemyPool.CAP * EnemyRenderer.STRIDE)
	assert_almost_eq(buf[3], sim.enemies.pos[first].x, 0.01)
	assert_almost_eq(buf[7], sim.enemies.pos[first].y, 0.01)
	assert_almost_eq(buf[12], 0.75, 0.001, "parlama INSTANCE_CUSTOM.r'de")


func test_projectile_renderer_compact_count_and_direction() -> void:
	var sim := _sim()
	var r := ProjectileRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	sim.spawn_projectile(Vector2(10, 20), Vector2(0, 900), 5.0, {})
	sim.spawn_projectile(
		Vector2(0, 0), Vector2(900, 0), 5.0, {"flags": ProjectilePool.FLAG_EXPLODES}
	)
	r.refresh()
	assert_eq(r.visible_count(), sim.projectiles.count)
	var buf := r.multimesh.buffer
	assert_almost_eq(buf[0], 0.0, 1e-4, "aşağı giden mermi: x.x = cos(90°)")
	assert_almost_eq(buf[4], 1.0, 1e-4, "x.y = sin(90°)")
	assert_eq(
		ProjectileRenderer.color_for_flags(ProjectilePool.FLAG_EXPLODES),
		ProjectileRenderer.COLOR_EXPLODES
	)
	assert_eq(ProjectileRenderer.color_for_flags(0), ProjectileRenderer.COLOR_BASIC)


func test_gem_renderer_counts() -> void:
	var sim := _sim()
	var r := GemRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	sim.gems.drop(Vector2(5, 5), 1)
	sim.gems.drop(Vector2(50, 5), 7)
	r.refresh()
	assert_eq(r.visible_count(), sim.gems.count)
	assert_eq(GemRenderer.scale_for_value(1), 1.0)
	assert_gt(GemRenderer.scale_for_value(7), 1.0)
	assert_lte(GemRenderer.scale_for_value(100000), 2.2)


func test_player_view_rig_nodes_and_arm_flip() -> void:
	var sim := _sim()
	var v := PlayerView.new()
	add_child_autofree(v)
	v.bind(sim)
	for n in ["FarArm", "Body", "NearArm", "ReloadRing", "Shadow"]:
		assert_not_null(v.get_node_or_null(n), n)
	assert_lt(v.far_arm.z_index, v.body.z_index)
	assert_gt(v.near_arm.z_index, v.body.z_index)
	sim.gun_aim[0] = PI
	v.update_view(1.0 / 60.0)
	assert_lt(v.near_arm.scale.y, 0.0, "cos(rot) < 0 ise scale.y = -1")
	sim.gun_aim[0] = 0.2
	v.update_view(1.0 / 60.0)
	assert_gt(v.near_arm.scale.y, 0.0)
	var rig := sim.character.rig
	assert_eq(
		PlayerView.shoulder_local(rig, 1, true),
		PlayerRig.shoulder_world(1, Vector2.ZERO, true, rig),
		"omuz PlayerRig ile aynı geometri"
	)


func test_ground_snaps_to_tile() -> void:
	assert_eq(GroundView.snapped_center(Vector2(300, -10), 256.0), Vector2(256, -256))
	var g := GroundView.new()
	add_child_autofree(g)
	g.follow(Vector2(1000, 1000), Vector2(1080, 2400))
	assert_gt(g.region_rect.size.x, 1080.0)
	assert_gt(g.region_rect.size.y, 2400.0)
