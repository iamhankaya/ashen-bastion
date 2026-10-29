extends GutTest
## R1: Sfx sınırları ve tekrar aralıkları data/sfx_rules.json'dan gelir (sfx.gd'de karaktere özgü kimlik yok).


func before_each() -> void:
	Sfx.clear_caches()


func after_each() -> void:
	Sfx.clear_caches()


func test_rf1_limit_of_reads_rule_and_defaults_to_pool_size() -> void:
	assert_eq(Sfx.limit_of(&"shot_right"), 4)
	assert_eq(Sfx.limit_of(&"zyfen_gather"), 1)
	assert_eq(Sfx.limit_of(&"zz_kuralsiz_ses"), Sfx.POOL_SIZE)


func test_rf1_min_gap_of_reads_rule_and_defaults_to_zero() -> void:
	assert_eq(Sfx.min_gap_of(&"girdap"), 3000)
	assert_eq(Sfx.min_gap_of(&"hortum"), 400)
	assert_eq(Sfx.min_gap_of(&"hit"), 0)
	assert_eq(Sfx.min_gap_of(&"zz_kuralsiz_ses"), 0)


func test_rf1_clear_caches_rereads_rules_and_keeps_values() -> void:
	assert_eq(Sfx.limit_of(&"hit"), 3)
	Sfx.clear_caches()
	assert_eq(Sfx.limit_of(&"hit"), 3)


func test_rf1_clear_caches_drops_registered_streams_and_gap_state() -> void:
	Sfx.register_stream(&"zz_test_ses", AudioStreamWAV.new())
	Sfx._last_ms[&"hortum"] = 1000
	Sfx.clear_caches()
	assert_eq(Sfx.variant_count(&"zz_test_ses"), 0)
	assert_false(Sfx.gap_blocked(&"hortum", 1100))


func test_rf1_rule_file_values_are_positive_and_limits_fit_the_pool() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Sfx.RULES_PATH))
	assert_true(parsed is Dictionary, "sfx_rules.json okunur")
	for id in parsed["limits"]:
		assert_between(int(parsed["limits"][id]), 1, Sfx.POOL_SIZE, "limits.%s" % id)
	for id in parsed["min_gap_ms"]:
		assert_gt(int(parsed["min_gap_ms"][id]), 0, "min_gap_ms.%s" % id)
