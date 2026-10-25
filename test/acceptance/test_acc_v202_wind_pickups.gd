extends GutTest
## Kabul (v2.0.2 K, W/Z): rüzgar becerileri ile eklentiler (pickup). Plan §6: hasar `stats.bullet_dmg_mult` ile çarpılır, soğumalar
## `stats.fire_rate_mult`'a bölünür (Öfke Barutu / Kızgın Namlu çalışsın). Sonsuz Tambur'da Nefes Dalgası/Kasırga tetiklenmez (Açık nokta #6).
## Eklentiler gerçek pickups.json üzerinden toplanır (debug_spawn_pickup + debug_collect_pickups).

const BUFF_DAMAGE := 1.5  # data/pickups.json ofke_barutu
const BUFF_RATE := 1.4  # data/pickups.json kizgin_namlu


func _take(sim: GameSim, kind: StringName) -> void:
	assert_gte(sim.debug_spawn_pickup(kind, sim.player_pos), 0, "%s doğdu" % kind)
	sim.debug_collect_pickups()


func test_w1_rage_powder_scales_wind_projectile_damage() -> void:
	if V202Slice.require(self, "W"):
		return
	var sim := AccV202.zyfen({"hava_bicaklari": 1, "delen_ruzgar": 1})
	AccV202.dummy(sim, Vector2(250, 0))
	_take(sim, &"ofke_barutu")
	assert_true(SimKit.run_until(sim, func() -> bool: return sim.projectiles.count > 0, 40))
	var seen := {}
	for i in sim.projectiles.count:
		seen[snappedf(sim.projectiles.dmg[i], 0.01)] = true
	assert_true(
		(
			seen.has(snappedf(10.0 * BUFF_DAMAGE, 0.01))
			or seen.has(snappedf(80.0 * BUFF_DAMAGE, 0.01))
		),
		"kesik hasarı x1,5: %s" % str(seen.keys())
	)


func test_z1_rage_powder_scales_girdap_nefes_and_twister_damage() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"girdap": 1, "nefes_dalgasi": 1})
	var g := AccV202.dummy(sim, Vector2(100, 0), &"elit_piyade")
	AccV202.steps(sim, 2)
	_take(sim, &"ofke_barutu")
	AccV202.steps(sim, 35)
	var ev := AccV202.damages(sim, &"dot", g)
	assert_gt(ev.size(), 0, "Girdap darbesi")
	assert_almost_eq(
		float(ev[ev.size() - 1]["amount"]), 6.0 * BUFF_DAMAGE, 0.05, "Girdap tik hasarı x1,5"
	)
	AccV202.begin_reload(sim)
	var evs := AccV202.damages(sim, &"dot", g)
	assert_almost_eq(
		float(evs[evs.size() - 1]["amount"]), 14.0 * BUFF_DAMAGE, 0.05, "Nefes Dalgası hasarı x1,5"
	)
	var t := AccV202.zyfen({"hortum": 1})
	AccV202.dummy(t, Vector2(400, 0))
	_take(t, &"ofke_barutu")
	SimKit.run_until(t, func() -> bool: return t.zones.count > 0, 700)
	assert_almost_eq(
		t.zones.dmg[0], 8.0 * BUFF_DAMAGE, 0.05, "Hortum tik hasarı x1,5 (doğuş anında sabitlenir)"
	)


func _cast_gap(sim: GameSim) -> int:
	var casts: Array[int] = []
	var last := 0
	for _k in 900:
		sim.step(Vector2.ZERO)
		if sim.projectiles.count > last and sim.projectiles.life[sim.projectiles.count - 1] > 0.3:
			casts.append(sim.step_count)
		last = sim.projectiles.count
		if casts.size() >= 3:
			break
	return casts[2] - casts[1] if casts.size() >= 3 else -1


func test_w2_hot_barrel_divides_active_cooldowns_by_the_fire_rate() -> void:
	if V202Slice.require(self, "W"):
		return
	var base := AccV202.zyfen({"hava_bicaklari": 1})
	AccV202.dummy(base, Vector2(250, 0))
	var gap_base := _cast_gap(base)
	var hot := AccV202.zyfen({"hava_bicaklari": 1})
	AccV202.dummy(hot, Vector2(250, 0))
	_take(hot, &"kizgin_namlu")
	var gap_hot := _cast_gap(hot)
	assert_between(float(gap_base), 3.4 * 60 - 3, 3.4 * 60 + 3, "taban soğuma 3,4 sn")
	assert_between(
		float(gap_hot),
		3.4 / BUFF_RATE * 60 - 3,
		3.4 / BUFF_RATE * 60 + 3,
		"Kızgın Namlu: 3,4 / 1,4 sn"
	)


func test_z2_endless_drum_blocks_the_breath_wave_and_the_storm_burst() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"nefes_dalgasi": 5}, false)
	sim.debug_grant(&"kasirga_patlamasi")
	AccV202.dummy(sim, Vector2(300, 0))
	var waves: Array = []
	sim.fx.wind_wave.connect(func(_o: Vector2, _r: float, big: bool) -> void: waves.append(big))
	_take(sim, &"sonsuz_tambur")
	AccV202.steps(sim, 600)
	assert_eq(waves.size(), 0, "Sonsuz Tambur sürerken dalga yok (doldurma yok)")
	assert_gt(
		sim.kills + SimKit.count_events(sim, SimEvents.SHOT),
		5,
		"kontrol: tabanca ateş etmeye devam etti"
	)


func test_z3_magnet_and_heal_pickups_work_with_zyfen_cards_and_wind_kills() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hava_cebi": 5, "girdap": 5})
	sim.hp = 10.0
	sim.max_hp = 85.0
	_take(sim, &"kizil_iksir")
	assert_gt(sim.hp, 10.0, "iksir can verir")
	assert_lte(sim.hp, sim.max_hp, "hp <= max_hp değişmezi")
	sim.debug_fill(&"curumus_piyade", 40, 90.0)
	AccV202.steps(sim, 240)
	assert_eq(
		sim.check_invariants().size(),
		0,
		"rüzgar kill'leri + eklenti sonrası sim değişmezleri temiz"
	)
