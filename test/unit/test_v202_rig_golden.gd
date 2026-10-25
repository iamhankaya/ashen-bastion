extends GutTest
## U2 altın hash kanıtı: Gunslinger u2 = u1b (ArmRig refaktörü, kolsuz dal, Rüzgar Kesiği Gunslinger sim'ine dokunmaz);
## Zyfen u2 kaydı canlı koşuya eşit, durumu RUNNING ve u1b'den farklı (Rüzgar Kesiği artık gerçek davranış), iki koşu aynı.
## Kayıtlar: test/fixtures/golden_hashes.json (`u2`, tools/golden/golden_run.gd ile üretildi); senaryo GoldenKit.

var _fix: Dictionary


func before_all() -> void:
	_fix = GoldenKit.load_fixture()


func _stage(key: String, character: String) -> Dictionary:
	return _fix.get("stages", {}).get(key, {}).get(character, {})


func test_u2_gunslinger_record_equals_u1b() -> void:
	var a := _stage("u2", "gunslinger")
	var b := _stage("u1b", "gunslinger")
	assert_eq(a.size(), GoldenKit.seeds().size())
	for s in GoldenKit.seeds():
		var k := str(s)
		for f in ["hash", "steps", "level_ups", "kills", "elites", "pickups", "state"]:
			assert_eq(int(a[k][f]), int(b[k][f]), "u2=u1b %s/%s" % [k, f])
		assert_eq(a[k]["rng_combat"], b[k]["rng_combat"], "u2=u1b %s/rng_combat" % k)


func test_u2_gunslinger_live_run_equals_u1b_record() -> void:
	for s in GoldenKit.seeds():
		var want: Dictionary = _stage("u1b", "gunslinger")[str(s)]
		var got := GoldenKit.run(s, &"gunslinger")
		assert_eq(got["hash"], int(want["hash"]), "tohum %d: state_hash" % s)
		assert_eq(got["kills"], int(want["kills"]), "tohum %d: kills" % s)


## U3 Zyfen'in rüzgar davranışlarını da gerçek yaptı: canlı Zyfen koşusu artık u2 kaydına eşit değildir (beklenen).
## u2 Zyfen kaydı TARİHSELDİR (yalnız RUNNING ve u1b'den farklı denetlenir); canlı Zyfen kanıtı `zyfen_u3` aşamasındadır
## (test_v202_wind_golden.gd).
func test_u2_zyfen_record_is_historical_running_and_differs_from_u1b() -> void:
	for s in GoldenKit.seeds():
		var k := str(s)
		var want: Dictionary = _stage("u2", "zyfen")[k]
		assert_eq(int(want["state"]), 0, "Zyfen koşusu RUNNING bitti")
		assert_ne(
			int(want["hash"]),
			int(_stage("u1b", "zyfen")[k]["hash"]),
			"gerçek davranış hash'i değiştirir"
		)


func test_u2_zyfen_two_runs_are_identical() -> void:
	var s: int = GoldenKit.seeds()[0]
	assert_eq(GoldenKit.run(s, &"zyfen")["hash"], GoldenKit.run(s, &"zyfen")["hash"])
