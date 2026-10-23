extends GutTest
## OffscreenArrow.place: ekran dışı hedef için kenar konumu ve açı (1 dünya px = 1 ekran px, kamera ekran merkezinde).

const VIEW := Vector2(1080, 2400)
const SAFE := Rect2(0, 196, 1080, 2400 - 196 - 222)
const M := 50.0


func _place(target: Vector2) -> Dictionary:
	return OffscreenArrow.place(target, Vector2.ZERO, VIEW, SAFE, M)


func test_target_on_screen_is_hidden() -> void:
	assert_false(_place(Vector2(0, 0))["visible"])
	assert_false(_place(Vector2(500, 1100))["visible"])
	assert_false(_place(Vector2(-539, -1199))["visible"])


func test_four_directions_land_on_the_inner_safe_edge() -> void:
	var inner := SAFE.grow(-M)
	var cases := {
		Vector2(2000, 0): [inner.end.x, 1200.0, 0.0],
		Vector2(-2000, 0): [inner.position.x, 1200.0, PI],
		Vector2(0, 3000): [540.0, inner.end.y, PI * 0.5],
		Vector2(0, -3000): [540.0, inner.position.y, -PI * 0.5],
	}
	for t in cases.keys():
		var r := _place(t)
		assert_true(r["visible"])
		var p: Vector2 = r["pos"]
		var exp: Array = cases[t]
		assert_almost_eq(p.x, exp[0], 0.01, "x %s" % t)
		assert_almost_eq(p.y, exp[1], 0.01, "y %s" % t)
		assert_almost_eq(absf(angle_difference(r["angle"], exp[2])), 0.0, 0.001, "açı %s" % t)


func test_corner_directions_stay_inside_safe_rect() -> void:
	var inner := SAFE.grow(-M)
	for t in [
		Vector2(3000, 3000), Vector2(-3000, 3000), Vector2(3000, -3000), Vector2(-3000, -3000)
	]:
		var r := _place(t)
		assert_true(r["visible"])
		var p: Vector2 = r["pos"]
		assert_true(inner.grow(0.01).has_point(p), "güvenli dikdörtgen içinde %s" % p)
		assert_almost_eq(float(r["angle"]), (t).angle(), 0.001)


func test_diagonal_hits_the_nearer_edge() -> void:
	var r := _place(Vector2(1500, 300))  # yatay kenara önce varır
	var p: Vector2 = r["pos"]
	assert_almost_eq(p.x, 1080.0 - M, 0.01)
	assert_between(p.y, SAFE.position.y, SAFE.end.y)


func test_just_off_screen_target_is_visible_near_the_edge() -> void:
	var r := _place(Vector2(541, 0))
	assert_true(r["visible"])
	assert_lte((r["pos"] as Vector2).x, 1080.0 - M + 0.01)


func test_nearest_pickup_picks_the_closest_and_none_when_empty() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "pickups": false})
	assert_eq(OffscreenArrow.nearest_pickup(sim), -1)
	sim.debug_spawn_pickup(&"kizil_iksir", sim.player_pos + Vector2(900, 0))
	sim.debug_spawn_pickup(&"cekim_tasi", sim.player_pos + Vector2(0, 700))
	assert_eq(OffscreenArrow.nearest_pickup(sim), 1)


func test_node_refresh_shows_only_for_offscreen_nearest_pickup() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "pickups": false})
	var arrow := OffscreenArrow.new()
	add_child_autofree(arrow)
	arrow.size = Vector2(1080, 2000)
	assert_false(arrow.visible, "gizli doğar")
	arrow.bind(sim)
	assert_true(arrow.visible, "bind görünür yapar")
	sim.debug_spawn_pickup(&"kizil_iksir", sim.player_pos + Vector2(100, 0))
	sim.debug_spawn_pickup(&"kara_bomba", sim.player_pos + Vector2(0, 2500))
	arrow.refresh(0.016)
	assert_false(arrow._info["visible"], "en yakın ekranda: ok yok (uzaktakine işaret etmez)")
	sim.pickups.remove(0)
	arrow.refresh(0.016)
	assert_true(arrow._info["visible"])
