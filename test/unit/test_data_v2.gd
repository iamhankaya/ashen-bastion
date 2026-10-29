extends GutTest
## v2.0 veri sözleşmesi (S1): achievements.json, karakter alanları, Barutçu, atlas_cells. Beklenen tablo plan metninden.

const FIX := "res://test/fixtures"
const REAL := "res://data"
## id -> [stat, target, tier] (docs/plan/v2.0-plan.md "22 başarım")
const TABLE := {
	"ilk_kan": ["total_kills", 1, "kolay"],
	"bes_dakika": ["run_time", 300, "kolay"],
	"seviye_10": ["run_level", 10, "kolay"],
	"yerlesik": ["total_runs", 10, "kolay"],
	"tambur_ustasi": ["run_reloads", 100, "kolay"],
	"alti_silah": ["run_active_slots", 6, "kolay"],
	"kirim": ["run_kills", 500, "orta"],
	"on_dakika": ["run_time", 600, "orta"],
	"seri_ustasi": ["run_best_mult", 5, "orta"],
	"piyade_avcisi": ["run_elit_piyade", 1, "orta"],
	"eklenti_avcisi": ["run_pickups", 5, "orta"],
	"dokunulmaz": ["run_clean_secs", 180, "orta"],
	"seviye_20": ["run_level", 20, "orta"],
	"kalabalik_kesici": ["total_kills", 10000, "orta"],
	"cifte_yol": ["total_chars5", 2, "orta"],
	"on_bes_dakika": ["run_time", 900, "zor"],
	"uc_elit": ["run_elite_kinds", 3, "zor"],
	"ilk_evrim": ["run_evolutions", 1, "zor"],
	"skor_100k": ["run_score", 100000, "zor"],
	"sinirsiz_kirim": ["run_unlimited_kills", 100, "zor"],
	"kale_lordu_devrildi": ["run_won", 1, "cok_zor"],
	"bomba_ustasi": ["run_bomb_hits", 20, "cok_zor"],
}
## char_bad_<durum> -> beklenen hata kodu
const CHAR_CASES := {
	"blurb_long": "out_of_range",
	"portrait_missing": "asset_missing",
	"unlock_unknown": "unknown_ref",
	"unlock_key": "unknown_key",
	"placeholder_type": "bad_type",
	"base_gun": "unknown_key",
}


func after_all() -> void:
	KitDev.remove_tmp()


func _codes(errs: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	for e in errs:
		out.append(e.get_slice("]", 0).trim_prefix("["))
	return out


func test_stats_set_is_closed_and_has_21_names() -> void:
	var want := AchievementMetricRegistry.default().stats().size()
	assert_eq(AchievementDef.STATS.size(), want, "kapalı küme = metrik kaydındaki stat sayısı")
	var seen := {}
	for s in AchievementDef.STATS:
		seen[s] = true
	assert_eq(seen.size(), want, "yinelenen stat yok")


func test_scope_of_total_prefix_run_otherwise_unknown_empty() -> void:
	assert_eq(AchievementDef.scope_of(&"total_kills"), &"total")
	assert_eq(AchievementDef.scope_of(&"total_chars5"), &"total")
	assert_eq(AchievementDef.scope_of(&"run_time"), &"run")
	assert_eq(AchievementDef.scope_of(&"run_bomb_hits"), &"run")
	assert_eq(AchievementDef.scope_of(&"yok_boyle"), &"")
	assert_eq(AchievementDef.scope_of(&"total_"), &"", "ön ek yetmez: kapalı küme")


func test_tier_index() -> void:
	assert_eq(AchievementDef.tier_index(&"kolay"), 0)
	assert_eq(AchievementDef.tier_index(&"cok_zor"), 3)
	assert_eq(AchievementDef.tier_index(&"çok_zor"), -1, "JSON'da ASCII")


func test_v20_data_loads_22_achievements_matching_table() -> void:
	var g := AchKit.legacy_data()
	assert_eq(g.achievements.size(), 22)
	assert_eq(g.achievement_ids.size(), 22)
	for id in TABLE:
		var a := g.get_achievement(StringName(id))
		assert_not_null(a, id)
		if a == null:
			continue
		assert_eq(String(a.stat), TABLE[id][0], id)
		assert_eq(a.target, TABLE[id][1], id)
		assert_eq(String(a.tier), TABLE[id][2], id)
		assert_eq(a.scope, AchievementDef.scope_of(a.stat), id)
		assert_lte(a.display_name.length(), 22, id)
		assert_lte(a.desc.length(), 60, id)
	assert_null(g.get_achievement(&"yok_boyle"))


func test_v20_data_tier_distribution_6_9_5_2() -> void:
	var g := AchKit.legacy_data()
	var n := [0, 0, 0, 0]
	for a in g.achievements:
		n[AchievementDef.tier_index(a.tier)] += 1
	assert_eq(n, [6, 9, 5, 2])


func test_real_data_file_order_is_array_order() -> void:
	var g := GameData.load_dir(REAL)
	assert_eq(g.achievement_ids[0], &"endure", "v2.0.3: ilk aile")
	assert_eq(g.achievement_ids[18], &"two_roads")
	assert_eq(AchKit.legacy_data().achievement_ids[21], &"bomba_ustasi")
	for i in g.achievements.size():
		assert_eq(g.achievements[i].id, g.achievement_ids[i])


func test_real_data_is_valid_in_complete_mode() -> void:
	assert_eq(GameData.load_dir(REAL).validate({}, true), PackedStringArray())


func test_barutcu_and_dynamite_are_gone() -> void:
	var g := GameData.load_dir(REAL)
	assert_false(g.character_ids.has(&"barutcu"))
	assert_null(g.get_skill(&"dinamit"))
	for p in [
		"res://data/characters/barutcu.json",
		"res://data/skills/dinamit.json",
		"res://scripts/sim/skills/dinamit.gd",
		"res://assets/gfx/char/barutcu_arm.png",
		"res://assets/ui/icons/dinamit.svg",
	]:
		assert_false(FileAccess.file_exists(p), "silinmeliydi: %s" % p)
	assert_true(FileAccess.file_exists("res://assets/ui/icons/hud-patlama.svg"))


func test_zyfen_values_and_assets() -> void:
	var g := GameData.load_dir(REAL)
	var c := g.get_character(&"zyfen")
	assert_eq(c.display_name, "Zyfen")
	assert_eq(c.max_hp, 85.0)
	assert_eq(c.mag_cap, 8)
	assert_eq(c.reload_time, 1.3)
	assert_eq(c.starting_skill, &"ruzgar_kesigi")
	assert_eq(g.get_skill(c.starting_skill).pool, &"zyfen")
	assert_eq(g.get_skill(c.starting_skill).kind, SkillDef.KIND_ACTIVE)
	assert_false(c.placeholder, "U2: gerçek gövde şeridi ve portre bağlandı")
	assert_eq(c.unlock_achievement, &"", "ödül yok: kilit yok")
	for p in [c.rig["body"], c.portrait]:
		assert_true(FileAccess.file_exists(p), p)
	assert_lte(c.blurb.length(), 120)
	assert_ne(c.blurb, "")


func test_gunslinger_gets_portrait_and_blurb_unchanged_stats() -> void:
	var c := GameData.load_dir(REAL).get_character(&"gunslinger")
	assert_eq(c.portrait, "res://assets/ui/portre-seviye-atlama.png")
	assert_ne(c.blurb, "")
	assert_false(c.placeholder)
	assert_eq(c.unlock_achievement, &"")
	assert_eq(c.max_hp, 100.0)
	assert_eq(c.mag_cap, 6)
	assert_eq(c.starting_skill, &"cift_tabanca")


func test_character_ids_follow_order_field() -> void:
	# F-030: `order` artan; eşitlikte dosya adı sırası. Bilinen kimlikler katalogda ve bu sırada (yeni karakter araya girebilir).
	var ids := GameData.load_dir(REAL).character_ids
	assert_gte(ids.find(&"gunslinger"), 0, "gunslinger katalogda")
	assert_gt(ids.find(&"zyfen"), ids.find(&"gunslinger"), "gunslinger zyfen'den önce")
	var g := CatalogFixtures.characters(3)
	g.get_character(&"zz_c0").order = 2
	g.get_character(&"zz_c1").order = 2
	g.get_character(&"zz_c2").order = 1
	g._sort_character_ids()
	assert_eq(
		g.character_ids,
		[&"zz_c2", &"zz_c0", &"zz_c1"] as Array[StringName],
		"eşitlikte dosya sırası"
	)


func test_character_def_defaults_for_missing_v2_fields() -> void:
	var c := CharacterDef.from_dict({"id": "x", "name": "X"})
	assert_eq(c.blurb, "")
	assert_eq(c.portrait, "")
	assert_eq(c.unlock_achievement, &"")
	assert_false(c.placeholder)


func test_character_def_wrong_types_do_not_crash() -> void:
	var c := CharacterDef.from_dict(
		{"id": "x", "blurb": 5, "portrait": [], "unlock": "ilk_kan", "placeholder": "evet"}
	)
	assert_eq(c.blurb, "")
	assert_eq(c.portrait, "")
	assert_eq(c.unlock_achievement, &"")
	assert_false(c.placeholder)


func test_character_def_unlock_achievement_read() -> void:
	var c := CharacterDef.from_dict({"id": "x", "unlock": {"achievement": "bes_dakika"}})
	assert_eq(c.unlock_achievement, &"bes_dakika")


func test_char_bad_fixtures_report_their_code() -> void:
	for case in CHAR_CASES:
		var errs := GameData.load_dir(KitDev.data_dir("%s/char_bad_%s" % [FIX, case])).validate(
			{}, true
		)
		assert_true(
			_codes(errs).has(CHAR_CASES[case]),
			"%s: [%s] bekleniyordu: %s" % [case, CHAR_CASES[case], errs]
		)


func test_valid_unlock_reference_passes() -> void:
	var files := {
		"characters/gunslinger.json":
		_with(
			KitDev.read_json(FIX + "/data_valid/characters/gunslinger.json"),
			{"unlock": {"achievement": "ilk_kan"}}
		)
	}
	var errs := GameData.load_dir(KitDev.data_dir_with(files)).validate({}, true)
	assert_eq(errs, PackedStringArray())
	var c := GameData.load_dir(KitDev.data_dir_with(files)).get_character(&"gunslinger")
	assert_eq(c.unlock_achievement, &"ilk_kan")


func test_atlas_cells_7_enemies_pass_17_fail() -> void:
	assert_eq(GameData.load_dir(REAL).enemy_ids.size(), 7)
	assert_false(_codes(GameData.load_dir(REAL).validate({}, true)).has("atlas_cells"))
	var errs := GameData.load_dir(KitDev.data_dir(FIX + "/data_bad_atlas_cells")).validate({}, true)
	assert_true(_codes(errs).has("atlas_cells"), str(errs))
	assert_eq(
		GameData.load_dir(KitDev.data_dir(FIX + "/data_bad_atlas_cells")).enemy_ids.size(), 17
	)


func test_atlas_cells_exactly_16_passes() -> void:
	var files := {}
	var base: Dictionary = KitDev.read_json(FIX + "/data_valid/enemies/les_kargasi.json")
	for i in 12:  # 4 + 12 = 16
		var d := base.duplicate(true)
		d["id"] = "atlas_on_alti_%02d" % i
		files["enemies/atlas_on_alti_%02d.json" % i] = d
	var g := GameData.load_dir(KitDev.data_dir_with(files))
	assert_eq(g.enemy_ids.size(), 16)
	assert_false(_codes(g.validate({}, true)).has("atlas_cells"))


func test_missing_achievements_file_only_fails_complete_mode() -> void:
	var dir := KitDev.data_dir_with({"achievements.json": null})
	assert_eq(GameData.load_dir(dir).validate({}, false), PackedStringArray())
	assert_true(_codes(GameData.load_dir(dir).validate({}, true)).has("missing_file"))
	assert_eq(GameData.load_dir(dir).achievements.size(), 0)


func test_achievement_error_codes() -> void:
	var cases := {
		"bad_json": ["{ bozuk", "bad_json"],
		"root_not_array": [{"a": 1}, "bad_type"],
		"entry_not_object": [[5], "bad_type"],
		"unknown_key": [[_ach({"extra": 1})], "unknown_key"],
		"dup_id": [[_ach({}), _ach({})], "dup_id"],
		"bad_id_chars": [[_ach({"id": "Büyük"})], "bad_type"],
		"id_too_long": [[_ach({"id": "a".repeat(41)})], "bad_type"],
		"name_too_long": [[_ach({"name": "x".repeat(23)})], "out_of_range"],
		"desc_too_long": [[_ach({"desc": "x".repeat(61)})], "out_of_range"],
		"target_zero": [[_ach({"target": 0})], "out_of_range"],
		"target_fraction": [[_ach({"target": 1.5})], "bad_type"],
		"target_huge": [[_ach({"target": 1000000000})], "out_of_range"],
		"bad_scope": [[_ach({"scope": "hepsi"})], "bad_type"],
		"bad_tier": [[_ach({"tier": "çok_zor"})], "bad_type"],
		"icon_missing": [[_ach({"icon": "res://yok/ikon.png"})], "asset_missing"],
		"missing_name": [[_ach({"name": null})], "missing_field"],
	}
	for k in cases:
		var errs := (
			GameData
			. load_dir(KitDev.data_dir_with({"achievements.json": cases[k][0]}))
			. validate({}, false)
		)
		assert_true(
			_codes(errs).has(cases[k][1]), "%s: [%s] bekleniyordu: %s" % [k, cases[k][1], errs]
		)


func test_ach_count_boundaries_12_and_30() -> void:
	for n in [11, 31]:
		var errs := (
			GameData
			. load_dir(KitDev.data_dir_with({"achievements.json": _many(n)}))
			. validate({}, true)
		)
		assert_true(_codes(errs).has("ach_count"), "%d: %s" % [n, errs])
	for n in [12, 30]:
		var errs := (
			GameData
			. load_dir(KitDev.data_dir_with({"achievements.json": _many(n)}))
			. validate({}, true)
		)
		assert_false(_codes(errs).has("ach_count"), "%d: %s" % [n, errs])


func test_ach_count_not_enforced_outside_complete_mode() -> void:
	var errs := GameData.load_dir(KitDev.data_dir_with({"achievements.json": _many(3)})).validate(
		{}, false
	)
	assert_false(_codes(errs).has("ach_count"))
	assert_false(_codes(errs).has("tier_missing"))


func _ach(over: Dictionary) -> Dictionary:
	var d := {
		"id": "ilk_kan",
		"name": "İlk Kan",
		"desc": "x",
		"stat": "total_kills",
		"target": 1,
		"scope": "total",
		"tier": "kolay"
	}
	return _with(d, over)


## null değer anahtarı siler.
func _with(base: Dictionary, over: Dictionary) -> Dictionary:
	var d := base.duplicate(true)
	for k in over:
		if over[k] == null:
			d.erase(k)
		else:
			d[k] = over[k]
	return d


## n kayıt; kademeler dönüşümlü (her kademe temsil edilir).
func _many(n: int) -> Array:
	var out := []
	for i in n:
		out.append(_ach({"id": "b_%02d" % i, "tier": AchievementDef.TIERS[i % 4]}))
	return out
