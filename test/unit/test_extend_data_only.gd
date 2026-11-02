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
				assert_gte(t.position.x, prev.position.x + prev.size.x, "sekme %d öncekiyle çakışmaz" % i)
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

