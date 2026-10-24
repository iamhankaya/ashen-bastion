extends GutTest

const FIX := "res://test/fixtures"

# Başka yolla sınanan kodlar (fixture bindirmesi uygun değil)
const COVERED_ELSEWHERE: Array[String] = ["behavior_base"]


func after_all() -> void:
	KitDev.remove_tmp()


func _validate(dir: String, complete: bool = true) -> PackedStringArray:
	return GameData.load_dir(dir).validate({}, complete)


func _has_code(errs: PackedStringArray, code: String) -> bool:
	for e in errs:
		if e.begins_with("[%s] " % code):
			return true
	return false


func test_valid_fixture_has_no_errors() -> void:
	var errs := _validate(KitDev.data_dir())
	assert_eq(errs.size(), 0, "geçerli fixture hatasız olmalı: %s" % [errs])


func test_default_data_is_valid() -> void:
	assert_eq(GameData.load_dir("res://data").validate(), PackedStringArray())


func test_shipped_evolutions_have_distinct_existing_sfx() -> void:
	var gd := GameData.load_dir("res://data")
	var used := {}
	for sk in gd.skills_of_kind(SkillDef.KIND_EVOLUTION):
		assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % sk.sfx), str(sk.id))
		assert_false(used.has(sk.sfx), "ses tekrarı: %s" % sk.sfx)
		used[sk.sfx] = true


func test_bad_fixtures_report_their_code() -> void:
	var dirs := DirAccess.get_directories_at(FIX)
	dirs.sort()
	var seen := 0
	for d in dirs:
		if not d.begins_with("data_bad_"):
			continue
		seen += 1
		var code := d.trim_prefix("data_bad_")
		var errs := _validate(KitDev.data_dir(FIX + "/" + d))
		assert_true(_has_code(errs, code), "%s: [%s] bekleniyordu, gelen: %s" % [d, code, errs])
	assert_gt(seen, 0)


func test_every_error_code_has_a_bad_fixture() -> void:
	var dirs := DirAccess.get_directories_at(FIX)
	for code in GameData.ERROR_CODES:
		if COVERED_ELSEWHERE.has(code):
			continue
		assert_true(dirs.has("data_bad_" + code), "data_bad_%s eksik" % code)


func test_every_bad_fixture_is_a_known_code() -> void:
	for d in DirAccess.get_directories_at(FIX):
		if d.begins_with("data_bad_"):
			assert_true(
				GameData.ERROR_CODES.has(d.trim_prefix("data_bad_")), "%s bilinmeyen kod" % d
			)


func test_error_line_format_is_code_context_message() -> void:
	var errs := _validate(KitDev.data_dir(FIX + "/data_bad_bad_ai"))
	assert_gt(errs.size(), 0)
	var rx := RegEx.create_from_string("^\\[[a-z_]+\\] [^:]+: .+")
	assert_not_null(rx.search(errs[0]), "biçim '[kod] bağlam: açıklama' olmalı: %s" % errs[0])


func test_behavior_must_derive_from_skill_behavior() -> void:
	var g := GameData.load_dir(KitDev.data_dir())
	var reg := SkillRegistry.BEHAVIORS.duplicate()
	reg[&"cift_tabanca"] = GameData  # SkillBehavior'dan türemeyen bir script
	var errs := g.validate(reg)
	assert_true(_has_code(errs, "behavior_base"), "behavior_base bekleniyordu: %s" % [errs])


func test_rhythm_rule_only_in_complete_mode() -> void:
	var dir := KitDev.data_dir(FIX + "/data_bad_rhythm_count")
	assert_false(_has_code(_validate(dir, false), "rhythm_count"))
	assert_true(_has_code(_validate(dir, true), "rhythm_count"))


func test_starting_skill_must_be_an_existing_active() -> void:
	var ch: Dictionary = KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json")
	ch["starting_skill"] = "olmayan"
	var errs := _validate(KitDev.data_dir_with({"characters/gunslinger.json": ch}))
	assert_true(_has_code(errs, "requires_ref"))
	ch["starting_skill"] = "barut_kesesi"
	errs = _validate(KitDev.data_dir_with({"characters/gunslinger.json": ch}))
	assert_true(_has_code(errs, "requires_kind"))


func test_rig_numbers_are_range_checked() -> void:
	var ch: Dictionary = KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json")
	ch["rig"]["muzzle"] = [1.4, 0.3]
	assert_true(
		_has_code(
			_validate(KitDev.data_dir_with({"characters/gunslinger.json": ch})), "out_of_range"
		)
	)
	ch["rig"]["muzzle"] = [0.9, 0.3]
	ch["rig"]["sway"]["scarf_rect"] = [0.5, 0.1, 0.2, 0.9]
	assert_true(
		_has_code(
			_validate(KitDev.data_dir_with({"characters/gunslinger.json": ch})), "out_of_range"
		)
	)


func test_passive_levels_are_totals_and_must_not_shrink() -> void:
	var p: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/barut_kesesi.json")
	p["levels"][3]["area_mult"] = 0.1
	var errs := _validate(KitDev.data_dir_with({"skills/barut_kesesi.json": p}))
	assert_true(_has_code(errs, "levels_monotonic"))


func test_reload_time_passive_uses_negative_totals() -> void:
	# reload_time_mult x değeri 0'dan aşağı büyür (|x| artar); pozitif değer aralık dışıdır
	var p: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/hizli_doldurma.json")
	p["levels"][0]["reload_time_mult"] = 0.1
	var errs := _validate(KitDev.data_dir_with({"skills/hizli_doldurma.json": p}))
	assert_true(_has_code(errs, "out_of_range"))


func test_active_cooldown_may_decrease_but_not_increase() -> void:
	var s: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/cift_tabanca.json")
	assert_eq(_validate(KitDev.data_dir_with({"skills/cift_tabanca.json": s})).size(), 0)
	s["levels"][4]["interval"] = 0.5
	assert_true(
		_has_code(
			_validate(KitDev.data_dir_with({"skills/cift_tabanca.json": s})), "levels_monotonic"
		)
	)


func test_loaded_defs_are_typed_and_ordered() -> void:
	var g := GameData.load_dir(KitDev.data_dir())
	assert_eq(g.character_ids, [&"gunslinger"] as Array[StringName])
	assert_eq(g.skill_ids.size(), 6)
	var names: Array[String] = []
	for id in g.skill_ids:
		names.append(String(id))
	var sorted_names := names.duplicate()
	sorted_names.sort()
	assert_eq(
		names,
		sorted_names,
		"kimlikler dosya adı sırasında (StringName sıralaması adres bazlıdır, String kullan)"
	)
	var c := g.get_character(&"gunslinger")
	assert_eq(c.max_hp, 100.0)
	assert_eq(c.mag_cap, 6)
	assert_eq(c.attack_range, 700.0)
	assert_eq(c.starting_skill, &"cift_tabanca")
	var s := g.get_skill(&"seken_mermi")
	assert_eq(s.kind, SkillDef.KIND_ACTIVE)
	assert_eq(s.levels.size(), s.max_level)
	assert_eq(s.level_data(4)["every_n"], 2.0)
	assert_eq(s.level_data(0), {})
	assert_eq(g.skills_of_kind(SkillDef.KIND_EVOLUTION).size(), 1)
	var e := g.get_enemy(&"kale_lordu")
	assert_eq(e.ai, &"lord")
	assert_eq(e.summon["count"], 12.0)
	assert_null(g.get_skill(&"yok"))


func test_load_default_is_cached() -> void:
	GameData.clear_default_cache()
	var a := GameData.load_default()
	assert_same(a, GameData.load_default())
	GameData.clear_default_cache()


func test_missing_record_directories_count_as_empty() -> void:
	# temiz checkout'ta boş dizinler (ör. data/enemies) git'te yoktur
	var dir := KitDev.data_dir()
	for sub in ["enemies", "skills"]:
		KitDev.remove_dir(dir.path_join(sub))
	var g := GameData.load_dir(dir)
	assert_eq(g.enemy_ids.size(), 0)
	assert_eq(g.skill_ids.size(), 0)
	assert_false(_has_code(g.validate(), "bad_json"))


func test_evolution_requires_is_mandatory_and_must_be_an_object() -> void:
	var evo: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/zincirleme_patlama.json")
	evo.erase("requires")
	var errs := _validate(KitDev.data_dir_with({"skills/zincirleme_patlama.json": evo}))
	assert_true(_has_code(errs, "missing_field"), "requires yok: %s" % [errs])
	evo["requires"] = "x"
	errs = _validate(KitDev.data_dir_with({"skills/zincirleme_patlama.json": evo}))
	assert_true(_has_code(errs, "bad_type"), "requires metin: %s" % [errs])
	evo["requires"] = {
		"active": "seken_mermi",
		"active_level": 5,
		"passive": "barut_kesesi",
		"passive_min_level": 1,
		"x": 1
	}
	errs = _validate(KitDev.data_dir_with({"skills/zincirleme_patlama.json": evo}))
	assert_true(_has_code(errs, "unknown_key"))


func test_literal_null_json_is_rejected() -> void:
	var errs := _validate(KitDev.data_dir_with({"waves.json": "null"}))
	assert_true(_has_code(errs, "not_object"), "waves null: %s" % [errs])
	errs = _validate(KitDev.data_dir_with({"enemies/les_kargasi.json": "null"}))
	assert_true(_has_code(errs, "not_object"), "enemy null: %s" % [errs])


func test_active_level_values_are_bounded() -> void:
	var s: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/cift_tabanca.json")
	s["levels"][0]["interval"] = 0.0
	assert_true(
		_has_code(_validate(KitDev.data_dir_with({"skills/cift_tabanca.json": s})), "out_of_range")
	)
	s = KitDev.read_json(FIX + "/data_valid/skills/cift_tabanca.json")
	s["levels"][1]["damage"] = -5
	assert_true(
		_has_code(_validate(KitDev.data_dir_with({"skills/cift_tabanca.json": s})), "out_of_range")
	)
	s = KitDev.read_json(FIX + "/data_valid/skills/son_mermi_patlar.json")
	s["levels"][4]["ex_radius"] = 1.0e9
	assert_true(
		_has_code(
			_validate(KitDev.data_dir_with({"skills/son_mermi_patlar.json": s})), "out_of_range"
		)
	)


func test_unknown_keys_are_rejected_on_every_record_type() -> void:
	var ch: Dictionary = KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json")
	ch["rnage"] = 700
	assert_true(
		_has_code(
			_validate(KitDev.data_dir_with({"characters/gunslinger.json": ch})), "unknown_key"
		)
	)
	var en: Dictionary = KitDev.read_json(FIX + "/data_valid/enemies/kale_lordu.json")
	en["chrage"] = {"every": 4, "duration": 1, "speed": 300}
	assert_true(
		_has_code(_validate(KitDev.data_dir_with({"enemies/kale_lordu.json": en})), "unknown_key")
	)
	var sk: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/cift_tabanca.json")
	sk["tagz"] = []
	assert_true(
		_has_code(_validate(KitDev.data_dir_with({"skills/cift_tabanca.json": sk})), "unknown_key")
	)


# --- v1.1 sözleşmesi: eklentiler, skor, düşman anim, rig.walk -------------------------------------


func _pickups() -> Dictionary:
	return KitDev.read_json(FIX + "/data_valid/pickups.json")


func _score() -> Dictionary:
	return KitDev.read_json(FIX + "/data_valid/score.json")


## Bozulmuş pickups.json ile doğrular (tam mod).
func _pk_errs(d: Dictionary) -> PackedStringArray:
	return _validate(KitDev.data_dir_with({"pickups.json": d}))


func _sc_errs(d: Dictionary) -> PackedStringArray:
	return _validate(KitDev.data_dir_with({"score.json": d}))


func _kind(d: Dictionary, id: String) -> Dictionary:
	for k in d["kinds"]:
		if k["id"] == id:
			return k
	return {}


func test_valid_fixture_loads_pickups_and_score_tables() -> void:
	var g := GameData.load_dir(KitDev.data_dir())
	assert_eq(g.validate({}, true), PackedStringArray())
	assert_eq(g.pickup_ids.size(), 6)
	assert_eq(g.pickup_ids[0], &"kizil_iksir", "kinds dizi sırası korunur")
	assert_eq(g.pickup_ids[5], &"sonsuz_tambur")
	var bomb := g.get_pickup(&"kara_bomba")
	assert_eq(bomb.effect, &"bomb")
	assert_eq(bomb.rarity, &"uncommon")
	assert_eq(bomb.radius, 320.0)
	assert_eq(bomb.fuse, 0.8)
	assert_eq(bomb.dmg, 600.0)
	assert_null(g.get_pickup(&"yok"))
	assert_eq(g.pickup_cfg["spawn"]["max_alive"], 2.0)
	assert_eq(g.score_table.points(&"kale_lordu"), 10000)
	assert_eq(g.score_table.window_steps, 180)


func test_missing_pickups_and_score_files_mean_empty_tables() -> void:
	var dir := KitDev.data_dir_with({"pickups.json": null, "score.json": null})
	var g := GameData.load_dir(dir)
	assert_eq(g.pickup_ids.size(), 0)
	assert_true(g.pickup_cfg.is_empty())
	assert_eq(g.score_table.points(&"curumus_piyade"), 0)
	assert_eq(g.score_table.mult_for(500), 1, "varsayılan tablo tek basamak")
	assert_eq(g.validate({}, false), PackedStringArray(), "tam mod dışında dosya isteğe bağlı")
	var errs := g.validate({}, true)
	assert_true(_has_code(errs, "missing_file"), "tam modda zorunlu: %s" % [errs])


func test_real_pickup_data_matches_plan_numbers() -> void:
	var g := GameData.load_dir("res://data")
	assert_eq(
		g.pickup_ids,
		(
			[
				&"kizil_iksir",
				&"cekim_tasi",
				&"ofke_barutu",
				&"kizgin_namlu",
				&"kara_bomba",
				&"sonsuz_tambur"
			]
			as Array[StringName]
		)
	)
	var sp: Dictionary = g.pickup_cfg["spawn"]
	assert_eq(sp["first"], [30.0, 45.0])
	assert_eq(sp["interval"], [45.0, 60.0])
	assert_eq(sp["dist"], [450.0, 700.0])
	assert_eq(
		[sp["clearance"], sp["life"], sp["blink_last"], sp["collect_radius"], sp["max_alive"]],
		[40.0, 25.0, 5.0, 72.0, 2.0]
	)
	var weights := {}
	var total := 0.0
	for id in g.pickup_ids:
		weights[String(id)] = g.get_pickup(id).weight
		total += g.get_pickup(id).weight
	assert_eq(total, 100.0)
	assert_eq(
		weights,
		{
			"kizil_iksir": 30.0,
			"cekim_tasi": 20.0,
			"ofke_barutu": 15.0,
			"kizgin_namlu": 15.0,
			"kara_bomba": 15.0,
			"sonsuz_tambur": 5.0
		}
	)
	assert_eq(g.get_pickup(&"kizil_iksir").amount, 25.0)
	var damage := g.get_pickup(&"ofke_barutu")
	assert_eq([damage.buff, damage.mult, damage.duration], [&"damage", 1.5, 12.0])
	var rate := g.get_pickup(&"kizgin_namlu")
	assert_eq([rate.buff, rate.mult, rate.duration], [&"fire_rate", 1.4, 12.0])
	var bomb := g.get_pickup(&"kara_bomba")
	assert_eq(
		[bomb.radius, bomb.fuse, bomb.dmg, bomb.elite_frac, bomb.elite_min],
		[320.0, 0.8, 600.0, 0.08, 600.0]
	)
	var inf := g.get_pickup(&"sonsuz_tambur")
	assert_eq([inf.buff, inf.duration, inf.rarity], [&"unlimited", 10.0, &"rare"])
	assert_eq(g.get_pickup(&"kizil_iksir").toast, "+25 Can")
	assert_eq(g.get_pickup(&"kara_bomba").toast, "")


func test_real_score_data_matches_plan_numbers() -> void:
	var t := GameData.load_dir("res://data").score_table
	var want := {
		&"curumus_piyade": 10,
		&"les_kargasi": 8,
		&"sovalye_hayaleti": 50,
		&"elit_piyade": 400,
		&"elit_sovalye": 1200,
		&"elit_karga": 1500,
		&"kale_lordu": 10000,
	}
	for id in want.keys():
		assert_eq(t.points(id), want[id], String(id))
	assert_eq(t.kill_points.size(), 7)
	assert_eq(
		t.tiers,
		(
			[Vector2i(0, 1), Vector2i(10, 2), Vector2i(25, 3), Vector2i(50, 4), Vector2i(100, 5)]
			as Array[Vector2i]
		)
	)
	assert_eq(
		[t.window_steps, t.evolution_bonus, t.survival_per_sec, t.lord_bonus, t.display_cap],
		[180, 2000, 5, 25000, 99999999]
	)


func test_score_table_mult_for_uses_inclusive_thresholds() -> void:
	var t := GameData.load_dir("res://data").score_table
	var cases := {0: 1, 1: 1, 9: 1, 10: 2, 24: 2, 25: 3, 49: 3, 50: 4, 99: 4, 100: 5, 5000: 5}
	for n in cases.keys():
		assert_eq(t.mult_for(n), cases[n], "seri %d" % n)
	assert_eq(t.points(&"bilinmeyen"), 0)


func test_pickup_unknown_keys_are_rejected() -> void:
	var d := _pickups()
	d["extra"] = 1
	assert_true(_has_code(_pk_errs(d), "unknown_key"), "üst düzey")
	d = _pickups()
	d["spawn"]["extra"] = 1
	assert_true(_has_code(_pk_errs(d), "unknown_key"), "spawn")
	d = _pickups()
	d["kinds"][0]["extra"] = 1
	assert_true(_has_code(_pk_errs(d), "unknown_key"), "tür")


func test_pickup_enums_are_closed_sets() -> void:
	var d := _pickups()
	d["kinds"][0]["effect"] = "teleport"
	assert_true(_has_code(_pk_errs(d), "bad_kind"), "effect")
	d = _pickups()
	d["kinds"][0]["rarity"] = "epic"
	assert_true(_has_code(_pk_errs(d), "bad_kind"), "rarity")
	d = _pickups()
	_kind(d, "ofke_barutu")["buff"] = "shield"
	assert_true(_has_code(_pk_errs(d), "bad_kind"), "buff")


func test_pickup_ids_must_be_unique_in_file() -> void:
	var d := _pickups()
	d["kinds"][1]["id"] = d["kinds"][0]["id"]
	assert_true(_has_code(_pk_errs(d), "dup_id"))


func test_pickup_spawn_ranges() -> void:
	var cases := {
		"first": [50, 40],
		"interval": [60, 45],
		"dist": [700, 450],
	}
	for k in cases.keys():
		var d := _pickups()
		d["spawn"][k] = cases[k]
		assert_true(_has_code(_pk_errs(d), "out_of_range"), "%s min > max" % k)
	var d := _pickups()
	d["spawn"]["life"] = 5
	assert_true(_has_code(_pk_errs(d), "out_of_range"), "life <= blink_last")
	d = _pickups()
	d["spawn"]["blink_last"] = -1
	assert_true(_has_code(_pk_errs(d), "out_of_range"), "blink_last < 0")
	for bad in [0, 501]:
		d = _pickups()
		d["spawn"]["collect_radius"] = bad
		assert_true(_has_code(_pk_errs(d), "out_of_range"), "collect_radius %d" % bad)
	for bad in [0, 9]:
		d = _pickups()
		d["spawn"]["max_alive"] = bad
		assert_true(_has_code(_pk_errs(d), "out_of_range"), "max_alive %d" % bad)
	d = _pickups()
	d["spawn"]["max_alive"] = 1.5
	assert_true(_has_code(_pk_errs(d), "bad_type"), "max_alive tamsayı")
	d = _pickups()
	d["spawn"].erase("dist")
	assert_true(_has_code(_pk_errs(d), "missing_field"))


func test_pickup_weight_sum_must_be_positive() -> void:
	var d := _pickups()
	for k in d["kinds"]:
		k["weight"] = 0
	assert_true(_has_code(_pk_errs(d), "pickup_weight"))
	d = _pickups()
	d["kinds"] = []
	assert_true(_has_code(_pk_errs(d), "pickup_weight"), "boş tür listesi")
	d = _pickups()
	d["kinds"][0]["weight"] = -1
	assert_true(_has_code(_pk_errs(d), "out_of_range"), "negatif ağırlık")


func test_pickup_icon_must_exist() -> void:
	var d := _pickups()
	d["kinds"][0]["icon"] = "res://assets/ui/icons/pickups/yok.svg"
	assert_true(_has_code(_pk_errs(d), "asset_missing"))
	d["kinds"][0]["icon"] = "placeholder:iksir"
	assert_eq(_pk_errs(d), PackedStringArray(), "placeholder kabul edilir")


func test_pickup_effect_specific_required_fields() -> void:
	var cases := {
		"kizil_iksir": ["amount"],
		"ofke_barutu": ["buff", "mult", "duration"],
		"sonsuz_tambur": ["buff", "duration"],
		"kara_bomba": ["radius", "fuse", "dmg"],
	}
	for id in cases.keys():
		for field in cases[id]:
			var d := _pickups()
			_kind(d, id).erase(field)
			assert_true(_has_code(_pk_errs(d), "missing_field"), "%s.%s yok" % [id, field])
	var d := _pickups()
	_kind(d, "sonsuz_tambur").erase("mult")
	assert_eq(_pk_errs(d), PackedStringArray(), "sınırsızda mult gerekmez")
	d = _pickups()
	_kind(d, "cekim_tasi").erase("amount")
	assert_eq(_pk_errs(d), PackedStringArray(), "mıknatıs ek alan istemez")


func test_pickup_bomb_bounds() -> void:
	var d := _pickups()
	_kind(d, "kara_bomba")["dmg"] = 100001
	assert_true(_has_code(_pk_errs(d), "out_of_range"), "dmg > 100000")
	d = _pickups()
	_kind(d, "kara_bomba")["elite_frac"] = 1.5
	assert_true(_has_code(_pk_errs(d), "out_of_range"), "elite_frac > 1")
	d = _pickups()
	_kind(d, "kara_bomba")["radius"] = 0
	assert_true(_has_code(_pk_errs(d), "out_of_range"), "radius 0")
	d = _pickups()
	_kind(d, "kara_bomba")["fuse"] = "0.8"
	assert_true(_has_code(_pk_errs(d), "bad_type"), "fuse metin")


func test_pickup_bad_json_and_non_object_root() -> void:
	var errs := _validate(KitDev.data_dir_with({"pickups.json": "{ bozuk"}))
	assert_true(_has_code(errs, "bad_json"))
	assert_false(_has_code(errs, "not_object"), "bad_json ikinci kez bildirilmez")
	errs = _validate(KitDev.data_dir_with({"pickups.json": "[1]"}))
	assert_true(_has_code(errs, "not_object"))
	errs = _validate(KitDev.data_dir_with({"pickups.json": "null"}))
	assert_true(_has_code(errs, "not_object"), "null kök")


func test_score_kill_points_must_name_known_enemies() -> void:
	var d := _score()
	d["kill_points"]["hayalet_x"] = 5
	assert_true(_has_code(_sc_errs(d), "unknown_enemy"))
	d = _score()
	d["kill_points"].erase("les_kargasi")
	var errs := _sc_errs(d)
	assert_true(_has_code(errs, "missing_field"), "tam modda her düşman için kayıt: %s" % [errs])
	assert_false(
		_has_code(_validate(KitDev.data_dir_with({"score.json": d}), false), "missing_field"),
		"tam mod dışında zorunlu değil"
	)
	d = _score()
	d["kill_points"]["les_kargasi"] = -3
	assert_true(_has_code(_sc_errs(d), "out_of_range"))
	d["kill_points"]["les_kargasi"] = 2.5
	assert_true(_has_code(_sc_errs(d), "bad_type"))


func test_score_tiers_rules() -> void:
	var bad_tiers := {
		"ilk basamak [0,1] değil": [[1, 1], [10, 2]],
		"ilk çarpan 1 değil": [[0, 2], [10, 3]],
		"eşik artmıyor": [[0, 1], [10, 2], [10, 3]],
		"eşik azalıyor": [[0, 1], [25, 2], [10, 3]],
		"çarpan artmıyor": [[0, 1], [10, 3], [25, 3]],
		"çarpan azalıyor": [[0, 1], [10, 3], [25, 2]],
	}
	for why in bad_tiers.keys():
		var d := _score()
		d["streak"]["tiers"] = bad_tiers[why]
		assert_true(_has_code(_sc_errs(d), "score_tiers"), why)
	var d := _score()
	d["streak"]["tiers"] = [[0, 1]]
	assert_eq(_sc_errs(d), PackedStringArray(), "tek basamak geçerli")
	d["streak"]["tiers"] = []
	assert_true(_has_code(_sc_errs(d), "bad_type"), "boş dizi")
	d["streak"]["tiers"] = [[0, 1], [10]]
	assert_true(_has_code(_sc_errs(d), "bad_type"), "eksik çift")
	d["streak"].erase("tiers")
	assert_true(_has_code(_sc_errs(d), "missing_field"))


func test_score_tiers_are_bounded() -> void:
	var d := _score()
	d["streak"]["tiers"] = [[0, 1], [10, 999999999]]
	assert_true(_has_code(_sc_errs(d), "score_tiers"), "çarpan tavanı")
	d["streak"]["tiers"] = [[0, 1], [10000000, 2]]
	assert_true(_has_code(_sc_errs(d), "score_tiers"), "eşik tavanı")
	var many: Array = []
	for i in 21:
		many.append([i * 10, i + 1])
	d["streak"]["tiers"] = many
	assert_true(_has_code(_sc_errs(d), "score_tiers"), "en çok 20 basamak")
	many.resize(20)
	assert_eq(_sc_errs(d), PackedStringArray(), "20 basamak geçerli")


func test_score_numeric_bounds_and_keys() -> void:
	for w in [0.4, 30.5]:
		var d := _score()
		d["streak"]["window"] = w
		assert_true(_has_code(_sc_errs(d), "out_of_range"), "window %s" % w)
	for k in ["evolution_bonus", "survival_per_sec", "lord_bonus"]:
		var d := _score()
		d[k] = 1000001
		assert_true(_has_code(_sc_errs(d), "out_of_range"), k)
		d[k] = -1
		assert_true(_has_code(_sc_errs(d), "out_of_range"), "%s negatif" % k)
	var d := _score()
	d["display_cap"] = 100000000
	assert_true(_has_code(_sc_errs(d), "out_of_range"), "display_cap tavanı")
	d = _score()
	d["bonus"] = 1
	assert_true(_has_code(_sc_errs(d), "unknown_key"))
	d = _score()
	d["streak"]["extra"] = 1
	assert_true(_has_code(_sc_errs(d), "unknown_key"), "streak")
	d = _score()
	d.erase("streak")
	assert_true(_has_code(_sc_errs(d), "missing_field"))


func test_enemy_anim_is_optional_and_defaults_to_none() -> void:
	var g := GameData.load_dir(KitDev.data_dir())
	assert_eq(g.get_enemy(&"elit_piyade").anim, {"kind": "none"}, "anim yok => none")
	assert_eq(g.get_enemy(&"curumus_piyade").anim["kind"], "crawl")
	assert_eq(g.get_enemy(&"curumus_piyade").anim["cycle"], 72.0)
	var real := GameData.load_dir("res://data")
	for id in real.enemy_ids:
		assert_ne(real.get_enemy(id).anim["kind"], "none", "gerçek veride %s animasyonlu" % id)


## `anim` bloğunu yamalar/siler (clear = önce boşalt) ve tam modda doğrular.
func _anim_errs(
	patch: Dictionary = {}, erase: Array = [], clear: bool = false
) -> PackedStringArray:
	var en: Dictionary = KitDev.read_json(FIX + "/data_valid/enemies/curumus_piyade.json")
	var a: Dictionary = en["anim"]
	if clear:
		a.clear()
	for k in patch.keys():
		a[k] = patch[k]
	for k in erase:
		a.erase(k)
	return _validate(KitDev.data_dir_with({"enemies/curumus_piyade.json": en}))


func test_enemy_anim_rules() -> void:
	assert_true(_has_code(_anim_errs({"zip": 1}), "unknown_key"))
	assert_true(_has_code(_anim_errs({"kind": "swim"}), "bad_kind"))
	assert_true(_has_code(_anim_errs({}, ["kind"]), "missing_field"))
	assert_true(_has_code(_anim_errs({"death": "explode"}), "bad_kind"))
	assert_true(_has_code(_anim_errs({"rot": 16}), "out_of_range"), "rot <= 15")
	assert_true(_has_code(_anim_errs({"hz": -1}), "out_of_range"))
	assert_true(_has_code(_anim_errs({"death_ms": 10}), "out_of_range"))
	assert_true(_has_code(_anim_errs({"bob": "5"}), "bad_type"))
	assert_true(_has_code(_anim_errs({"alpha": [1]}), "bad_type"))
	assert_true(_has_code(_anim_errs({"alpha": [0.5, 1.5]}), "out_of_range"))
	assert_eq(_anim_errs({"kind": "none"}), PackedStringArray(), "none geçerli")
	assert_eq(_anim_errs({"kind": "float"}, [], true), PackedStringArray(), "yalnız kind yeterli")
	var en: Dictionary = KitDev.read_json(FIX + "/data_valid/enemies/curumus_piyade.json")
	en["anim"] = "crawl"
	assert_true(
		_has_code(_validate(KitDev.data_dir_with({"enemies/curumus_piyade.json": en})), "bad_type")
	)


## rig.walk'ı yamalar; frame_mode > 0 ise önce o kare sayısıyla geçerli kare modu tabanını kurar.
func _walk_errs(
	patch: Dictionary = {}, erase: Array = [], frame_mode: int = 0
) -> PackedStringArray:
	var ch: Dictionary = KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json")
	var w: Dictionary = ch["rig"]["walk"]
	if frame_mode > 0:
		w["frames"] = frame_mode
		w["strip"] = "res://assets/gfx/char/gunslinger_body.png"
		w["cell"] = [177, 320]
	for k in patch.keys():
		w[k] = patch[k]
	for k in erase:
		w.erase(k)
	return _validate(KitDev.data_dir_with({"characters/gunslinger.json": ch}))


func test_rig_walk_defaults_to_procedural_fallback() -> void:
	var g := GameData.load_dir(KitDev.data_dir())
	assert_eq(g.get_character(&"gunslinger").walk["frames"], 0.0)
	assert_eq(g.get_character(&"gunslinger").walk["stride"], 136.0)
	assert_eq(_walk_errs(), PackedStringArray(), "frames 0 geçerli (şerit dosyası olmasa da)")
	var ch: Dictionary = KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json")
	ch["rig"].erase("walk")
	var g2 := GameData.load_dir(KitDev.data_dir_with({"characters/gunslinger.json": ch}))
	assert_eq(g2.validate({}, true), PackedStringArray(), "walk isteğe bağlı")
	assert_eq(g2.get_character(&"gunslinger").walk, {"frames": 0})


func test_rig_walk_frame_mode_rules() -> void:
	for n in [2, 6, 7, 12]:
		assert_eq(_walk_errs({}, [], n), PackedStringArray(), "frames %d" % n)
	for n in [1, 13, -1]:
		assert_true(_has_code(_walk_errs({"frames": n}, [], 6), "out_of_range"), "frames %d" % n)
	assert_true(_has_code(_walk_errs({"frames": 6.5}), "bad_type"), "tamsayı olmalı")
	assert_true(_has_code(_walk_errs({"stride": 10}), "out_of_range"))
	assert_true(_has_code(_walk_errs({"stride": 601}), "out_of_range"))
	assert_true(_has_code(_walk_errs({}, ["frames"]), "missing_field"))
	assert_true(_has_code(_walk_errs({"kare": 1}), "unknown_key"))
	var missing := {"strip": "res://assets/gfx/char/yok.png"}
	assert_true(_has_code(_walk_errs(missing, [], 6), "asset_missing"))
	assert_true(_has_code(_walk_errs({}, ["strip"], 6), "missing_field"))
	assert_true(_has_code(_walk_errs({}, ["cell"], 6), "missing_field"))
	assert_true(_has_code(_walk_errs({"cell": [0, 320]}, [], 6), "bad_type"))
	assert_true(_has_code(_walk_errs({"cell": [177]}, [], 6), "bad_type"))


func test_rig_walk_shoulder_dev_rules() -> void:
	var dev7: Array = []
	for i in 7:
		dev7.append([0.01 * i, -0.02])
	assert_eq(_walk_errs({"shoulder_dev": dev7}, [], 6), PackedStringArray(), "frames+1 eleman")
	var short := dev7.slice(0, 6)
	assert_true(
		_has_code(_walk_errs({"shoulder_dev": short}, [], 6), "out_of_range"), "frames kadar yetmez"
	)
	var far := dev7.duplicate(true)
	far[3] = [0.3, 0.0]
	assert_true(_has_code(_walk_errs({"shoulder_dev": far}, [], 6), "out_of_range"), "±0,2 dışı")
	assert_true(_has_code(_walk_errs({"shoulder_dev": "x"}), "bad_type"))
	assert_true(_has_code(_walk_errs({"shoulder_dev": [[0, 0, 0]]}, [], 6), "out_of_range"))
	assert_eq(_walk_errs({"shoulder_dev": []}, [], 6), PackedStringArray(), "boş geçerli")
