extends GutTest
## Kabul: karakter veri olarak tanımlı; yeni karakter eklemek oyun döngüsünü (kodu) değiştirmez.
## Sınama: gerçek data/ geçici dizine kopyalanır, yalnız bir JSON eklenir; sim aynı koddan yeni karakterle çalışır.

const HERO := &"test_hero"


func _hero_data() -> GameData:
	var dir := SimKit.copy_data(SimKit.REAL_DIR, "hero")
	SimKit.write_json(dir.path_join("waves.json"), SimKit.EMPTY_WAVES)
	var base: Dictionary = SimKit.read_json(dir.path_join("characters/gunslinger.json"))
	var hero := base.duplicate(true)
	hero["id"] = String(HERO)
	hero["name"] = "Test Kahramanı"
	hero["max_hp"] = 150
	hero["move_speed"] = 450
	hero["mag_cap"] = 4
	hero["reload_time"] = 2.0
	hero["pickup_radius"] = 140
	hero["range"] = 650
	SimKit.write_json(dir.path_join("characters/%s.json" % HERO), hero)
	return GameData.load_dir(dir)


func after_all() -> void:
	SimKit.remove_tmp()


func test_new_character_json_validates_without_code_changes() -> void:
	var g := _hero_data()
	assert_not_null(g.get_character(HERO), "yeni karakter yüklendi")
	assert_not_null(g.get_character(&"gunslinger"), "mevcut karakter bozulmadı")
	assert_eq(
		g.validate({}, Slice.is_content_complete()), PackedStringArray(), "veri doğrulaması hatasız"
	)


func test_new_character_runs_in_the_same_sim_with_its_own_stats() -> void:
	var g := _hero_data()
	var hero := SimKit.make(171, {"data": g, "character": HERO})
	var base := SimKit.make(171, {"data": g})
	assert_not_null(hero.character)
	assert_eq(hero.character.id, HERO)
	assert_eq(hero.max_hp, 150.0)
	assert_eq(hero.hp, 150.0)
	assert_eq(hero.magazine.cap, 4, "şarjör verisi")
	assert_eq(hero.magazine.count, 4)
	assert_eq(base.max_hp, 100.0, "gunslinger verisi değişmedi")
	assert_eq(base.magazine.cap, 6)
	assert_eq(hero.loadout.level_of(&"cift_tabanca"), 1, "başlangıç becerisi veriden")
	SimKit.run(hero, 15, Vector2.RIGHT)
	SimKit.run(base, 15, Vector2.RIGHT)
	assert_almost_eq(hero.player_pos.x, 450.0 * 0.25, 0.6, "hız 450 px/sn verisi")
	assert_almost_eq(base.player_pos.x, 300.0 * 0.25, 0.6, "hız 300 px/sn")
	assert_eq(hero.check_invariants(), PackedStringArray())


func test_new_character_reload_time_and_range_come_from_data() -> void:
	var g := _hero_data()
	var hero := SimKit.make(172, {"data": g, "character": HERO})
	SimKit.add_enemy(hero, &"sovalye_hayaleti", Vector2(500, 0))
	SimKit.run(hero, 120)
	var starts := SimKit.events(hero, SimEvents.RELOAD_START)
	assert_gt(starts.size(), 0, "4 kurşun sonra doldurma")
	if not starts.is_empty():
		assert_almost_eq(
			float(starts[0]["duration"]), 2.0, 0.01, "doldurma süresi veriden (2,0 sn)"
		)
	var s0 := int(starts[0]["step"]) if not starts.is_empty() else 1 << 30
	var n := 0
	for s in SimKit.events(hero, SimEvents.SHOT):
		if int(s["step"]) <= s0:
			n += 1
	assert_eq(n, 4, "şarjör 4")
	# Menzil 650: 680 px'teki hedef (70 px/sn ile yaklaşır) ilk ~0,4 sn vurulmaz; gunslinger (700) hemen vurur.
	var far_hero := SimKit.make(173, {"data": g, "character": HERO})
	SimKit.add_enemy(far_hero, &"sovalye_hayaleti", Vector2(680, 0))
	SimKit.run(far_hero, 15)
	assert_eq(SimKit.count_events(far_hero, SimEvents.SHOT), 0, "menzil 650 (veri)")
	var far_base := SimKit.make(173, {"data": g})
	SimKit.add_enemy(far_base, &"sovalye_hayaleti", Vector2(680, 0))
	SimKit.run(far_base, 15)
	assert_gt(SimKit.count_events(far_base, SimEvents.SHOT), 0, "gunslinger menzili 700")


func test_both_characters_play_a_full_short_run_with_the_same_loop() -> void:
	var g := _hero_data()
	for cid in [&"gunslinger", HERO]:
		var sim := SimKit.make(174, {"data": g, "character": cid})
		SimKit.godmode(sim)
		SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(400, 0))
		var rng := Bots.make_rng(174)
		var r := Bots.play(sim, Bots.GREEDY, 1800, rng, 60)
		assert_eq(r["violations"], PackedStringArray(), "%s: değişmezler" % cid)
		assert_gt(sim.step_count, 0)
		assert_gt(SimKit.count_events(sim, SimEvents.SHOT), 0, "%s: ateş eder" % cid)


func test_sim_code_has_no_hardcoded_character_ids() -> void:
	var offenders := PackedStringArray()
	var stack: Array[String] = ["res://scripts/sim"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			for line in FileAccess.get_file_as_string(dir.path_join(f)).split("\n"):
				var code: String = line.split("#")[0]
				if code.findn("gunslinger") != -1:
					offenders.append("%s/%s: %s" % [dir, f, line.strip_edges()])
		for d in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(d))
	assert_eq(
		offenders,
		PackedStringArray(),
		"sim kodu belirli bir karakter kimliğini (gunslinger) bilmemeli"
	)


func test_character_def_exposes_art_and_rig_as_data() -> void:
	var c := GameData.load_default().get_character(&"gunslinger")
	assert_not_null(c)
	if c == null:
		return
	for key in [
		"body", "arm", "display_height", "shoulders", "arm_pivot", "muzzle", "arm_scale", "sway"
	]:
		assert_true(c.rig.has(key), "rig.%s veride" % key)
	assert_eq((c.rig["shoulders"] as Array).size(), 2, "iki omuz")
	assert_ne(str(c.rig["body"]), "")
	assert_ne(str(c.rig["arm"]), "")
