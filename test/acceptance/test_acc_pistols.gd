extends GutTest
## Kabul: çift tabanca ritmi. Kurallar: plan "Magazine" + "cift_tabanca" (tabanca başına aralık, yarım aralık faz
## farkı, toplam hız 2/aralık, sv1'de 6 kurşun ~0,75 sn). Doğurma çizelgesi boş (SimKit "quiet").

const TARGET := Vector2(500, 0)


func _sim_with_target() -> GameSim:
	var sim := SimKit.make(11)
	var id := SimKit.add_enemy(sim, &"sovalye_hayaleti", TARGET)
	assert_ne(id, -1, "hedef doğmadı (debug_spawn -1)")
	return sim


func _shots(sim: GameSim) -> Array:
	return SimKit.events(sim, SimEvents.SHOT)


func test_first_cycle_has_six_shots_alternating_guns_in_about_075_s() -> void:
	var sim := _sim_with_target()
	SimKit.run(sim, 44)
	var shots := _shots(sim)
	assert_gte(shots.size(), 5, "0,73 sn'de en az 5 kurşun çıkmalı")
	SimKit.run(sim, 8)  # toplam 52 adım ~ 0,87 sn
	shots = _shots(sim)
	assert_gte(shots.size(), 6, "0,87 sn'de 6 kurşun çıkmış olmalı")
	if shots.size() < 6:
		return
	for i in 6:
		assert_eq(int(shots[i]["gun"]), i % 2, "kurşun %d tabancası (0,1,0,1,0,1)" % (i + 1))
		assert_eq(int(shots[i]["index_in_mag"]), i + 1, "kurşun %d şarjör indeksi" % (i + 1))
		assert_eq(bool(shots[i]["is_last"]), i == 5, "yalnız 6. kurşun is_last")
	assert_lte(int(shots[5]["step"]), 48, "6. kurşun <= 0,8 sn")
	assert_gte(int(shots[5]["step"]), 43, "6. kurşun >= 0,71 sn (aralık/2 faz farkı)")


func test_shot_spacing_is_half_interval_between_guns_and_full_interval_per_gun() -> void:
	var sim := _sim_with_target()
	SimKit.run(sim, 50)
	var shots := _shots(sim)
	if shots.size() < 6:
		fail_test("6 kurşun çıkmadı")
		return
	for i in 4:
		var same_gun := int(shots[i + 2]["step"]) - int(shots[i]["step"])
		assert_between(
			same_gun, 17, 19, "aynı tabanca aralığı 0,30 sn = 18 adım (kurşun %d)" % (i + 1)
		)
	for i in 5:
		var cross := int(shots[i + 1]["step"]) - int(shots[i]["step"])
		assert_between(cross, 8, 10, "tabancalar arası 0,15 sn = 9 adım (kurşun %d)" % (i + 1))


func test_total_fire_rate_is_two_over_interval_per_second() -> void:
	var sim := _sim_with_target()
	# 3 şarjör boyunca (doldurma dahil) değil, ilk şarjör içinde ölç: 5 aralık = 5 * 0,15 sn.
	SimKit.run(sim, 60)
	var shots := _shots(sim)
	if shots.size() < 6:
		fail_test("6 kurşun çıkmadı")
		return
	var span := float(int(shots[5]["step"]) - int(shots[0]["step"])) * GameSim.STEP
	assert_almost_eq(span, 5.0 * 0.15, 0.04, "ilk 6 kurşun 5 yarım-aralıkta çıkar")


func test_shot_damage_follows_active_level() -> void:
	var sim := _sim_with_target()
	SimKit.run(sim, 20)
	var s1 := _shots(sim)
	assert_gt(s1.size(), 0)
	if not s1.is_empty():
		assert_almost_eq(float(s1[0]["dmg"]), 15.0, 0.001, "sv1 hasarı 15")
	var sim5 := _sim_with_target()
	sim5.debug_grant(&"cift_tabanca", 5)
	SimKit.run(sim5, 20)
	var s5 := _shots(sim5)
	assert_gt(s5.size(), 0)
	if not s5.is_empty():
		assert_almost_eq(float(s5[0]["dmg"]), 28.0, 0.001, "sv5 hasarı 28")


func test_level5_interval_is_022_per_gun() -> void:
	var sim := _sim_with_target()
	sim.debug_grant(&"cift_tabanca", 5)
	SimKit.run(sim, 40)
	var shots := _shots(sim)
	if shots.size() < 4:
		fail_test("4 kurşun çıkmadı")
		return
	var same_gun := int(shots[2]["step"]) - int(shots[0]["step"])
	assert_between(same_gun, 12, 14, "sv5 aralığı 0,22 sn ~ 13 adım")


func test_hizli_parmak_shortens_interval() -> void:
	var sim := _sim_with_target()
	sim.debug_grant(&"hizli_parmak", 5)  # +%40 atış hızı: 0,30 / 1,4 = 0,214 sn
	SimKit.run(sim, 40)
	var shots := _shots(sim)
	if shots.size() < 4:
		fail_test("4 kurşun çıkmadı")
		return
	var same_gun := int(shots[2]["step"]) - int(shots[0]["step"])
	assert_between(same_gun, 12, 14, "hizli_parmak sv5 ile aralık 0,30/1,4 sn ~ 13 adım")


func test_no_target_means_no_shot_and_no_ammo_spent() -> void:
	var sim := SimKit.make(12)
	SimKit.run(sim, 120)
	assert_eq(SimKit.count_events(sim, SimEvents.SHOT), 0, "hedef yok => ateş yok")
	assert_eq(sim.magazine.count, 6, "şarjör harcanmaz")
	assert_false(sim.magazine.reloading, "boşuna doldurma başlamaz")
	assert_ne(SimKit.add_enemy(sim, &"sovalye_hayaleti", TARGET), -1)
	SimKit.run(sim, 20)
	assert_gt(SimKit.count_events(sim, SimEvents.SHOT), 0, "hedef gelince ateş başlar")
	assert_lt(sim.magazine.count, 6)


func test_enemy_out_of_range_is_not_shot() -> void:
	var sim := SimKit.make(13)
	SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(900, 0))
	SimKit.run(sim, 30)  # hedef 70 px/sn ile ~35 px yaklaşır; hâlâ >700 px
	assert_eq(SimKit.count_events(sim, SimEvents.SHOT), 0, "menzil 700 px")
	assert_ne(SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(500, 0)), -1)
	SimKit.run(sim, 20)
	assert_gt(SimKit.count_events(sim, SimEvents.SHOT), 0, "menzildeki düşmana ateş edilir")


func test_muzzle_origin_comes_from_player_rig_single_source() -> void:
	var sim := _sim_with_target()
	SimKit.run(sim, 12)
	var shots := _shots(sim)
	assert_gt(shots.size(), 1)
	var rig: Dictionary = sim.character.rig
	for s in shots:
		var dir: Vector2 = s["dir"]
		var want := PlayerRig.muzzle_world(
			int(s["gun"]), sim.player_pos, dir.angle(), dir.x < 0.0, rig
		)
		var got: Vector2 = s["origin"]
		assert_lt(
			got.distance_to(want),
			1.0,
			"tabanca %d çıkış noktası PlayerRig.muzzle_world ile aynı" % s["gun"]
		)
		assert_gt(dir.x, 0.9, "hedef sağda: yön ~ (+1, 0)")
