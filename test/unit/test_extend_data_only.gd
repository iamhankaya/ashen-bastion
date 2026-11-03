extends GutTest
## Genişletilebilirlik (T20261103-07): yeni öğe yalnız veri/katalog değişikliğiyle çalışır.
## F-ashen-bastion-140/149 (başarım kalıcılık anahtarı), -148 (4. mod/zorluk skor sekmesi), -151 (karakter becerisi
## havuzu), -129 (karakter sfx .ogg varlığı). Gerçek `res://data` geçici dizine kopyalanır, üstüne yalnız veri eklenir.


func after_all() -> void:
	KitDev.remove_tmp()


func after_each() -> void:
	AchKit.cleanup()
	CatalogFixtures.unpin_default()


# --- F-140 / F-149: başarım metriği + kalıcılık anahtarı yalnız veriyle -----------------------------------------------


func _ach_root(metrics: Dictionary, families: Array) -> String:
	var dest := "%s/ext_%d" % [KitDev.TMP_ROOT, Time.get_ticks_usec()]
	KitDev.copy_dir("res://data", dest)
	for stat: String in metrics:
		var mf := FileAccess.open(dest.path_join("achievements/%s.json" % stat), FileAccess.WRITE)
		mf.store_string(JSON.stringify(metrics[stat]))
		mf.close()
	var fams: Array = JSON.parse_string(
		FileAccess.get_file_as_string(dest.path_join("achievements.json"))
	)
	fams.append_array(families)
	var ff := FileAccess.open(dest.path_join("achievements.json"), FileAccess.WRITE)
	ff.store_string(JSON.stringify(fams))
	ff.close()
	return dest


func _fam(id: String, stat: String, scope: String, steps: Array) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"desc": "d",
		"stat": stat,
		"scope": scope,
		"steps": steps,
		"group": "THE ROAD"
	}


func _persist_data() -> GameData:
	var total_metric := {
		"stat": "total_zz_pick",
		"order": 930,
		"icon_family": "hud-oldurme",
		"persist": {"total": "zz_picks", "best": null},
		"source": {"event": "pickup_collected", "filter": {}, "value": "one"},
		"aggregate": "sum",
	}
	var best_metric := {
		"stat": "run_zz_best",
		"order": 940,
		"icon_family": "hud-oldurme",
		"persist": {"total": null, "best": "zz_best"},
		"source": {"event": "pickup_collected", "filter": {}, "value": "one"},
		"aggregate": "sum",
	}
	var root := _ach_root(
		{"total_zz_pick": total_metric, "run_zz_best": best_metric},
		[
			_fam("zz_picks", "total_zz_pick", "total", [2, 4]),
			_fam("zz_best", "run_zz_best", "run", [2, 3])
		]
	)
	return GameData.load_dir(root)


func test_data_only_persist_keys_accumulate_unlock_and_survive_reload() -> void:
	var g := _persist_data()
	assert_eq(Array(g.validate()), [], "yeni metrik + aile doğrulayıcıdan temiz geçer")
	var r := AchKit.rig(&"gunslinger", AchKit.FIXED_UNIX, g)
	var bus: SimBus = r["bus"]
	var store: AchievementStore = r["store"]
	var tracker: AchievementTracker = r["tracker"]
	for _i in 3:
		bus.pickup_collected.emit(&"x", Vector2.ZERO)
	assert_eq(int(store.totals["zz_picks"]), 3, "yeni toplam anahtarı depoda birikir")
	assert_eq(store.step_count(&"zz_picks"), 1, "kademe 2'de açıldı")
	tracker.finish(false, {"time": 10, "level": 1, "score": 0})
	assert_eq(int(store.best["zz_best"]), 3, "yeni en-iyi anahtarı koşu sonunda yazılır")
	assert_eq(store.step_count(&"zz_best"), 2, "run kademeleri 2 ve 3 açıldı")
	assert_eq(AchievementProgress.of(g.get_achievement(&"zz_picks"), store), 3, "ekran ilerlemesi")
	assert_eq(AchievementProgress.of(g.get_achievement(&"zz_best"), store), 3)
	assert_true(store.save(), "kayıt yazılır")
	var again := AchievementStore.new(store.path)
	assert_true(again.load_file(g.achievements))
	assert_eq(int(again.totals["zz_picks"]), 3, "yeniden yüklemede toplam korunur")
	assert_eq(int(again.best["zz_best"]), 3, "yeniden yüklemede en iyi korunur")
	assert_eq(int(again.totals["kills"]), 0, "yerleşik anahtarlar etkilenmedi")


func test_data_only_persist_key_seeds_reconcile_after_threshold_added() -> void:
	var g := _persist_data()
	var st := AchKit.store()
	st.declare_counters(PackedStringArray(["zz_picks"]), PackedStringArray())
	st.add_total(&"zz_picks", 5)
	var added := AchievementMigration.reconcile(st, g.achievements, AchKit.FIXED_UNIX)
	assert_gte(added, 2, "kayıtlı sayaç hak ettiği kademeleri sessizce verir")
	assert_eq(st.step_count(&"zz_picks"), 2)


func test_hostile_save_keys_neither_displace_declared_keys_nor_persist() -> void:
	var g := _persist_data()
	var totals := {"zz_picks": 7}
	for i in 40:
		totals["a%02d" % i] = 1  # alfabetik olarak zz_picks'ten önce gelen uydurma anahtarlar
	var raw := {"v": 2, "totals": totals, "best": {"zz_best": 4, "BAD KEY": 9}}
	var clean := AchievementStore.sanitize(
		raw, PackedStringArray(["zz_picks"]), PackedStringArray(["zz_best"])
	)
	assert_eq(int(clean["totals"]["zz_picks"]), 7, "tanımlı anahtar korunur")
	assert_eq(int(clean["best"]["zz_best"]), 4)
	assert_false(clean["totals"].has("a00"), "tanımsız uydurma anahtar atılır")
	assert_false(clean["best"].has("BAD KEY"))
	assert_eq(clean["totals"].size(), AchievementStore.TOTAL_KEYS.size() + 1)
	var plain := AchievementStore.sanitize(raw)
	assert_false(plain["totals"].has("zz_picks"), "tanım verilmezse yalnız yerleşik anahtarlar")
	assert_not_null(g)


func test_invalid_persist_key_format_is_a_catalog_error() -> void:
	var metric := {
		"stat": "total_zz_pick",
		"order": 930,
		"icon_family": "hud-oldurme",
		"persist": {"total": "ZzPicks", "best": null},
		"source": {"event": "pickup_collected", "filter": {}, "value": "one"},
		"aggregate": "sum",
	}
	var root := _ach_root(
		{"total_zz_pick": metric}, [_fam("zz_picks", "total_zz_pick", "total", [2, 4])]
	)
	var errs := "\n".join(GameData.load_dir(root).validate())
	assert_string_contains(errs, "persist.total 'ZzPicks' geçersiz")


# --- F-148: 4. mod / zorluk skor ekranında kod istemez -------------------------------------------------------------


func _scores_with(n_modes: int, n_diffs: int) -> HighscoreScreen:
	var modes := CatalogFixtures.modes(n_modes)
	for m: Dictionary in modes:
		m["label"] = String(m["name"])
	var diffs := CatalogFixtures.difficulties(n_diffs)
	for d: Dictionary in diffs:
		d["label"] = String(d["name"])
	CatalogFixtures.pin_default(RunCatalog.from_dicts(modes, diffs))
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var s := HighscoreScreen.new()
	host.add_child(s)
	s.show_scores([], -1, &"zz_m3", &"zz_d3")
	return s


func test_fourth_mode_and_difficulty_tabs_are_laid_out_selectable_and_named() -> void:
	var s := _scores_with(4, 4)
	assert_eq(s.mode_tabs.size(), 4, "mod sekmesi katalog kadar")
	assert_eq(s.diff_tabs.size(), 4, "zorluk sekmesi katalog kadar")
	for tabs in [s.mode_tabs, s.diff_tabs]:
		for i in tabs.size():
			var t: Control = tabs[i]
			assert_gt(t.size.x, 0.0, "sekme %d genişliği var" % i)
			assert_gt(t.position.x + t.size.x, t.position.x)
			if i > 0:
				var prev: Control = tabs[i - 1]
				assert_gte(
					t.position.x, prev.position.x + prev.size.x, "sekme %d öncekiyle çakışmaz" % i
				)
		var last: Control = tabs[3]
		assert_lte(last.position.x + last.size.x, 1080.0, "4. sekme ekrana sığar")
		assert_gt(last.position.x, 0.0, "4. sekme (0,0)'a düşmez")
	assert_true(s.mode_tabs[3].selected, "açılış sekmesi 4. mod")
	assert_true(s.diff_tabs[3].selected, "açılış sekmesi 4. zorluk")
	assert_string_contains(s.mode_tabs[3].accessibility_name, "dördüncüsü")
	assert_string_contains(s.diff_tabs[3].accessibility_name, "dördüncüsü")
	assert_false(s.mode_tabs[0].selected)
	watch_signals(s)
	s.select_tab(&"zz_m3", &"zz_d1")
	assert_signal_emitted_with_parameters(s, "tab_changed", [&"zz_m3", &"zz_d1"])
	assert_true(s.diff_tabs[1].selected)


# --- F-151: veri-yalnız karakter becerisi havuza girince kimse kırılmaz --------------------------------------------


func _skill_root(skills: Dictionary) -> String:
	var dest := "%s/extskill_%d" % [KitDev.TMP_ROOT, Time.get_ticks_usec()]
	KitDev.copy_dir("res://data", dest)
	for id: String in skills:
		var f := FileAccess.open(dest.path_join("skills/%s.json" % id), FileAccess.WRITE)
		f.store_string(JSON.stringify(skills[id]))
		f.close()
	return dest


func _clone_passive(id: String, pool: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/skills/saglam_yelek.json")
	)
	d["id"] = id
	d["name"] = "ZZ " + id
	d["pool"] = pool
	if pool != "common":
		d.erase("variants")  # yalnız ortak pasifin karakter varyantı olur
	return d


func test_data_only_skill_in_gunslinger_and_common_pool_validates_and_is_pool_filtered() -> void:
	var root := _skill_root(
		{
			"zz_g_yelek": _clone_passive("zz_g_yelek", "gunslinger"),
			"zz_c_yelek": _clone_passive("zz_c_yelek", "common"),
		}
	)
	var g := GameData.load_dir(root)
	assert_eq(Array(g.validate()), [], "havuzlu yeni beceriler doğrulayıcıdan temiz geçer")
	assert_eq(g.get_skill(&"zz_g_yelek").pool, &"gunslinger")
	assert_eq(g.get_skill(&"zz_c_yelek").pool, &"common")
	var base := GameData.load_default()
	assert_eq(
		g.skills_of_kind(SkillDef.KIND_PASSIVE).size(),
		base.skills_of_kind(SkillDef.KIND_PASSIVE).size() + 2,
		"iki yeni pasif katalogda"
	)
	var zy := Loadout.new(g, &"zyfen")
	var gs := Loadout.new(g, &"gunslinger")
	for seed_value in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for c in zy.roll_choices(rng):
			assert_ne(c.skill_id, &"zz_g_yelek", "Zyfen Gunslinger havuzundan kart almaz")
	var seen := false
	for seed_value in 60:
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = seed_value
		for c in gs.roll_choices(rng2):
			seen = seen or c.skill_id == &"zz_g_yelek"
	assert_true(seen, "Gunslinger yeni havuz becerisini teklif alır")


# --- F-129: karakter sfx + sfx_rules anahtarları gerçek .ogg ister ------------------------------------------------


func _char_root(sfx: Variant, rules_patch: Dictionary = {}) -> String:
	var dest := "%s/extsfx_%d" % [KitDev.TMP_ROOT, Time.get_ticks_usec()]
	KitDev.copy_dir("res://data", dest)
	var c: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/characters/zyfen.json")
	)
	c["sfx"] = sfx  # başlangıç becerisi havuzu kimliğe bağlı: kimlik aynı kalır, yalnız sfx değişir
	var cf := FileAccess.open(dest.path_join("characters/zyfen.json"), FileAccess.WRITE)
	cf.store_string(JSON.stringify(c))
	cf.close()
	if not rules_patch.is_empty():
		var rules: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(dest.path_join("sfx_rules.json"))
		)
		for sect: String in rules_patch:
			(rules[sect] as Dictionary).merge(rules_patch[sect])
		var rf := FileAccess.open(dest.path_join("sfx_rules.json"), FileAccess.WRITE)
		rf.store_string(JSON.stringify(rules))
		rf.close()
	return dest


func test_character_with_real_sfx_ids_validates() -> void:
	var g := GameData.load_dir(_char_root({"shot": "zyfen_cast", "hit": ["hit_1", "hit_2"]}))
	assert_eq(Array(g.validate()), [], "gerçek .ogg kimlikleri temiz geçer")


func test_character_sfx_without_an_ogg_is_a_catalog_error() -> void:
	var g := GameData.load_dir(_char_root({"shot": "zz_yok_ses"}))
	var errs := "\n".join(g.validate())
	assert_string_contains(errs, "asset_missing", "eksik karakter sesi sessiz kalmaz")
	assert_string_contains(errs, "zz_yok_ses")


func test_sfx_rules_key_without_an_ogg_is_a_catalog_error() -> void:
	var g := GameData.load_dir(
		_char_root(
			{"shot": "zyfen_cast"}, {"limits": {"zz_ses_yok": 2}, "min_gap_ms": {"zz_ses_yok2": 50}}
		)
	)
	var errs := "\n".join(g.validate())
	assert_string_contains(errs, "zz_ses_yok", "kurallardaki ölü ses kimliği hata")
	assert_string_contains(errs, "zz_ses_yok2")


func test_every_shipped_sfx_rule_key_and_character_sfx_has_an_ogg() -> void:
	var g := GameData.load_default()
	var rules: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/sfx_rules.json")
	)
	for sect: String in ["limits", "min_gap_ms"]:
		for id: String in rules[sect]:
			assert_true(DataV2.sfx_exists(id), "sfx_rules.%s.%s için .ogg" % [sect, id])
	for cid in CharacterRoster.ids(g):
		for ev: String in g.get_character(cid).sfx:
			var v: Variant = g.get_character(cid).sfx[ev]
			for id in v if v is Array else [v]:
				assert_true(DataV2.sfx_exists(str(id)), "%s sfx.%s=%s için .ogg" % [cid, ev, id])
