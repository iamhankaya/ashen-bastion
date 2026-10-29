extends GutTest
## R8 kuru denemeleri (iki ayrı): (1) veriyle ekleme: yeni metrik JSON'u + aile kaydı, hiçbir .gd değişmez;
## (2) yeni reducer dosyası: yeni .gd (test/helpers/reducer_fixtures/) + metrik JSON'u, mevcut .gd değişmez.
## Gerçek `res://data` geçici dizine kopyalanır; üstüne yalnız bu dosyalar eklenir.


func after_all() -> void:
	KitDev.remove_tmp()


func after_each() -> void:
	AchKit.cleanup()


func _root(metric_file: String, metric: Dictionary, family: Dictionary) -> String:
	var dest := "%s/rf8_%d" % [KitDev.TMP_ROOT, Time.get_ticks_usec()]
	KitDev.copy_dir("res://data", dest)
	var mf := FileAccess.open(
		dest.path_join("achievements/%s.json" % metric_file), FileAccess.WRITE
	)
	mf.store_string(JSON.stringify(metric))
	mf.close()
	var fams: Array = JSON.parse_string(
		FileAccess.get_file_as_string(dest.path_join("achievements.json"))
	)
	fams.append(family)
	var ff := FileAccess.open(dest.path_join("achievements.json"), FileAccess.WRITE)
	ff.store_string(JSON.stringify(fams))
	ff.close()
	return dest


func _family(id: String, stat: String, steps: Array) -> Dictionary:
	var fam := {"id": id, "name": id, "desc": "d", "stat": stat, "scope": "run", "steps": steps}
	fam["group"] = "THE ROAD"
	return fam


func test_dry_run_data_only_metric_unlocks_a_new_family() -> void:
	var metric := {
		"stat": "run_zz_dry",
		"order": 900,
		"icon_family": "hud-oldurme",
		"persist": {"total": null, "best": null},
		"source": {"event": "pickup_collected", "filter": {"kind_id": ["zz_kind"]}, "value": "one"},
		"aggregate": "count",
	}
	var before := GameData.load_default()._stat_metrics.size()
	var root := _root("run_zz_dry", metric, _family("zz_dry", "run_zz_dry", [2, 4]))
	var g := GameData.load_dir(root)
	assert_eq(Array(g.validate()), [], "yeni metrik ve aile doğrulayıcıdan temiz geçer")
	assert_eq(g._stat_metrics.size(), before + 1, "kayıt tam bir metrik büyüdü")
	var r := AchKit.rig(&"gunslinger", AchKit.FIXED_UNIX, g)
	var bus: SimBus = r["bus"]
	var store: AchievementStore = r["store"]
	bus.pickup_collected.emit(&"baska", Vector2.ZERO)
	bus.pickup_collected.emit(&"zz_kind", Vector2.ZERO)
	assert_false(store.is_unlocked(&"zz_dry"), "süzgeç dışı tür sayılmaz")
	bus.pickup_collected.emit(&"zz_kind", Vector2.ZERO)
	assert_eq(store.step_count(&"zz_dry"), 1)
	for _i in 2:
		bus.pickup_collected.emit(&"zz_kind", Vector2.ZERO)
	assert_eq(store.step_count(&"zz_dry"), 2)
	assert_eq((r["tracker"] as AchievementTracker).value_of(&"run_zz_dry"), 4)
	assert_eq(store.totals["kills"], 0, "yerleşik statlar etkilenmedi")


func test_dry_run_new_reducer_file_drives_a_new_family() -> void:
	var metric := {
		"stat": "run_zz_streak",
		"order": 910,
		"icon_family": "hud-oldurme",
		"persist": {"total": null, "best": null},
		"reducer": "FxStreakReducer",
		"events": ["enemy_killed", "player_damaged"],
	}
	var root := _root("run_zz_streak", metric, _family("zz_streak", "run_zz_streak", [3]))
	var g := GameData.load_dir(root)
	assert_eq(Array(g.validate()), [], "reducer sınıfı eklenti dizininde bulunur")
	var r := AchKit.rig(&"gunslinger", AchKit.FIXED_UNIX, g)
	var bus: SimBus = r["bus"]
	var store: AchievementStore = r["store"]
	AchKit.kills(bus, 2)
	bus.player_damaged.emit(1.0, 9.0)
	AchKit.kills(bus, 2)
	assert_false(store.is_unlocked(&"zz_streak"), "hasar seriyi böler")
	AchKit.kills(bus, 1)
	assert_true(store.is_unlocked(&"zz_streak"))


func test_synthetic_same_event_metrics_unlock_in_order_not_file_name_order() -> void:
	# Sıra sözleşmesi sentetik: dosya adı sırası (zz_a < zz_b) ile `order` sırası (b önce) ters seçilir.
	var fam_a := _family("zz_fam_a", "run_zz_a", [1])
	var root := _root("run_zz_a", _kill_metric("run_zz_a", 902), fam_a)
	var mf := FileAccess.open(root.path_join("achievements/run_zz_b.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(_kill_metric("run_zz_b", 901)))
	mf.close()
	var fams: Array = JSON.parse_string(
		FileAccess.get_file_as_string(root.path_join("achievements.json"))
	)
	fams.append(_family("zz_fam_b", "run_zz_b", [1]))
	var ff := FileAccess.open(root.path_join("achievements.json"), FileAccess.WRITE)
	ff.store_string(JSON.stringify(fams))
	ff.close()
	var g := GameData.load_dir(root)
	assert_eq(Array(g.validate()), [])
	var r := AchKit.rig(&"gunslinger", AchKit.FIXED_UNIX, g)
	var tracker: AchievementTracker = r["tracker"]
	var got: Array = []
	tracker.unlocked.connect(func(d: AchievementDef) -> void: got.append(String(d.id)))
	AchKit.kills(r["bus"], 1)
	var ours := got.filter(func(i: String) -> bool: return i.begins_with("zz_fam_"))
	assert_eq(ours, ["zz_fam_b", "zz_fam_a"], "küçük `order` önce")


func _kill_metric(stat: String, order: int) -> Dictionary:
	return {
		"stat": stat,
		"order": order,
		"icon_family": "hud-oldurme",
		"persist": {"total": null, "best": null},
		"source": {"event": "enemy_killed", "filter": {}, "value": "one"},
		"aggregate": "count",
	}


func test_unknown_reducer_class_is_a_schema_error() -> void:
	var metric := {
		"stat": "run_zz_bad",
		"order": 920,
		"persist": {"total": null, "best": null},
		"reducer": "YokReducer",
		"events": [],
	}
	var root := _root("run_zz_bad", metric, _family("zz_bad", "run_zz_bad", [1]))
	var errs := "\n".join(GameData.load_dir(root).validate())
	assert_string_contains(
		errs, "[metric_schema] achievements/run_zz_bad: reducer 'YokReducer' yok"
	)
