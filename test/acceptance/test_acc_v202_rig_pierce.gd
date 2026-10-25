extends GutTest
## Kabul (v2.0.2 K, R): delen temel saldırı (Rüzgar Kesiği) ve kolsuz atış noktası. Sözleşme satırı "Rüzgar Kesiği": hizalı 20 düşman,
## sv1: tek kesik PIERCE_ALL + FLAG_WIND + yarıçap 14, her düşmana en çok 1 DAMAGE, hasar ±%1. 60+ düşmanlı çizgide çift hasar
## sayısı ölçülür (HIT_SLOTS 96 >= 60: sıfır beklenir; plan: kusurlu davranış beklenen değer yapılmaz). Kolsuz atış noktası aynalanır.
## Delme sayacı mutasyon kanıtı (HIT_SLOTS / PIERCE_ALL bilinçli bozulunca kırmızı) kapanış raporundadır.

const BASE_DAMAGE := 12.0  # plan Arayüzler/6 Rüzgar Kesiği sv1


## Canlı tabanca ile ilk kesiği atar (sonra tabancayı susturur) ve kesik uçuşunu bitirir. Dönen: {sim, ids, shot_event, proj}.
func _first_crescent(line: Array[Vector2], run_steps: int = 150) -> Dictionary:
	var sim := AccV202.zyfen({}, false)
	var ids: Array[int] = []
	for p in line:
		ids.append(AccV202.dummy(sim, p))
	var proj := {}
	for _k in 120:
		sim.step(Vector2.ZERO)
		if SimKit.count_events(sim, SimEvents.SHOT) >= 1:
			break
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	if sim.projectiles.count > 0:
		var i := 0
		proj = {
			"flags": sim.projectiles.flags[i],
			"pierce": sim.projectiles.pierce[i],
			"rad": sim.projectiles.rad[i],
			"dmg": sim.projectiles.dmg[i],
		}
	AccV202.steps(sim, run_steps)
	return {"sim": sim, "ids": ids, "shot": SimKit.last_event(sim, SimEvents.SHOT), "proj": proj}


## Atış ekseni üzerinde hizalı çizgi: kesik cast noktasından çıktığı için çizgi cast noktasının y'sindedir.
func _line(n: int, x0: float, dx: float) -> Array[Vector2]:
	var probe := AccV202.zyfen()
	var y := PlayerRig.cast_point_world(probe.player_pos, false, probe.character.rig).y
	var out: Array[Vector2] = []
	for k in n:
		out.append(Vector2(x0 + dx * k, y))
	return out


func test_r1_aligned_20_enemies_get_at_most_one_hit_each_and_flags_are_right() -> void:
	if V202Slice.require(self, "R"):
		return
	var r := _first_crescent(_line(20, 400.0, 40.0))
	var sim: GameSim = r["sim"]
	var p: Dictionary = r["proj"]
	assert_false(p.is_empty(), "ilk atışta mermi doğdu")
	assert_eq(p["pierce"], ProjectilePool.PIERCE_ALL, "PIERCE_ALL")
	assert_true(int(p["flags"]) & ProjectilePool.FLAG_WIND != 0, "FLAG_WIND")
	assert_almost_eq(float(p["rad"]), 14.0, 0.001, "yarıçap 14")
	var hit := 0
	for id in r["ids"]:
		var hits := AccV202.damages(sim, &"bullet", id)
		assert_lte(hits.size(), 1, "düşman %d en çok 1 isabet" % id)
		for h in hits:
			assert_almost_eq(float(h["amount"]), BASE_DAMAGE, BASE_DAMAGE * 0.01, "hasar ±%1")
		hit += hits.size()
	assert_gte(hit, 12, "kesik hattın çoğunu deler (%d/20)" % hit)


func test_r2_sixty_enemy_line_gets_zero_double_damage() -> void:
	if V202Slice.require(self, "R"):
		return
	var r := _first_crescent(_line(60, 130.0, 18.0), 200)
	var sim: GameSim = r["sim"]
	var doubles := 0
	var hit := 0
	for id in r["ids"]:
		var n := AccV202.damages(sim, &"bullet", id).size()
		doubles += 1 if n > 1 else 0
		hit += 1 if n > 0 else 0
	assert_gte(hit, 40, "kesik çizgiyi deler (%d/60)" % hit)
	assert_eq(doubles, 0, "aynı düşmana çift hasar sayısı")


func test_r3_piercing_shot_does_not_stop_at_the_first_enemy() -> void:
	if V202Slice.require(self, "R"):
		return
	var r := _first_crescent(_line(3, 200.0, 150.0))
	var sim: GameSim = r["sim"]
	for id in r["ids"]:
		assert_eq(AccV202.damages(sim, &"bullet", id).size(), 1, "her düşman bir kez vuruldu")


func _origin_for(target: Vector2) -> Vector2:
	var r := _first_crescent([target], 1)
	return (r["shot"] as Dictionary).get("origin", Vector2.INF)


func test_r4_armless_shot_origin_is_the_cast_point_and_mirrors_with_the_target_side() -> void:
	if V202Slice.require(self, "R"):
		return
	var sim := AccV202.zyfen()
	var right := _origin_for(Vector2(300, 0)) - sim.player_pos
	var left := _origin_for(Vector2(-300, 0)) - sim.player_pos
	assert_ne(right, Vector2.INF - sim.player_pos, "SHOT olayı origin taşır")
	assert_gt(right.x, 0.0, "hedef sağda: cast noktası sağda")
	assert_lt(left.x, 0.0, "hedef solda: cast noktası solda")
	assert_almost_eq(left.x, -right.x, 0.01, "x işareti ters, |x| korunur")
	assert_almost_eq(left.y, right.y, 0.01, "y aynı")
	var rig: Dictionary = sim.character.rig
	var want := PlayerRig.cast_point_world(sim.player_pos, false, rig) - sim.player_pos
	assert_almost_eq(right.x, want.x, 0.5, "sağ origin = cast_point_world")
	assert_almost_eq(right.y, want.y, 0.5)
	var cp: Vector2 = sim.character.cast_point
	var h := float(rig["display_height"])
	assert_almost_eq(
		right.length(), cp.length() * h, 2.0, "uzaklık = |cast_point| x display_height (JSON'dan)"
	)


func test_r5_facing_rule_follows_target_x_not_travel_direction() -> void:
	if V202Slice.require(self, "R"):
		return
	var sim := AccV202.zyfen()
	var up_right := _origin_for(Vector2(5, -400)) - sim.player_pos
	var up_left := _origin_for(Vector2(-5, -400)) - sim.player_pos
	assert_gt(up_right.x, 0.0, "hedef.x > oyuncu.x => sağ")
	assert_lt(up_left.x, 0.0, "hedef.x < oyuncu.x => sol")


func test_r6_gunslinger_keeps_the_arm_muzzle_path() -> void:
	if V202Slice.require(self, "R"):
		return
	var g := SimKit.make(1, {"character": &"gunslinger"})
	assert_false(PlayerRig.is_armless(g.character.rig), "Gunslinger kollu")
	assert_false(g.character.armless)
	var z := SimKit.make(1, {"character": &"zyfen"})
	assert_true(PlayerRig.is_armless(z.character.rig), "Zyfen kolsuz")
