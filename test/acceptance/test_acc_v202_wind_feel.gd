extends GutTest
## Kabul (v2.0.2 K, W): delen kesiğin "his" vekil ölçütleri (plan test stratejisi): 50 düşmanlı çizgide kesik başına ortalama
## isabet >= 5; kesik/mızrak yarıçap ve hızı Gunslinger mermisinden farklı. Sayılar plandan (900 px/sn, yarıçap 8 = Gunslinger).

const G_SPEED := 900.0
const G_RADIUS := 8.0


func _cast_y() -> float:
	var p := AccV202.zyfen()
	return PlayerRig.cast_point_world(p.player_pos, false, p.character.rig).y


func test_w1_a_crescent_hits_at_least_five_enemies_on_average_in_a_50_enemy_line() -> void:
	if V202Slice.require(self, "W"):
		return
	var sim := AccV202.zyfen({}, false)
	sim.gun_cd = PackedFloat32Array([0.0, 1.0e9])
	var y := _cast_y()
	for k in 50:
		AccV202.dummy(sim, Vector2(400.0 + 20.0 * k, y))
	var shots := 0
	for _n in 400:
		sim.step(Vector2.ZERO)
		shots = SimKit.count_events(sim, SimEvents.SHOT)
		if shots >= 4:
			sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
			break
	AccV202.steps(sim, 140)  # uçuştaki kesikler sönsün
	var hits := AccV202.damages(sim, &"bullet").size()
	assert_gte(shots, 4)
	var per := float(hits) / float(shots)
	assert_gte(
		per, 5.0, "kesik başına ortalama isabet %.1f (%d isabet / %d kesik)" % [per, hits, shots]
	)


func test_w2_crescent_radius_differs_from_the_gunslinger_bullet() -> void:
	if V202Slice.require(self, "W"):
		return
	var z := AccV202.zyfen({}, false)
	var g := AccV202.zyfen({}, false, 1, &"gunslinger")
	AccV202.dummy(z, Vector2(400, _cast_y()))
	AccV202.dummy(g, Vector2(400, 0))
	SimKit.run_until(z, func() -> bool: return z.projectiles.count > 0, 60)
	SimKit.run_until(g, func() -> bool: return g.projectiles.count > 0, 60)
	assert_gt(z.projectiles.count, 0)
	assert_gt(g.projectiles.count, 0)
	assert_almost_eq(g.projectiles.rad[0], G_RADIUS, 0.001, "Gunslinger mermi yarıçapı 8")
	assert_gt(z.projectiles.rad[0], g.projectiles.rad[0] * 1.5, "kesik belirgin biçimde geniş")


func test_w3_piercing_wind_spear_differs_in_speed_and_radius_from_the_gunslinger_bullet() -> void:
	if V202Slice.require(self, "W"):
		return
	var sim := AccV202.zyfen({"delen_ruzgar": 1})
	AccV202.dummy(sim, Vector2(500, 0))
	SimKit.run_until(sim, func() -> bool: return sim.projectiles.count > 0, 60)
	assert_gt(sim.projectiles.count, 0)
	assert_gt(
		sim.projectiles.vel[0].length(), G_SPEED * 1.4, "mızrak hızı Gunslinger'dan belirgin hızlı"
	)
	assert_ne(sim.projectiles.rad[0], G_RADIUS, "yarıçap farklı")
