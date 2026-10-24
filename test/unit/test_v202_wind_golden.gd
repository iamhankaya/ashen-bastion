extends GutTest
## U3 altın hash kanıtı: Gunslinger u3 = u1b (rüzgar seti Gunslinger sim'ine dokunmaz); Tufan'lı Zyfen koşusu `zyfen_u3`
## kaydına eşit, RUNNING ve u2'den farklı. Kayıt: tools/golden/golden_run.gd --stage zyfen_u3 --characters zyfen
## --zyfen-u3-grants --write (senaryo GoldenKit, yük GoldenKit.ZYFEN_U3_GRANTS).

var _fix: Dictionary


func before_all() -> void:
	_fix = GoldenKit.load_fixture()


func _stage(key: String, character: String) -> Dictionary:
	return _fix.get("stages", {}).get(key, {}).get(character, {})


func test_gunslinger_live_run_equals_u1b_record() -> void:
	for s in GoldenKit.seeds():
		var want: Dictionary = _stage("u1b", "gunslinger")[str(s)]
		var got := GoldenKit.run(s, &"gunslinger")
		assert_eq(got["hash"], int(want["hash"]), "u3=u1b tohum %d: state_hash" % s)
		assert_eq(got["rng_combat"], want["rng_combat"], "tohum %d: rng_combat" % s)
		for f in ["steps", "level_ups", "kills", "elites", "pickups", "state"]:
			assert_eq(got[f], int(want[f]), "tohum %d: %s" % [s, f])


func test_zyfen_u3_record_exists_and_scenario_preconditions_hold() -> void:
	var rec := _stage("zyfen_u3", "zyfen")
	assert_eq(rec.size(), GoldenKit.seeds().size())
	for s in GoldenKit.seeds():
		var r: Dictionary = rec[str(s)]
		assert_gte(int(r["steps"]), GoldenKit.STEPS)
		assert_gte(int(r["level_ups"]), GoldenKit.MIN_LEVEL_UPS)
		assert_eq(int(r["state"]), 0, "RUNNING bitti")
		assert_ne(int(r["hash"]), int(_stage("u2", "zyfen")[str(s)]["hash"]), "u2'den farklı")


func test_zyfen_u3_live_run_equals_record_twice() -> void:
	for s in GoldenKit.seeds():
		var want: Dictionary = _stage("zyfen_u3", "zyfen")[str(s)]
		var got := GoldenKit.run(s, &"zyfen", GoldenKit.STEPS, GoldenKit.ZYFEN_U3_GRANTS)
		assert_eq(got["hash"], int(want["hash"]), "tohum %d: state_hash" % s)
		assert_eq(got["rng_combat"], want["rng_combat"], "tohum %d: rng_combat" % s)
		for f in ["steps", "level_ups", "kills", "elites", "pickups", "state"]:
			assert_eq(got[f], int(want[f]), "tohum %d: %s" % [s, f])
	var s0: int = GoldenKit.seeds()[0]
	var a := GoldenKit.run(s0, &"zyfen", GoldenKit.STEPS, GoldenKit.ZYFEN_U3_GRANTS)["hash"]
	var b := GoldenKit.run(s0, &"zyfen", GoldenKit.STEPS, GoldenKit.ZYFEN_U3_GRANTS)["hash"]
	assert_eq(a, b)
