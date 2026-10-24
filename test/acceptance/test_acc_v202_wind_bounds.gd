extends GutTest
## Kabul (v2.0.2 K, Z): sınır durumları (plan Test stratejisi: "Merkez mesafe 0, harita kenarı, harabe içine gömülme, büyük yarıçap").
## Davranış: hiçbir değer NaN/sonsuz olmaz, çakışan merkezdeki düşman sağa itilir, katı harabe içine gömülmez (EnemyAI çözümünün
## 0,8 x yarıçap payıyla), çok büyük yarıçap tüm düşmanları tam bir kez vurur, harita yüklenen alanın dışına itme çökertmez.

const EMBED_SLACK := 2.0


func _finite(p: Vector2) -> bool:
	return is_finite(p.x) and is_finite(p.y)


func test_z1_enemy_exactly_on_the_wave_and_girdap_center_is_pushed_right_without_nan() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"nefes_dalgasi": 1, "girdap": 1})
	var a := AccV202.dummy(sim, sim.player_pos)
	AccV202.steps(sim, 2)
	AccV202.begin_reload(sim)
	assert_true(_finite(AccV202.pos_of(sim, a)), "mesafe 0: konum sonlu")
	assert_gt(AccV202.pos_of(sim, a).x, sim.player_pos.x + 100.0, "merkezdeki düşman sağa itilir")
	AccV202.steps(sim, 90)
	assert_true(_finite(AccV202.pos_of(sim, a)))


func test_z2_twister_centered_exactly_on_an_enemy_keeps_positions_finite() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({})
	var e := AccV202.dummy(sim, Vector2(300, 0))
	sim.zones.spawn(
		ZonePool.KIND_TWISTER,
		Vector2(300, 0),
		{
			"radius": 150.0,
			"life": 1.0,
			"tick_every": 0.4,
			"dmg": 5.0,
			"pull": 100.0,
			"fling": 220.0,
			"speed": 0.0
		}
	)
	AccV202.steps(sim, 90)
	assert_true(_finite(AccV202.pos_of(sim, e)), "çekim merkezi üstünde NaN yok")
	assert_eq(sim.zones.count, 0, "bölge ömrü bitince kalktı")
	assert_gt(AccV202.damages(sim, &"dot", e).size(), 1, "tikler vurdu")


func test_z3_huge_radius_hits_every_enemy_exactly_once_per_tick() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({})
	var ids: Array[int] = []
	for k in 150:
		var a := TAU * float(k) / 150.0
		ids.append(AccV202.dummy(sim, Vector2.from_angle(a) * (200.0 + 9.0 * k)))
	sim.zones.spawn(
		ZonePool.KIND_TWISTER,
		Vector2.ZERO,
		{"radius": 3000.0, "life": 5.0, "tick_every": 0.4, "dmg": 3.0, "speed": 0.0}
	)
	var first := sim.step_count
	for _k in 25:
		sim.step(Vector2.ZERO)
	var ticks := AccV202.damages(sim, &"dot", ids[0], first).size()
	assert_between(ticks, 1, 1, "0,4 sn'lik adımda tam bir tik")
	for id in ids:
		assert_eq(
			AccV202.damages(sim, &"dot", id, first).size(),
			ticks,
			"düşman %d de aynı sayıda tik aldı" % id
		)
	assert_eq(Array(sim.check_invariants()), [])


func test_z4_enemy_pushed_toward_a_solid_ruin_does_not_end_up_inside_it() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"nefes_dalgasi": 1})
	var solid := Vector3.ZERO
	for o in sim.map.obstacles_near(Vector2(900, 0)):
		if o.z >= 40.0 and Vector2(o.x, o.y).length() > 600.0:
			solid = o
			break
	assert_gt(solid.z, 0.0, "yakında katı harabe bulundu")
	if solid.z <= 0.0:
		return
	var o := Vector2(solid.x, solid.y)
	var d := o.normalized()
	var radius := 26.0  # curumus_piyade
	var e_pos := o - d * (solid.z + radius + 6.0)
	sim.player_pos = e_pos - d * 70.0
	var e := AccV202.dummy(sim, e_pos)
	AccV202.steps(sim, 2)
	AccV202.begin_reload(sim)  # itme: oyuncudan dışa = harabeye doğru
	var dist := AccV202.pos_of(sim, e).distance_to(o)
	assert_gte(
		dist,
		solid.z + radius * 0.8 - EMBED_SLACK,
		"harabeye gömülmedi (%.1f >= %.1f)" % [dist, solid.z + radius * 0.8]
	)


func test_z5_displacement_beyond_the_loaded_map_area_stays_finite() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"nefes_dalgasi": 5})
	sim.player_pos = Vector2(2900, 0)  # yüklü bölge kenarı
	var e := AccV202.dummy(sim, Vector2(3050, 0))
	AccV202.steps(sim, 2)
	AccV202.begin_reload(sim)
	assert_true(_finite(AccV202.pos_of(sim, e)))
	AccV202.steps(sim, 60)
	assert_true(_finite(AccV202.pos_of(sim, e)))
	assert_eq(Array(sim.check_invariants()), [])
