extends GutTest
## MapSim: deterministik chunk üretimi, başlangıç boş, engelden itme, harabe verisi doğrulaması.


func _defs() -> Array:
	return GameData.load_default().ruins


func test_ruins_data_is_valid_and_has_solid_and_decor() -> void:
	var data := GameData.load_default()
	assert_eq(data.validate(), PackedStringArray())
	var solid := 0
	var decor := 0
	for r in data.ruins:
		if r["solid"]:
			solid += 1
		else:
			decor += 1
	assert_gt(solid, 3)
	assert_gt(decor, 5)


func test_same_seed_same_map_and_different_seed_differs() -> void:
	var a := MapSim.new(77, _defs())
	var b := MapSim.new(77, _defs())
	var c := MapSim.new(78, _defs())
	for m in [a, b, c]:
		m.ensure(Vector2(5000, -3000))
	assert_eq(a.ob_pos, b.ob_pos)
	assert_ne(a.ob_pos, c.ob_pos)
	assert_gt(a.count, 20)


func test_generation_is_independent_of_visit_order() -> void:
	var a := MapSim.new(5, _defs())
	a.ensure(Vector2.ZERO)
	a.ensure(Vector2(4096, 0))
	var b := MapSim.new(5, _defs())
	b.ensure(Vector2(4096, 0))
	b.ensure(Vector2.ZERO)
	var pa := {}
	for i in a.count:
		pa[a.ob_pos[i]] = true
	for i in b.count:
		assert_true(pa.has(b.ob_pos[i]), "aynı chunk aynı engelleri üretir")


func test_start_area_is_clear() -> void:
	for s in 6:
		var m := MapSim.new(s, _defs())
		m.ensure(Vector2.ZERO)
		for i in m.count:
			assert_gt(
				m.ob_pos[i].length(), MapSim.START_CLEAR, "başlangıç çevresi boş (tohum %d)" % s
			)


func test_resolve_pushes_circle_out_of_solid_obstacle() -> void:
	var m := MapSim.new(3, _defs())
	m.ensure(Vector2(3000, 3000))
	var found := -1
	for i in m.count:
		if m.ob_solid[i] == 1:
			found = i
			break
	assert_ne(found, -1)
	var center := m.ob_pos[found]
	var r := m.ob_r[found]
	var out := m.resolve(center + Vector2(10, 0), 22.0)
	assert_almost_eq(out.distance_to(center), r + 22.0, 0.5)
	var far := center + Vector2(r + 500.0, 0)
	assert_eq(m.resolve(far, 22.0), far, "engelden uzak konum değişmez")


func test_obstacles_near_returns_only_solid_circles() -> void:
	var m := MapSim.new(9, _defs())
	var obs := m.obstacles_near(Vector2(2000, 2000))
	assert_gt(obs.size(), 0)
	for o in obs:
		assert_gt(o.z, 0.0)


func test_no_ruin_data_means_empty_map() -> void:
	var m := MapSim.new(1, [])
	m.ensure(Vector2(100, 100))
	assert_eq(m.count, 0)
	assert_eq(m.resolve(Vector2(5, 5), 20.0), Vector2(5, 5))


func test_player_cannot_walk_through_a_solid_ruin_in_the_sim() -> void:
	var sim := GameSim.new(31, &"gunslinger", {"log_events": false})
	sim.max_hp = 1.0e9
	sim.hp = 1.0e9
	var target := Vector2.ZERO
	var obs := sim.map.obstacles_near(Vector2(1500, 0))
	for o in obs:
		if o.x > 700.0:
			target = Vector2(o.x, o.y)
			break
	assert_ne(target, Vector2.ZERO)
	var worst := 1.0e9
	for i in 3000:
		var to := target - sim.player_pos
		if to.length() < 5.0:
			break
		sim.step(to.normalized())
		for o in sim.map.obstacles_near(sim.player_pos):
			worst = minf(worst, sim.player_pos.distance_to(Vector2(o.x, o.y)) - o.z)
	assert_gte(worst, sim.character.collision_radius - 0.5, "oyuncu engelin içine giremez")


func test_ruin_view_creates_and_frees_sprites_with_chunks() -> void:
	var actors := Node2D.new()
	add_child_autofree(actors)
	var m := MapSim.new(4, _defs())
	var rv := RuinView.new()
	rv.bind(actors, m)
	rv.follow(Vector2.ZERO)
	var near := rv.sprite_count()
	assert_gt(near, 10)
	assert_eq(actors.get_child_count(), near)
	rv.follow(Vector2(40000, 40000))
	await get_tree().process_frame
	assert_lt(actors.get_child_count(), near + rv.sprite_count() + 1)
	rv.clear()


func test_bad_ruin_records_are_reported() -> void:
	var dir := SimKit.copy_data("res://data", "bad_ruins")
	(
		SimKit
		. write_json(
			dir.path_join("ruins.json"),
			[
				{
					"id": "a",
					"sprite": "placeholder:x",
					"display_scale": 1,
					"foot": [0.5, 0.9],
					"footprint": {"w": 10, "h": 4},
					"weight": 1,
					"solid": true
				},
				{
					"id": "a",
					"sprite": "res://yok.png",
					"display_scale": 0,
					"foot": [2, 0.9],
					"footprint": {"w": 0},
					"weight": 1,
					"solid": "evet"
				},
			]
		)
	)
	var errs := GameData.load_dir(dir).validate()
	assert_gt(errs.size(), 4, "yinelenen id, eksik dosya, aralık, footprint, solid türü")
	var joined := "\n".join(errs)
	assert_true("dup_id" in joined)
	assert_true("asset_missing" in joined)
	assert_true("out_of_range" in joined)
	assert_true("bad_type" in joined)
