extends GutTest
## S1 kanıtı: davranış değişmedi. Gunslinger (ve referans Barutçu) altın hash'i v2.0.1 kaydıyla (`v201`) eşit olmak
## ZORUNDA; eşit değilse S1 bir davranış değişikliği yapmıştır. Aşama zinciri: test/fixtures/golden_hashes.json.
## Kaydı üreten araç: tools/golden/golden_run.gd (aynı GoldenKit senaryosu).

var _fix: Dictionary


func before_all() -> void:
	_fix = GoldenKit.load_fixture()


func _stage(key: String, character: String) -> Dictionary:
	return _fix.get("stages", {}).get(key, {}).get(character, {})


func test_fixture_has_v201_and_s1_for_both_characters() -> void:
	for stage in ["v201", "s1"]:
		for c in ["gunslinger", "barutcu"]:
			var rec := _stage(stage, c)
			assert_eq(rec.size(), GoldenKit.seeds().size(), "%s/%s kayıt sayısı" % [stage, c])
			for s in GoldenKit.seeds():
				assert_true(rec.has(str(s)), "%s/%s tohum %d" % [stage, c, s])


func test_scenario_preconditions_hold_in_the_record() -> void:
	for c in ["gunslinger", "barutcu"]:
		for seed_key in _stage("v201", c):
			var r: Dictionary = _stage("v201", c)[seed_key]
			assert_gte(int(r["steps"]), GoldenKit.STEPS)
			assert_gte(int(r["level_ups"]), GoldenKit.MIN_LEVEL_UPS)
			assert_gt(int(r["kills"]), 0)


func test_s1_record_equals_v201_record() -> void:
	for c in ["gunslinger", "barutcu"]:
		assert_eq(_stage("s1", c), _stage("v201", c), "%s: s1 kaydı v201'e eşit" % c)


func _live_equals_v201(character: StringName) -> void:
	for s in GoldenKit.seeds():
		var want: Dictionary = _stage("v201", String(character))[str(s)]
		var got := GoldenKit.run(s, character)
		assert_eq(got["hash"], int(want["hash"]), "%s tohum %d: state_hash" % [character, s])
		assert_eq(
			got["rng_combat"], want["rng_combat"], "%s tohum %d: rng_combat.state" % [character, s]
		)
		for k in ["steps", "level_ups", "kills", "elites", "pickups", "state"]:
			assert_eq(got[k], int(want[k]), "%s tohum %d: %s" % [character, s, k])


func test_gunslinger_live_run_equals_v201() -> void:
	_live_equals_v201(&"gunslinger")


func test_barutcu_live_run_equals_v201() -> void:
	_live_equals_v201(&"barutcu")
