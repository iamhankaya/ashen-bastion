extends GutTest
## R8: gerçek metrik kaydı (data/achievements/<stat>.json): yerleşik 21 stat için persist anahtarları depo ve AchievementDef
## tablolarıyla birebir, GameData doğrulayıcısı temiz, tracker'ın dinlediği olay kümesi kayıt şemasıyla aynı.
## Sözleşme "tüm kimlikler için X"tir: veriyle eklenen yeni metrik bu dosyayı kırmaz. Sıra ve sınır sayıları sentetik
## fixture ile `test_catalog_achievement_metrics` / `test_catalog_achievement_dry_run` dosyalarındadır.

const DIR := "res://data/achievements"
const REDUCER_DIR := "res://scripts/ctrl/achievement_reducers/"

var _reg: AchievementMetricRegistry


func before_each() -> void:
	_reg = AchievementMetricRegistry.default()


func test_every_closed_stat_has_exactly_one_metric_file() -> void:
	for st in AchievementDef.STATS:
		assert_true(FileAccess.file_exists("%s/%s.json" % [DIR, st]), st)
	# Her dosya tam bir stat taşır, dosya adı = stat (yinelenen stat yok); sayı veriden türer.
	var files := DirAccess.get_files_at(DIR)
	var json_files := 0
	for f in files:
		if f.ends_with(".json"):
			json_files += 1
			assert_false(_reg.metric(f.get_basename()).is_empty(), "%s: dosya adı = stat" % f)
	assert_eq(json_files, _reg.stats().size(), "dosya başına tam bir metrik")
	assert_gte(_reg.stats().size(), AchievementDef.STATS.size())


func test_persist_keys_match_the_closed_tables_exactly() -> void:
	for st in AchievementDef.STATS:
		var p: Dictionary = _reg.metric(st)["persist"]
		assert_eq(p["total"], AchievementDef.TOTAL_KEY.get(st), "%s total" % st)
		assert_eq(p["best"], AchievementDef.BEST_KEY.get(st), "%s best" % st)


func test_persist_key_sets_equal_the_store_key_lists() -> void:
	var totals := []
	var bests := []
	for st in _reg.stats():
		var p: Dictionary = _reg.metric(st)["persist"]
		if p["total"] != null:
			totals.append(p["total"])
		if p["best"] != null:
			bests.append(p["best"])
	totals.sort()
	bests.sort()
	var want_t := Array(AchievementStore.TOTAL_KEYS)
	var want_b := Array(AchievementStore.BEST_KEYS)
	want_t.sort()
	want_b.sort()
	assert_eq(totals, want_t)
	assert_eq(bests, want_b)


func test_icon_family_matches_the_icon_table() -> void:
	for st in AchievementDef.STATS:
		assert_eq(_reg.metric(st)["icon_family"], AchievementIcons.FAMILY[st], st)


func test_game_data_loads_every_metric_and_reports_no_metric_error() -> void:
	var g := GameData.load_default()
	assert_eq(g._stat_metrics.size(), _reg.stats().size(), "GameData kayıttaki her metriği yükler")
	for e in g.validate():
		assert_false(e.contains("metric_schema"), e)


func test_tracker_listens_to_exactly_the_event_table() -> void:
	var want := MetricSchema.EVENTS.keys()
	var got := Array(AchievementTracker.LISTENED)
	want.sort()
	got.sort()
	assert_eq(got, want)


func test_reducer_metrics_name_a_plugin_file_and_all_four_are_used() -> void:
	var used := []
	for st in _reg.stats():
		var rd := str(_reg.metric(st).get("reducer", ""))
		if rd == "":
			continue
		used.append(rd)
		assert_true(MetricSchema.script_path(rd).begins_with(REDUCER_DIR), rd)
	# Yerleşik dört eklenti kullanımda kalır; veriyle eklenen reducer'lar fazladan olabilir.
	for rd in [
		"CharsFiveReducer", "CleanSecsReducer", "EliteKindsReducer", "UnlimitedKillsReducer"
	]:
		assert_true(used.has(rd), rd)


func test_event_order_inside_one_event_is_the_data_order() -> void:
	# Aynı olayda birden çok stat varsa kademe açılış sırası metriğin `order` değeridir (anlık görüntü sırası).
	# Gerçek katalog beklentisi yerleşik 21 stat üzerindedir; yeni metrik araya girse de bunların göreli sırası aynı kalır.
	var kill_stats := []
	for st in AchievementDef.STATS:
		var m := _reg.metric(st)
		var ev := str((m.get("source", {}) as Dictionary).get("event", ""))
		if ev == "enemy_killed" or (m.get("events", []) as Array).has("enemy_killed"):
			kill_stats.append([int(m["order"]), st])
	kill_stats.sort()
	var names := []
	for r in kill_stats:
		names.append(r[1])
	assert_eq(
		names,
		[
			"total_kills",
			"run_kills",
			"total_boss_kills",
			"run_elit_piyade",
			"run_elite_kinds",
			"run_unlimited_kills"
		]
	)
