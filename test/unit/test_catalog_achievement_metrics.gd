extends GutTest
## AchievementMetricRegistry + AchievementReducer iskeletleri (sözleşme-B): sentetik 0/1/3 metrik ve validate() hataları.


func _reg(metrics: Array) -> AchievementMetricRegistry:
	return AchievementMetricRegistry.from_dicts(metrics)


func _errs(metrics: Array) -> String:
	return "\n".join(_reg(metrics).validate())


func test_zero_one_three_metrics() -> void:
	for n in [0, 1, 3]:
		var r := _reg(CatalogFixtures.metrics(n))
		assert_eq(r.validate().size(), 0, "n=%d %s" % [n, str(r.validate())])
		assert_eq(r.stats().size(), n)
		assert_eq(r.total_tiers(), n * 3)


func test_metric_lookup_and_unknown() -> void:
	var r := _reg(CatalogFixtures.metrics(3))
	assert_eq(r.stats(), PackedStringArray(["zz_stat0", "zz_stat1", "zz_stat2"]))
	assert_eq(r.metric("zz_stat1")["group"], "ZZ")
	assert_eq(r.metric("yok"), {})


func test_missing_or_bad_tiers_fail() -> void:
	var m := CatalogFixtures.metrics(2)
	m[0]["tiers"] = []
	m[1]["tiers"] = [20, 10]
	var e := _errs(m)
	assert_string_contains(e, "ACH_METRIC: zz_stat0: tiers boş")
	assert_string_contains(e, "ACH_METRIC: zz_stat1: tiers artan olmalı")


func test_unknown_aggregate_event_and_reducer_fail() -> void:
	var m := CatalogFixtures.metrics(3)
	m[0]["aggregate"] = "avg"
	m[1]["source"]["event"] = "yok_olay"
	m[2].erase("source")
	m[2].erase("aggregate")
	m[2]["reducer"] = "YokReducer"
	var e := _errs(m)
	assert_string_contains(e, "ACH_METRIC: zz_stat0: aggregate 'avg' bilinmiyor")
	assert_string_contains(e, "ACH_METRIC: zz_stat1: olay 'yok_olay' SimBus'ta yok")
	assert_string_contains(e, "ACH_METRIC: zz_stat2: reducer 'YokReducer' yok")


func test_source_and_reducer_are_exclusive_and_one_required() -> void:
	var m := CatalogFixtures.metrics(2)
	m[0]["reducer"] = "AchievementReducer"
	m[1].erase("source")
	m[1].erase("aggregate")
	var e := _errs(m)
	assert_string_contains(e, "ACH_METRIC: zz_stat0: source/aggregate ile reducer birlikte olamaz")
	assert_string_contains(e, "ACH_METRIC: zz_stat1: source+aggregate ya da reducer gerekir")


func test_duplicate_stat_and_persist_key_fail() -> void:
	var m := CatalogFixtures.metrics(3)
	m[1]["stat"] = "zz_stat0"
	m[2]["persist"]["total"] = "zz_total0"
	var e := _errs(m)
	assert_string_contains(e, "ACH_METRIC: zz_stat0: yinelenen stat")
	assert_string_contains(
		e, "ACH_METRIC: zz_stat2: persist anahtarı 'zz_total0' zz_stat0 ile çakışıyor"
	)


func test_null_persist_best_is_not_a_key_and_fractional_tier_fails() -> void:
	var m := CatalogFixtures.metrics(3)
	assert_eq(_errs(m), "")  # üçünde de best: null
	m[0]["tiers"] = [1.5, 3]
	assert_string_contains(_errs(m), "ACH_METRIC: zz_stat0: tiers artan olmalı")


func test_bad_value_expression_fails() -> void:
	var m := CatalogFixtures.metrics(1)
	m[0]["source"]["value"] = "toplam"
	assert_string_contains(_errs(m), "ACH_METRIC: zz_stat0: value 'toplam' geçersiz")
	m[0]["source"]["event"] = "bomb_hits"
	m[0]["source"]["value"] = "payload.hits"
	assert_eq(_errs(m), "")


func test_reducer_base_class_has_noop_contract() -> void:
	var r := AchievementReducer.new()
	var state := {"x": 1}
	r.on_event(&"enemy_killed", {}, state)
	r.poll(null, state)
	r.reset(state)
	assert_eq(r.finish({}, state), 0)
	assert_eq(state, {"x": 1})


func test_default_registry_is_valid() -> void:
	var r := AchievementMetricRegistry.default()
	assert_eq(r.validate().size(), 0, str(r.validate()))
	assert_eq(r.stats().size(), AchievementDef.STATS.size())
	for st in AchievementDef.STATS:
		assert_false(r.metric(st).is_empty(), st)


func test_tiers_are_optional_but_checked_when_present() -> void:
	var m := CatalogFixtures.metrics(1)
	m[0].erase("tiers")
	assert_eq(_errs(m), "")
	m[0]["tiers"] = []
	assert_string_contains(_errs(m), "tiers boş")


func test_event_value_and_filter_follow_the_event_signature() -> void:
	var m := CatalogFixtures.metrics(3)
	m[0]["source"]["value"] = "payload.level"  # enemy_killed'ın tamsayı alanı yok
	m[1]["source"]["filter"] = {"kind": ["x"]}  # enemy_killed'ın etiketi type_id
	m[2]["source"] = {"poll": "yok"}
	var e := _errs(m)
	assert_string_contains(e, "zz_stat0: value 'payload.level' olay 'enemy_killed' alanı değil")
	assert_string_contains(e, "zz_stat1: filter 'kind' olay 'enemy_killed' için geçersiz")
	assert_string_contains(e, "zz_stat2: poll 'yok' bilinmiyor")
	m[0]["source"]["value"] = "one"
	m[1]["source"]["filter"] = {"type_id": ["elit_piyade"]}
	m[2]["source"] = {"finish": "won", "value": "result.time"}
	assert_eq(_errs(m), "")


func test_same_key_in_totals_and_best_is_not_a_conflict() -> void:
	var m := CatalogFixtures.metrics(2)
	m[0]["persist"] = {"total": "zz_k", "best": null}
	m[1]["persist"] = {"total": null, "best": "zz_k"}
	assert_eq(_errs(m), "")
