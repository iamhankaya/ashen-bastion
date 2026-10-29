extends GutTest
## R7: yeni mod / zorluk yalnız veri dosyasıyla eklenir (kod değişmez). Yeni BİTİŞ TÜRÜ kabulden ayrıdır: kod gerektirir.
## Geçici veri kökü gerçek data/run_modes + data/difficulties + run_profiles.json kopyasıdır; üstüne sahte zz_* dosyası yazılır.

const TMP_DIR := "user://catalog_mode_fixture"
const PROFILE := {"time_scale": 0.8, "xp_mult": 1.0, "lord_hp_mult": 1.0, "rate_mult": 1.0}

var _dir := ""


func before_each() -> void:
	_dir = "%s_%d" % [TMP_DIR, OS.get_process_id()]
	_rm_rf(ProjectSettings.globalize_path(_dir))
	for sub in ["run_modes", "difficulties"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir).path_join(sub))
		for f in DirAccess.get_files_at("res://data/" + sub):
			_write("%s/%s" % [sub, f], FileAccess.get_file_as_string("res://data/%s/%s" % [sub, f]))
	_write("run_profiles.json", FileAccess.get_file_as_string("res://data/run_profiles.json"))


func after_each() -> void:
	_rm_rf(ProjectSettings.globalize_path(_dir))
	AchKit.cleanup()


func _write(rel: String, text: String) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(_dir).path_join(rel), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _mode(id: String, ending: String = "lord") -> Dictionary:
	return {
		"id": id,
		"order": 9,
		"name": "ZZ Mod",
		"label": "ZZ MOD",
		"description": "ZZ açıklama.",
		"ending": ending,
		"icon_key": "zz",
		"profile": PROFILE.duplicate()
	}


func _diff(id: String) -> Dictionary:
	return {
		"id": id,
		"order": 9,
		"name": "ZZ Zorluk",
		"label": "ZZ ZORLUK",
		"description": "ZZ açıklama.",
		"spoken": "zz açıklama",
		"shields": 3,
		"values":
		{"enemy_hp": 1.0, "enemy_dmg": 1.0, "spawn_density": 1.0, "xp": 1.0, "lord_hp": 1.0},
		"achievements": {"block_lord_bound": false, "totals": "all"}
	}


func test_shipped_catalog_dirs_load_clean() -> void:
	var c := RunCatalog.load_dir(_dir)
	assert_eq(c.validate().size(), 0, str(c.validate()))
	assert_eq(c.mode_ids(), PackedStringArray(["quick", "normal", "endless"]))
	assert_eq(c.difficulty_ids(), PackedStringArray(["easy", "normal", "hard"]))
	assert_eq(c.default_mode(), "normal")
	assert_eq(c.default_difficulty(), "normal")


func test_new_mode_file_is_a_mode_without_code_changes() -> void:
	_write("run_modes/zz_turbo.json", JSON.stringify(_mode("zz_turbo")))
	var c := RunCatalog.load_dir(_dir)
	assert_eq(c.validate().size(), 0, str(c.validate()))
	assert_true(c.mode_ids().has("zz_turbo"))
	var p := c.build_profile("zz_turbo", "normal")
	assert_not_null(p)
	assert_almost_eq(p.time_scale, 0.8, 0.0001)
	assert_eq(c.default_mode(), "normal", "yeni mod varsayılanı değiştirmez")


func test_new_mode_passes_profile_validation_and_keeps_defaults() -> void:
	_write("run_modes/zz_turbo.json", JSON.stringify(_mode("zz_turbo")))
	var loaded := RunProfiles.load_dir(_dir)
	assert_eq(loaded["errors"], [], "yeni mod geçerli")
	var profiles: Dictionary = loaded["profiles"]
	assert_true((profiles["modes"] as Dictionary).has("zz_turbo"))
	assert_eq(RunProfiles.default_selection(profiles)["mode"], &"normal")


func test_new_difficulty_file_carries_its_own_achievement_rule() -> void:
	_write("difficulties/zz_hell.json", JSON.stringify(_diff("zz_hell")))
	var loaded := RunProfiles.load_dir(_dir)
	assert_eq(loaded["errors"], [], "yeni zorluk geçerli (başarım kuralı kendi dosyasında)")
	var rules := AchievementRules.new(loaded["profiles"])
	assert_true(rules.counts_total(&"kills", &"zz_hell"))
	assert_true(rules.allows("lordslayer:1", &"zz_hell"))
	assert_false(rules.allows("lordslayer:1", &"easy"), "yerleşik kural korunur")


func test_new_ending_kind_is_not_data_only() -> void:
	_write("run_modes/zz_orbit.json", JSON.stringify(_mode("zz_orbit", "orbit")))
	var errs := "\n".join(RunCatalog.load_dir(_dir).validate())
	assert_string_contains(errs, "RUN_CATALOG: zz_orbit: bitiş türü 'orbit' bilinmiyor")


func test_file_name_must_match_id_and_bad_json_is_reported() -> void:
	_write("run_modes/zz_a.json", JSON.stringify(_mode("zz_b")))
	_write("run_modes/zz_c.json", "{ bozuk")
	var errs := "\n".join(RunCatalog.load_dir(_dir).validate())
	assert_string_contains(
		errs, "RUN_CATALOG: run_modes/zz_a.json: kimlik dosya adıyla aynı olmalı"
	)
	assert_string_contains(errs, "RUN_CATALOG: run_modes/zz_c.json: JSON ayrıştırılamadı")


func test_highscores_accept_catalog_modes_only() -> void:
	_write("run_modes/zz_turbo.json", JSON.stringify(_mode("zz_turbo")))
	var entry := {"mode": "zz_turbo", "diff": "normal", "score": 500}
	var stock := Highscores.new(AchKit.tmp_path("catdef"))
	assert_eq(stock.submit(entry).get("error"), "mode_diff_unknown", "varsayılan katalog bilmez")
	var hs := Highscores.new(AchKit.tmp_path("catfake"))
	hs.catalog = RunCatalog.load_dir(_dir)
	assert_false(hs.submit(entry).has("error"))
	assert_eq(hs.list_for(&"zz_turbo", &"normal").size(), 1)


func test_settings_accept_catalog_modes_only() -> void:
	_write("run_modes/zz_turbo.json", JSON.stringify(_mode("zz_turbo")))
	var path := AchKit.tmp_path("catset")
	AchKit.write_text(path, JSON.stringify({"kosu_modu": "zz_turbo", "kosu_zorluk": "easy"}))
	var st: Node = load("res://scripts/autoload/settings.gd").new()
	st.load_settings(path)
	assert_eq(st.run_mode, "normal", "varsayılan katalog bilmeyen modu düşürür")
	assert_eq(st.run_diff, "easy")
	st.catalog = RunCatalog.load_dir(_dir)
	st.load_settings(path)
	assert_eq(st.run_mode, "zz_turbo")
	st.free()


func test_game_data_validate_reports_catalog_errors_via_plugin() -> void:
	_write("run_modes/zz_orbit.json", JSON.stringify(_mode("zz_orbit", "orbit")))
	var joined := "\n".join(GameData.load_dir(_dir).validate())
	assert_string_contains(joined, "RUN_CATALOG: zz_orbit: bitiş türü 'orbit' bilinmiyor")


func test_plugin_is_silent_without_catalog_dirs() -> void:
	var g := GameData.new()
	var out := PackedStringArray()
	RunCatalogValidator.new().run(g, out, false)
	assert_eq(out.size(), 0, "kök yok")
	g.root_dir = "res://test/fixtures"
	RunCatalogValidator.new().run(g, out, false)
	assert_eq(out.size(), 0, "run_modes/ yok: eski fixture kökleri etkilenmez")


static func _rm_rf(abs_dir: String) -> void:
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for sub in DirAccess.get_directories_at(abs_dir):
		_rm_rf(abs_dir.path_join(sub))
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)
