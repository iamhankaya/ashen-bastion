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
