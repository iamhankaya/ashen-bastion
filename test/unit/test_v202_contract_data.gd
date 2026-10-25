extends GutTest
## S1 sözleşmesi: DataV202Pool / DataV202Rig doğrulayıcıları (şema şekli: kodlar ve bağlam; iş mantığı yok).
## Fixture'lar test/fixtures/pool_bad_*, rig_bad_* (data_valid üstüne bindirilir; yeni hata kodu YOK).

const FIX := "res://test/fixtures"
const POOL_CASES := {
	"unknown_pool": "unknown_ref",
	"pool_type": "bad_type",
	"variants_special": "unknown_key",
	"variant_char": "unknown_ref",
	"variant_name": "out_of_range",
	"variant_desc": "out_of_range",
	"variants_type": "bad_type",
	"evo_pool": "requires_ref",
	"starting": "requires_ref",
}
const RIG_CASES := {
	"cast_point_range": "out_of_range",
	"cast_point_missing": "missing_field",
	"fire_frame": "out_of_range",
	"cast_frames": "out_of_range",
	"cast_fps": "out_of_range",
	"gather_frames": "out_of_range",
	"no_strip": "missing_field",
	"strip_width": "out_of_range",
	"action_type": "bad_type",
	"walk_cast_fire": "out_of_range",
	"cast_key": "unknown_key",
}


func after_each() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(KitDev.TMP_ROOT)):
		KitDev.remove_tmp()


func _errs(dir: String) -> PackedStringArray:
	return GameData.load_dir(dir).validate()


func _has(errs: PackedStringArray, code: String) -> bool:
	for e in errs:
		if e.begins_with("[%s]" % code):
			return true
	return false


func _zyfen_overlay() -> Dictionary:
	return KitDev.read_json(FIX + "/rig_bad_cast_key/characters/zyfen.json")


func test_valid_fixture_data_has_no_errors() -> void:
	assert_eq(_errs(KitDev.data_dir()), PackedStringArray())


func test_pool_bad_fixtures_report_their_code() -> void:
	for k in POOL_CASES:
		var errs := _errs(KitDev.data_dir("%s/pool_bad_%s" % [FIX, k]))
		assert_true(
			_has(errs, POOL_CASES[k]),
			"pool_bad_%s: [%s] bekleniyordu: %s" % [k, POOL_CASES[k], errs]
		)


func test_rig_bad_fixtures_report_their_code() -> void:
	for k in RIG_CASES:
		var errs := _errs(KitDev.data_dir("%s/rig_bad_%s" % [FIX, k]))
		assert_true(
			_has(errs, RIG_CASES[k]), "rig_bad_%s: [%s] bekleniyordu: %s" % [k, RIG_CASES[k], errs]
		)


func test_every_pool_and_rig_fixture_dir_is_in_the_tables() -> void:
	for d in DirAccess.get_directories_at(FIX):
		if d.begins_with("pool_bad_"):
			assert_true(POOL_CASES.has(d.trim_prefix("pool_bad_")), d)
		if d.begins_with("rig_bad_"):
			assert_true(RIG_CASES.has(d.trim_prefix("rig_bad_")), d)


func test_armless_with_walk_frames_zero_cast_gather_and_walk_cast_passes() -> void:
	var z := _zyfen_overlay()
	z["rig"]["cast"] = {"frames": 6, "fire_frame": 3, "fps": 24}
	z["rig"]["walk_cast"] = {"frames": 4, "fire_frame": 1, "fps": 24}
	var errs := _errs(KitDev.data_dir_with({"characters/zyfen.json": z}))
	assert_eq(errs, PackedStringArray())


func test_armless_arm_fields_are_ignored_not_required() -> void:
	var z := _zyfen_overlay()
	z["rig"].erase("cast")
	z["rig"].erase("gather")
	assert_eq(
		_errs(KitDev.data_dir_with({"characters/zyfen.json": z})),
		PackedStringArray(),
		"kol alanı yok"
	)
	z["rig"]["arm"] = "olmayan_dosya"
	z["rig"]["muzzle"] = "bozuk"
	z["rig"]["arm_scale"] = 99
	assert_eq(
		_errs(KitDev.data_dir_with({"characters/zyfen.json": z})),
		PackedStringArray(),
		"verilirse yok sayılır"
	)


func test_armed_rig_still_requires_arm_fields_and_rejects_new_keys() -> void:
	var g: Dictionary = KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json")
	g["rig"].erase("arm_pivot")
	assert_true(
		_has(_errs(KitDev.data_dir_with({"characters/gunslinger.json": g})), "missing_field")
	)
	g = KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json")
	g["rig"]["cast_point"] = [0.3, 0.0]
	assert_true(_has(_errs(KitDev.data_dir_with({"characters/gunslinger.json": g})), "unknown_key"))


func test_valid_variant_and_pool_pass() -> void:
	var hd: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/hizli_doldurma.json")
	hd["variants"] = {"gunslinger": {"name": "Çabuk Toplayış", "desc": ["a", "b", "c", "d", "e"]}}
	hd["max_level"] = (hd["levels"] as Array).size()
	hd["variants"]["gunslinger"]["desc"] = (hd["desc"] as Array).duplicate()
	assert_eq(_errs(KitDev.data_dir_with({"skills/hizli_doldurma.json": hd})), PackedStringArray())
	var sm: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/seken_mermi.json")
	sm["pool"] = "gunslinger"
	var ev: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/zincirleme_patlama.json")
	ev["pool"] = "gunslinger"
	var errs := _errs(
		KitDev.data_dir_with({"skills/seken_mermi.json": sm, "skills/zincirleme_patlama.json": ev})
	)
	assert_eq(errs, PackedStringArray(), "evrim ve etkin aktifi aynı havuzda")


func test_wind_time_mult_passive_key_and_bounds() -> void:
	assert_true(GameData.PASSIVE_KEYS.has("wind_time_mult"))
	assert_eq(GameData.PASSIVE_BOUNDS["wind_time_mult"], [-0.9, 5.0])
	var p: Dictionary = KitDev.read_json(FIX + "/data_valid/skills/hizli_doldurma.json")
	p["levels"] = (p["levels"] as Array).map(
		func(_l: Variant) -> Dictionary: return {"wind_time_mult": 9.0}
	)
	assert_true(
		_has(_errs(KitDev.data_dir_with({"skills/hizli_doldurma.json": p})), "out_of_range")
	)


func test_real_data_is_valid_and_zyfen_skills_are_zyfen_pool() -> void:
	var g := GameData.load_default()
	assert_eq(g.validate(), PackedStringArray())
	for id in ["ruzgar_kesigi", "girdap", "tufan", "furtina_gozu"]:
		assert_eq(g.get_skill(StringName(id)).pool, &"zyfen", id)
