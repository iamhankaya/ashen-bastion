extends GutTest
## Kabul: şarjör ritmiyle etkileşen beceriler (en az 2 beceri, kabul kriteri). Plan "Denge tabloları" + kanca eşlemesi.
## seken_mermi ve son_mermi_patlar slice 1; doldurma_sacilmasi slice 2.

const GROUP := [Vector2(450, 0), Vector2(470, 60), Vector2(500, -50), Vector2(430, 110)]


func _sim_with_group(seed_value: int = 31) -> GameSim:
	var sim := SimKit.make(seed_value)
	for p in GROUP:
		assert_ne(SimKit.add_enemy(sim, &"sovalye_hayaleti", p), -1, "hedef doğmadı")
	return sim


func _first_cycle_shots(sim: GameSim) -> Array:
	var out: Array = []
	var starts := SimKit.events(sim, SimEvents.RELOAD_START)
	var cut := 1 << 30 if starts.is_empty() else int(starts[0]["step"])
	for s in SimKit.events(sim, SimEvents.SHOT):
		if int(s["step"]) <= cut:
			out.append(s)
	return out


func _bullet_damage_events(sim: GameSim) -> Array:
	var out: Array = []
	for d in SimKit.events(sim, SimEvents.DAMAGE):
		if str(d["kind"]) == "bullet":
			out.append(d)
	return out


func test_seken_mermi_level4_boosts_every_second_shot_damage() -> void:
	var sim := _sim_with_group()
	sim.debug_grant(&"seken_mermi", 4)  # every_n 2, damage_mult 1,3
	SimKit.run(sim, 60)
	var shots := _first_cycle_shots(sim)
	assert_gte(shots.size(), 6, "6 kurşun")
	for s in shots:
		var idx := int(s["index_in_mag"])
		var want := 15.0 * 1.3 if idx % 2 == 0 else 15.0
		assert_almost_eq(float(s["dmg"]), want, 0.01, "kurşun %d hasarı" % idx)


func test_seken_mermi_bounces_hit_extra_distinct_enemies() -> void:
	var base := _sim_with_group(32)
	SimKit.run(base, 120)
	var plain := _bullet_damage_events(base).size()
	var sim := _sim_with_group(32)
	sim.debug_grant(&"seken_mermi", 1)  # her 3. kurşun, 2 sekme
	SimKit.run(sim, 120)
	var with_ricochet := _bullet_damage_events(sim).size()
	assert_gt(with_ricochet, plain, "sekme ek vuruş üretmeli (%d > %d)" % [with_ricochet, plain])


func test_ricochet_never_hits_the_same_enemy_twice() -> void:
	var sim := SimKit.make(33)
	var id := SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(400, 0))
	assert_ne(id, -1)
	sim.debug_grant(&"seken_mermi", 5)  # her 2. kurşun, 5 sekme
	SimKit.run(sim, 100)  # ilk şarjörün tüm kurşunları isabet eder; ikinci şarjör henüz başlamaz
	var shots := _first_cycle_shots(sim)
	var hits := 0
	for d in _bullet_damage_events(sim):
		if int(d["target"]) == id:
			hits += 1
	assert_gte(shots.size(), 6)
	assert_eq(
		hits,
		shots.size(),
		"tek hedef: her kurşun hedefe en çok bir kez vurur (sekme tekrar vurmaz)"
	)


func test_son_mermi_patlar_explodes_only_on_last_bullet() -> void:
	var sim := _sim_with_group(34)
	sim.debug_grant(&"son_mermi_patlar", 1)
	var seen: Array = []
	sim.bus.explosion.connect(func(p: Vector2, r: float) -> void: seen.append([p, r]))
	SimKit.run(sim, 100)
	var shots := _first_cycle_shots(sim)
	assert_eq(shots.size(), 6)
	var last_step := int(shots[shots.size() - 1]["step"]) if not shots.is_empty() else 0
	var ex := SimKit.events(sim, SimEvents.EXPLOSION)
	assert_eq(ex.size(), 1, "ilk döngüde tam bir patlama (yalnız son kurşun)")
	if ex.is_empty():
		return
	assert_almost_eq(float(ex[0]["radius"]), 100.0, 0.01, "sv1 yarıçap 100")
	assert_almost_eq(float(ex[0]["dmg"]), 50.0, 0.01, "sv1 hasar 50")
	assert_gte(int(ex[0]["step"]), last_step, "patlama son kurşundan önce olamaz")
	assert_lte(int(ex[0]["step"]), last_step + 60, "patlama son kurşunun isabetiyle (<= 1 sn)")
	assert_eq(seen.size(), 1, "bus.explosion bir kez")
	if not seen.is_empty():
		assert_almost_eq(float(seen[0][1]), 100.0, 0.01)


func test_explosion_damage_ignores_armor() -> void:
	var sim := _sim_with_group(35)
	sim.debug_grant(&"son_mermi_patlar", 1)
	SimKit.run(sim, 100)
	var n := 0
	for d in SimKit.events(sim, SimEvents.DAMAGE):
		if str(d["kind"]) == "explosion":
			n += 1
			assert_almost_eq(
				float(d["amount"]), float(d["raw"]), 0.001, "alan hasarı zırhı yok sayar"
			)
			assert_almost_eq(float(d["amount"]), 50.0, 0.01, "zırhlı hedefe tam 50")
	assert_gt(n, 0, "patlama en az bir düşmana hasar vermeli")


func test_son_mermi_patlar_level5() -> void:
	var sim := _sim_with_group(36)
	sim.debug_grant(&"son_mermi_patlar", 5)
	SimKit.run(sim, 100)
	var ex := SimKit.events(sim, SimEvents.EXPLOSION)
	assert_gt(ex.size(), 0)
	if not ex.is_empty():
		assert_almost_eq(float(ex[0]["radius"]), 170.0, 0.01, "sv5 yarıçap 170")
		assert_almost_eq(float(ex[0]["dmg"]), 150.0, 0.01, "sv5 hasar 150")


func test_barut_kesesi_scales_explosion_area_and_damage() -> void:
	var sim := _sim_with_group(37)
	sim.debug_grant(&"son_mermi_patlar", 1)
	sim.debug_grant(&"barut_kesesi", 5)  # alan +%60, patlama hasarı +%40
	SimKit.run(sim, 100)
	var ex := SimKit.events(sim, SimEvents.EXPLOSION)
	assert_gt(ex.size(), 0)
	if ex.is_empty():
		return
	assert_almost_eq(float(ex[0]["radius"]), 160.0, 0.5, "yarıçap 100 x 1,6")
	var checked := 0
	for d in SimKit.events(sim, SimEvents.DAMAGE):
		if str(d["kind"]) == "explosion":
			checked += 1
			assert_almost_eq(float(d["raw"]), 70.0, 0.5, "patlama hasarı 50 x 1,4")
	assert_gt(checked, 0)


func test_agir_kursun_scales_bullet_damage() -> void:
	var sim := _sim_with_group(38)
	sim.debug_grant(&"agir_kursun", 5)  # +%50
	SimKit.run(sim, 20)
	var shots := SimKit.events(sim, SimEvents.SHOT)
	assert_gt(shots.size(), 0)
	if not shots.is_empty():
		assert_almost_eq(float(shots[0]["dmg"]), 22.5, 0.01, "15 x 1,5")


func test_at_least_two_rhythm_skills_react_to_the_magazine_in_slice1() -> void:
	# Kabul kriteri: >= 2 beceri şarjör ritmiyle etkileşir. Slice 1'de seken_mermi (indeks) ve son_mermi_patlar
	# (son kurşun) yukarıdaki testlerle kanıtlanır; burada veri etiketi ve yuva birlikteliği denetlenir.
	var data := GameData.load_default()
	for id in [&"seken_mermi", &"son_mermi_patlar", &"hizli_doldurma", &"fazladan_mermi"]:
		var s := data.get_skill(id)
		assert_not_null(s, "%s yok" % id)
		if s != null:
			assert_true("rhythm" in s.tags, "%s 'rhythm' etiketli olmalı" % id)
	var sim := SimKit.make(39)
	sim.debug_grant(&"seken_mermi", 1)
	sim.debug_grant(&"son_mermi_patlar", 1)
	assert_eq(sim.loadout.level_of(&"seken_mermi"), 1)
	assert_eq(sim.loadout.level_of(&"son_mermi_patlar"), 1)
	assert_eq(sim.loadout.level_of(&"cift_tabanca"), 1, "başlangıç becerisi yuvada")


func test_doldurma_sacilmasi_fires_radial_salvo_at_reload_start() -> void:
	if Slice.current() < 2:
		pending("doldurma_sacilmasi slice 2 içeriği")
		return
	var sim := _sim_with_group(40)
	sim.debug_grant(&"doldurma_sacilmasi", 1)
	SimKit.run(sim, 110)
	var starts := SimKit.events(sim, SimEvents.RELOAD_START)
	var ends := SimKit.events(sim, SimEvents.RELOAD_END)
	assert_gt(starts.size(), 0)
	if starts.is_empty():
		return
	var s0 := int(starts[0]["step"])
	var e0 := int(ends[0]["step"]) if not ends.is_empty() else s0 + 70
	var salvo := 0
	for s in SimKit.events(sim, SimEvents.SHOT):
		var st := int(s["step"])
		if st >= s0 and st < e0:
			salvo += 1
			assert_almost_eq(float(s["dmg"]), 10.0, 0.01, "salvo hasarı sv1: 10")
	assert_eq(salvo, 8, "doldurma başında 8 radyal kurşun (sv1)")


func test_rhythm_tags_cover_the_planned_seven_skills_in_slice2() -> void:
	if Slice.current() < 2:
		pending("slice 2: 7 ritim becerisi")
		return
	var data := GameData.load_default()
	for id in ExpectedTables.RHYTHM_TAGGED:
		var s := data.get_skill(id)
		assert_not_null(s, "%s yok" % id)
		if s != null:
			assert_true("rhythm" in s.tags, "%s 'rhythm' etiketli olmalı" % id)
