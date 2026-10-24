extends GutTest
## Kabul (v2.0.2 K, P): ortak pasiflerin Zyfen'deki etkileri (plan Arayüzler/2 tablosu, sv5 değerleri) ve yığma sınırları
## (sv5: şarjör 13, doldurma 0,65 sn; hepsi birlikte iken sıfıra bölme/NaN yok). Sayılar plandan: Rüzgar Adımı +%30,
## Yas Paltosu +75 can / 1,25 can/sn, Çeken Esinti +%125, Bilenmiş Rüzgar +%50, Çevik Eller +%40, Derin Nefes +5, Çabuk Toplayış -%50.


func test_p1_bilenmis_ruzgar_scales_the_crescent_damage() -> void:
	if V202Slice.require(self, "P"):
		return
	var sim := AccV202.zyfen({"agir_kursun": 5}, false)
	AccV202.dummy(sim, Vector2(300, 0))
	AccV202.steps(sim, 5)
	var shot := SimKit.last_event(sim, SimEvents.SHOT)
	assert_false(shot.is_empty())
	assert_almost_eq(float(shot["dmg"]), 12.0 * 1.5, 0.01, "12 x 1,5")


func test_p2_cevik_eller_shortens_the_shot_interval_by_the_attack_speed() -> void:
	if V202Slice.require(self, "P"):
		return
	var sim := AccV202.zyfen({"hizli_parmak": 5}, false)
	sim.gun_cd = PackedFloat32Array([0.0, 1.0e9])
	AccV202.dummy(sim, Vector2(300, 0))
	AccV202.steps(sim, 120)
	var shots := SimKit.events(sim, SimEvents.SHOT)
	assert_gte(shots.size(), 4)
	var gap := int(shots[2]["step"]) - int(shots[1]["step"])
	assert_between(float(gap), 0.36 / 1.4 * 60.0 - 1.5, 0.36 / 1.4 * 60.0 + 1.5, "0,36 / 1,4 sn")


func test_p3_derin_nefes_adds_five_shots_before_the_reload() -> void:
	if V202Slice.require(self, "P"):
		return
	var sim := AccV202.zyfen({"fazladan_mermi": 5}, false)
	assert_eq(sim.magazine.cap, 13, "8 + 5")
	AccV202.dummy(sim, Vector2(300, 0))
	SimKit.run_until(
		sim, func() -> bool: return SimKit.count_events(sim, SimEvents.RELOAD_START) > 0, 600
	)
	var shots_before := 0
	for e in sim.event_log:
		if e["type"] == SimEvents.RELOAD_START:
			break
		if e["type"] == SimEvents.SHOT:
			shots_before += 1
	assert_eq(shots_before, 13, "doldurmadan önce 13 kesik")


func test_p4_cabuk_toplayis_halves_the_gather_time() -> void:
	if V202Slice.require(self, "P"):
		return
	var sim := AccV202.zyfen({"hizli_doldurma": 5})
	AccV202.begin_reload(sim)
	assert_almost_eq(sim.magazine.reload_total, 1.3 * 0.5, 0.001, "1,3 sn -> 0,65 sn")
	var base := AccV202.zyfen({})
	AccV202.begin_reload(base)
	assert_almost_eq(base.magazine.reload_total, 1.3, 0.001, "taban 1,3 sn")


func test_p5_ruzgar_adimi_raises_move_speed_by_thirty_percent() -> void:
	if V202Slice.require(self, "P"):
		return
	var plain := AccV202.zyfen({})
	var fast := AccV202.zyfen({"cevik_cizme": 5})
	for s in [plain, fast]:
		for _k in 30:
			s.step(Vector2(0, -1))
	var d0 := plain.player_pos.length()
	var d1 := fast.player_pos.length()
	assert_almost_eq(d0, 310.0 * 0.5, 4.0, "taban 310 px/sn")
	assert_almost_eq(d1 / d0, 1.30, 0.02, "+%30")


func test_p6_yas_paltosu_raises_max_hp_and_regenerates() -> void:
	if V202Slice.require(self, "P"):
		return
	var sim := SimKit.make(1, {"character": &"zyfen", "log_events": false})
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	sim.debug_grant(&"saglam_yelek", 5)
	assert_almost_eq(sim.max_hp, 85.0 + 75.0, 0.01, "85 + 75")
	sim.hp = 50.0
	for _k in 60:
		sim.step(Vector2.ZERO)
	assert_almost_eq(sim.hp, 51.25, 0.2, "1,25 can/sn")
	assert_lte(sim.hp, sim.max_hp)


func test_p7_ceken_esinti_extends_the_pickup_radius() -> void:
	if V202Slice.require(self, "P"):
		return
	for with_passive in [false, true]:
		var sim := SimKit.make(1, {"character": &"zyfen", "log_events": false})
		sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
		if with_passive:
			sim.debug_grant(&"miknatis", 5)
		sim.gems.drop(Vector2(230, 0), 5)
		var xp0 := sim.xp
		for _k in 90:
			sim.step(Vector2.ZERO)
		if with_passive:
			assert_gt(
				sim.xp + (sim.level - 1) * 1000, xp0, "230 px: 110 x 2,25 = 247 içinde toplanır"
			)
		else:
			assert_eq(sim.xp, xp0, "230 px: 110 px yarıçapın dışında")


func test_p8_all_common_passives_at_max_never_produce_nan_or_zero_division() -> void:
	if V202Slice.require(self, "P"):
		return
	var grants := {}
	for id in ExpectedTablesV202.COMMON_NAMES:
		grants[id] = 5
	var sim := AccV202.zyfen(grants, false)
	sim.debug_grant(&"furtina_gozu", 5)
	sim.debug_fill(&"curumus_piyade", 60, 400.0)
	for k in 600:
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
		sim.step(Vector2(1, 0) if k % 120 < 60 else Vector2(-1, 0))
	assert_eq(Array(sim.check_invariants()), [], "değişmezler")
	assert_true(is_finite(sim.max_hp) and is_finite(sim.hp))
	assert_gt(sim.magazine.cap, 0)
	assert_gte(sim.magazine.reload_total, 0.0)
	assert_true(is_finite(sim.gun_interval / sim.stats.fire_rate_mult), "atış aralığı sonlu")
