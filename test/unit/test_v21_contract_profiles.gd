extends GutTest
## v2.1 C sözleşmesi: data/run_profiles.json şeması ve alan bazlı doğrulayıcı (plan K-C4). Şekil testleri; iş mantığı yok.
## Ad öneki `test_contract_` bilerek: dilimsizdir (check_slices yalnız test_<m|s|k|a|b><N>_ adlarını dilime sayar).

const FIX := "res://test/fixtures"
## [yol, alt, üst]: sınır değerler geçerli, hemen dışı profile_range.
const BOUNDS: Array = [
	["modes.quick.time_scale", 0.25, 4.0],
	["modes.quick.xp_mult", 1.0, 5.0],
	["modes.quick.lord_hp_mult", 0.1, 5.0],
	["modes.quick.rate_mult", 0.25, 4.0],
	["modes.endless.lord_repeat_sec", 60.0, 1800.0],
	["modes.endless.lord_repeat_hp_mult", 1.0, 5.0],
	["modes.endless.lord_hp_cap_mult", 1.0, 20.0],
	["modes.endless.enrage_after_sec", 1200.0, 7200.0],
	["modes.endless.enrage_dmg_per_min", 0.0, 1.0],
	["difficulties.easy.enemy_hp", 0.1, 5.0],
	["difficulties.easy.enemy_dmg", 0.1, 5.0],
	["difficulties.easy.spawn_density", 0.1, 5.0],
	["difficulties.easy.xp", 1.0, 5.0],
	["difficulties.easy.lord_hp", 0.1, 5.0],
]


static func _codes(errs: PackedStringArray) -> Array:
	var out: Array = []
	for e in errs:
		out.append(e.substr(1, e.find("]") - 1))
	return out


func _check(d: Dictionary, code: String, what: String) -> void:
	var errs := RunProfiles.validate(d)
	assert_true(_codes(errs).has(code), "%s: [%s] bekleniyordu, gelen: %s" % [what, code, errs])


func test_contract_default_file_is_valid() -> void:
	var res := RunProfiles.load_default()
	assert_eq(res["errors"], [], "data/run_profiles.json geçerli olmalı")
	assert_false((res["profiles"] as Dictionary).is_empty())


func test_contract_default_selection_is_normal_normal() -> void:
	var sel := RunProfiles.default_selection(V21Kit.cfg())
	assert_eq(sel["mode"], &"normal")
	assert_eq(sel["diff"], &"normal")


func test_contract_file_has_the_planned_modes_and_difficulties() -> void:
	var c := V21Kit.cfg()
	assert_eq(c["v"], 1.0)
	assert_eq((c["modes"] as Dictionary).keys(), ["quick", "normal", "endless"])
	assert_eq((c["difficulties"] as Dictionary).keys(), ["easy", "normal", "hard"])
	assert_eq(c["modes"]["quick"]["time_scale"], 0.5)
	assert_eq(c["modes"]["endless"]["end_mode"], "endless")
	for name in ["quick", "normal"]:
		assert_eq(c["modes"][name]["end_mode"], "lord")
		assert_false(
			(c["modes"][name] as Dictionary).has("lord_repeat_sec"),
			"Sonsuz alanı yalnız endless'te"
		)
	assert_eq(c["difficulties"]["hard"]["enemy_hp"], 1.0, "Zor = bugünkü eğri")
	assert_eq(c["difficulties"]["hard"]["lord_hp"], 1.0)


func test_contract_missing_file_is_an_error_not_a_builtin_default() -> void:
	var res := RunProfiles.load_file("res://data/yok_boyle_run_profiles.json")
	assert_true(str(res["errors"][0]).begins_with("[profile_file_missing]"), str(res["errors"]))
	assert_true((res["profiles"] as Dictionary).is_empty(), "yerleşik varsayılan YOK")


func test_contract_error_line_format_is_code_context_message() -> void:
	var errs := RunProfiles.validate(V21Kit.mutated(V21Kit.cfg(), "modes.quick.time_scale", 9.0))
	var rx := RegEx.create_from_string("^\\[[a-z_]+\\] [^:]+: .+")
	assert_eq(errs.size(), 1, str(errs))
	assert_not_null(rx.search(errs[0]), errs[0])


func test_contract_every_error_code_has_a_fixture_that_reports_it() -> void:
	for code in RunProfiles.ERROR_CODES:
		var name := "profile_bad_%s" % code.trim_prefix("profile_")
		var dir := "%s/%s" % [FIX, name]
		assert_true(DirAccess.get_directories_at(FIX).has(name), "%s eksik" % dir)
		var res := RunProfiles.load_file(dir + "/run_profiles.json")
		assert_true(
			_codes(PackedStringArray(res["errors"])).has(code), "%s: %s" % [dir, res["errors"]]
		)
		assert_true((res["profiles"] as Dictionary).is_empty(), "hatalı dosyadan profil dönmez")


func test_contract_every_profile_fixture_dir_is_a_known_code() -> void:
	var seen := 0
	for d in DirAccess.get_directories_at(FIX):
		if d.begins_with("profile_bad_"):
			seen += 1
			assert_true(RunProfiles.ERROR_CODES.has("profile_" + d.trim_prefix("profile_bad_")), d)
	assert_eq(seen, RunProfiles.ERROR_CODES.size())


func test_contract_bounds_are_inclusive_and_just_outside_is_a_range_error() -> void:
	var base := V21Kit.cfg()
	for row: Array in BOUNDS:
		var path: String = row[0]
		var lo: float = row[1]
		var hi: float = row[2]
		assert_eq(
			RunProfiles.validate(V21Kit.mutated(base, path, lo)),
			PackedStringArray(),
			"%s alt sınır" % path
		)
		assert_eq(
			RunProfiles.validate(V21Kit.mutated(base, path, hi)),
			PackedStringArray(),
			"%s üst sınır" % path
		)
		_check(
			V21Kit.mutated(base, path, lo - maxf(lo * 0.01, 0.01)),
			"profile_range",
			path + " alt-dışı"
		)
		_check(V21Kit.mutated(base, path, hi * 1.01), "profile_range", path + " üst-dışı")


func test_contract_type_errors() -> void:
	var base := V21Kit.cfg()
	_check(
		V21Kit.mutated(base, "modes.quick.time_scale", "0.5"), "profile_type", "sayı yerine dizge"
	)
	_check(V21Kit.mutated(base, "modes.quick.end_mode", 3), "profile_type", "end_mode dizge değil")
	_check(
		V21Kit.mutated(base, "achievements.easy.block_lord_bound", "evet"),
		"profile_type",
		"bool değil"
	)
	_check(
		V21Kit.mutated(base, "achievements.lord_bound_tier_ids", "endure:4"),
		"profile_type",
		"dizi değil"
	)
	_check(V21Kit.mutated(base, "default", "normal"), "profile_type", "default nesne değil")
	_check(V21Kit.mutated(base, "modes", [1]), "profile_type", "modes nesne değil")
	assert_true(_codes(RunProfiles.validate([1, 2])).has("profile_type"), "kök dizi")
	assert_true(_codes(RunProfiles.validate("x")).has("profile_type"), "kök dizge")


func test_contract_missing_and_unknown_keys() -> void:
	var base := V21Kit.cfg()
	_check(
		V21Kit.mutated(base, "difficulties.easy.xp", null), "profile_missing_key", "zorluk alanı"
	)
	_check(V21Kit.mutated(base, "modes.quick.rate_mult", null), "profile_missing_key", "mod alanı")
	_check(V21Kit.mutated(base, "modes.quick.end_mode", null), "profile_missing_key", "end_mode")
	_check(V21Kit.mutated(base, "default", null), "profile_missing_key", "default")
	_check(V21Kit.mutated(base, "modes.quick", null), "profile_missing_key", "mod yok")
	_check(V21Kit.mutated(base, "v", null), "profile_missing_key", "v")
	_check(
		V21Kit.mutated(base, "achievements.hard.totals", null),
		"profile_missing_key",
		"başarım alanı"
	)
	_check(V21Kit.mutated(base, "bogus", 1), "profile_unknown_key", "kök")
	_check(V21Kit.mutated(base, "modes.quick.bogus", 1), "profile_unknown_key", "mod")
	_check(V21Kit.mutated(base, "difficulties.easy.bogus", 1), "profile_unknown_key", "zorluk")
	_check(
		V21Kit.mutated(base, "modes.turbo", base["modes"]["quick"]),
		"profile_unknown_key",
		"bilinmeyen mod adı"
	)
	_check(V21Kit.mutated(base, "achievements.easy.bogus", 1), "profile_unknown_key", "başarım")


func test_contract_default_must_name_defined_entries() -> void:
	var base := V21Kit.cfg()
	_check(V21Kit.mutated(base, "default.mode", "turbo"), "profile_default", "mod")
	_check(V21Kit.mutated(base, "default.diff", "efsane"), "profile_default", "zorluk")


func test_contract_cross_rules() -> void:
	var base := V21Kit.cfg()
	_check(
		V21Kit.mutated(base, "modes.quick.end_mode", "turbo"), "profile_cross", "end_mode değeri"
	)
	_check(
		V21Kit.mutated(base, "modes.quick.lord_repeat_sec", 300),
		"profile_cross",
		"lord modunda Sonsuz alanı"
	)
	_check(
		V21Kit.mutated(base, "modes.normal.enrage_dmg_per_min", 0.1),
		"profile_cross",
		"lord modunda enrage"
	)
	for key in RunProfiles.ENDLESS_FIELDS:
		_check(
			V21Kit.mutated(base, "modes.endless." + key, null),
			"profile_cross",
			"Sonsuz'da %s zorunlu" % key
		)
	_check(
		V21Kit.mutated(base, "achievements.easy", null),
		"profile_cross",
		"zorluk için başarım kuralı yok"
	)


func test_contract_achievement_value_checks() -> void:
	var base := V21Kit.cfg()
	_check(
		V21Kit.mutated(base, "achievements.easy.totals", "bazıları"),
		"profile_range",
		"totals değeri"
	)
	_check(
		V21Kit.mutated(base, "achievements.lord_bound_tier_ids", ["Endure-4"]),
		"profile_range",
		"kimlik biçimi"
	)
	_check(
		V21Kit.mutated(base, "achievements.lord_bound_tier_ids", [4]),
		"profile_type",
		"kimlik dizge değil"
	)
	_check(V21Kit.mutated(base, "v", 2), "profile_range", "sürüm")


func test_contract_lord_bound_tier_ids_name_real_tiers_with_the_planned_thresholds() -> void:
	var ids: Array = V21Kit.cfg()["achievements"]["lord_bound_tier_ids"]
	assert_eq(ids, ["lordslayer:1", "lordslayer:2", "lordslayer:3", "endure:4", "ascension:3"])
	var data := GameData.load_default()
	var want := {"endure:4": 1200, "ascension:3": 4}
	for id: String in ids:
		var parts := id.split(":")
		var def := data.get_achievement(StringName(parts[0]))
		assert_not_null(def, "%s: aile yok" % id)
		var step := int(parts[1])
		assert_lte(step, def.thresholds().size(), "%s: kademe yok" % id)
		if want.has(id):
			assert_eq(def.thresholds()[step - 1], want[id], "%s eşiği" % id)
	assert_eq(
		data.get_achievement(&"lordslayer").thresholds().size(), 3, "lordslayer'ın tüm kademeleri"
	)


func test_contract_validator_does_not_touch_game_data() -> void:
	# R7: GameData.validate katalogu RunCatalogValidator eklentisiyle denetler (kökte run_modes/ varsa); data_bad_* kökleri görmez. Geçerli veri temiz kalır.
	assert_eq(GameData.load_default().validate({}, false), PackedStringArray())
