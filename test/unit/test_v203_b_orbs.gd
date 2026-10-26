extends GutTest
## v2.0.3 B: ruh küreleri görünümü. Sim değişmez; yalnız GemRenderer tip/boyut/süzülme verisi.

var _hareket_azalt_before := false


func before_each() -> void:
	_hareket_azalt_before = Settings.hareket_azalt


func after_each() -> void:
	Settings.hareket_azalt = _hareket_azalt_before


func _sim() -> GameSim:
	return GameSim.new(11, &"gunslinger", {"end_mode": "timer", "end_time": 480.0})


func test_b1_buffer_carries_tier_and_pixel_size_per_gem() -> void:
	var sim := _sim()
	var r := GemRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	sim.gems.drop(Vector2(0, 0), 1)
	sim.gems.drop(Vector2(500, 0), 7)
	sim.gems.drop(Vector2(1000, 0), 120)
	r.refresh()
	var buf := r.multimesh.buffer
	assert_eq(sim.gems.count, 3)
	for i in 3:
		var o := i * GemRenderer.STRIDE
		var tier := GemTiers.tier_of(sim.gems.value[i])
		assert_eq(buf[o + 12], float(tier), "taş %d tipi" % i)
		assert_eq(buf[o], float(GemTiers.ORB_PX[tier]), "taş %d boyutu" % i)
		assert_eq(buf[o + 14], float(GemTiers.ORB_PX[tier]), "taş %d boy verisi" % i)
	var tiers := {buf[12], buf[GemRenderer.STRIDE + 12], buf[2 * GemRenderer.STRIDE + 12]}
	assert_eq(tiers.size(), 3, "üç tip birbirinden ayrı")


func test_b2_atlas_has_three_distinct_tiles() -> void:
	var img := GemRenderer.atlas_texture().get_image()
	assert_eq(img.get_size(), Vector2i(GemRenderer.TILE_PX * 3, GemRenderer.TILE_PX))
	var sums: Array[float] = []
	for t in 3:
		var s := 0.0
		for y in range(0, GemRenderer.TILE_PX, 4):
			for x in range(0, GemRenderer.TILE_PX, 4):
				var c := img.get_pixel(t * GemRenderer.TILE_PX + x, y)
				s += c.a * (c.r * 3.0 + c.g * 2.0 + c.b)
		sums.append(s)
		assert_gt(s, 0.0, "kutu %d boş değil" % t)
	assert_ne(sums[0], sums[1])
	assert_ne(sums[1], sums[2])


func test_b3_hareket_azalt_stops_bobbing() -> void:
	var r := GemRenderer.new()
	add_child_autofree(r)
	Settings.hareket_azalt = false
	r.refresh()
	assert_eq((r.material as ShaderMaterial).get_shader_parameter("bob_scale"), 1.0)
	Settings.hareket_azalt = true
	r.refresh()
	assert_eq((r.material as ShaderMaterial).get_shader_parameter("bob_scale"), 0.0)


func test_b4_drawing_orbs_does_not_touch_sim_state() -> void:
	var a := _sim()
	var b := _sim()
	var r := GemRenderer.new()
	add_child_autofree(r)
	r.bind(a)
	for s in [a, b]:
		s.gems.drop(Vector2(10, 10), 1)
		s.gems.drop(Vector2(90, 10), 120)
	r.refresh()
	assert_eq(a.gems.count, b.gems.count)
	assert_eq(a.gems.total_value(), b.gems.total_value())
