extends GutTest
## RunCatalog iskeleti (sözleşme-B): sentetik 0/1/3 mod/zorluk, validate() ve build_profile. Tüketici dönüşümü R7'dedir.


func _cat(nm: int, nd: int) -> RunCatalog:
	return RunCatalog.from_dicts(CatalogFixtures.modes(nm), CatalogFixtures.difficulties(nd))


func test_zero_entries_is_invalid_but_safe() -> void:
	var c := _cat(0, 0)
	assert_eq(c.mode_ids().size(), 0)
	assert_eq(c.difficulty_ids().size(), 0)
	assert_eq(c.default_mode(), "")
	assert_eq(c.default_difficulty(), "")
	assert_eq(c.validate().size(), 2)
	assert_string_contains(c.validate()[0], "RUN_CATALOG: ")


func test_one_entry_is_valid_and_default() -> void:
	var c := _cat(1, 1)
	assert_eq(c.validate().size(), 0, str(c.validate()))
	assert_eq(c.default_mode(), "zz_m0")
	assert_eq(c.default_difficulty(), "zz_d0")


func test_three_entries_sorted_by_order_then_id() -> void:
	var modes := CatalogFixtures.modes(3)
	modes[0]["order"] = 3
	modes[2]["order"] = 1
	var c := RunCatalog.from_dicts(modes, CatalogFixtures.difficulties(3))
	assert_eq(c.mode_ids(), PackedStringArray(["zz_m2", "zz_m1", "zz_m0"]))
	assert_eq(c.difficulty_ids(), PackedStringArray(["zz_d0", "zz_d1", "zz_d2"]))
	assert_eq(c.validate().size(), 0)


func test_explicit_default_flag_wins() -> void:
	var modes := CatalogFixtures.modes(3)
	modes[1]["default"] = true
	assert_eq(RunCatalog.from_dicts(modes, CatalogFixtures.difficulties(1)).default_mode(), "zz_m1")


func test_unknown_ids_return_empty_without_error() -> void:
	var c := _cat(1, 1)
	assert_eq(c.mode("yok"), {})
	assert_eq(c.difficulty("yok"), {})
	assert_null(c.build_profile("yok", "zz_d0"))
	assert_null(c.build_profile("zz_m0", "yok"))


func test_validate_reports_each_problem_deterministically() -> void:
	var modes := CatalogFixtures.modes(3)
	modes[0]["ending"] = "yok_tur"
	modes[1]["id"] = "zz_m0"  # yinelenen kimlik
	modes[2]["name"] = ""
	var c := RunCatalog.from_dicts(modes, CatalogFixtures.difficulties(1))
	var errs := c.validate()
	assert_eq(errs, RunCatalog.from_dicts(modes, CatalogFixtures.difficulties(1)).validate())
	var joined := "\n".join(errs)
	assert_string_contains(joined, "RUN_CATALOG: zz_m0: bitiş türü 'yok_tur' bilinmiyor")
	assert_string_contains(joined, "RUN_CATALOG: zz_m0: yinelenen kimlik")
	assert_string_contains(joined, "RUN_CATALOG: zz_m2: ad boş")


func test_validate_flags_missing_difficulty_values() -> void:
	var diffs := CatalogFixtures.difficulties(1)
	diffs[0]["values"] = {}
	assert_string_contains("\n".join(_cat_with(diffs).validate()), "RUN_CATALOG: zz_d0: values boş")


func _cat_with(diffs: Array) -> RunCatalog:
	return RunCatalog.from_dicts(CatalogFixtures.modes(1), diffs)


func test_ending_kinds_is_closed_set() -> void:
	assert_eq(_cat(1, 1).ending_kinds(), PackedStringArray(["lord", "endless"]))


func test_build_profile_combines_mode_and_difficulty() -> void:
	var modes := CatalogFixtures.modes(1)
	modes[0]["profile"]["time_scale"] = 0.5
	modes[0]["ending"] = "endless"
	var diffs := CatalogFixtures.difficulties(1)
	diffs[0]["values"]["enemy_hp"] = 0.7
	var p := RunCatalog.from_dicts(modes, diffs).build_profile("zz_m0", "zz_d0")
	assert_not_null(p)
	assert_eq(p.mode, &"zz_m0")
	assert_eq(p.diff, &"zz_d0")
	assert_eq(p.end_mode, "endless")
	assert_almost_eq(p.time_scale, 0.5, 0.0001)
	assert_almost_eq(p.enemy_hp, 0.7, 0.0001)


func test_default_catalog_matches_run_profiles_json() -> void:
	var c := RunCatalog.default()
	assert_eq(c.validate().size(), 0, str(c.validate()))
	for id in RunProfiles.MODES:
		assert_true(c.mode_ids().has(id), id)
	for id in RunProfiles.DIFFS:
		assert_true(c.difficulty_ids().has(id), id)
	var raw: Dictionary = RunProfiles.load_default()["profiles"]
	assert_eq(c.default_mode(), str(raw["default"]["mode"]))
	assert_eq(c.default_difficulty(), str(raw["default"]["diff"]))
	var legacy := c.build_profile("normal", "hard")
	assert_true(legacy.is_legacy(), "Normal+Zor bugünkü oyundur")
