extends GutTest
## U1 altın hash zinciri (Gunslinger): v201 = s1 = u1a (havuz ayrımı davranışı değiştirmez), u1b ≠ u1a. u1b'de
## değişimin tek sebebi `dinamit`in çıkışıdır (u1a ve u1b commit'leri arasındaki fark: dinamit + Barutçu silme, veri
## ve UI adı değişikliği hash'e girmez). Zyfen için u1b yalnız "sim çalışıyor" kaydıdır (no-op gövdelerle; davranış
## iddiası U2/U3'te). Kayıtlar: test/fixtures/golden_hashes.json; senaryo: GoldenKit.

var _fix: Dictionary


func before_all() -> void:
	_fix = GoldenKit.load_fixture()


func _stage(key: String, character: String = "gunslinger") -> Dictionary:
	return _fix.get("stages", {}).get(key, {}).get(character, {})


func _same(a: Dictionary, b: Dictionary, label: String) -> void:
	for s in GoldenKit.seeds():
		var k := str(s)
		for f in ["hash", "steps", "level_ups", "kills", "elites", "pickups", "state"]:
			assert_eq(int(a[k][f]), int(b[k][f]), "%s %s/%s" % [label, k, f])
		assert_eq(a[k]["rng_combat"], b[k]["rng_combat"], "%s %s/rng_combat" % [label, k])


func test_u1a_record_equals_v201_and_s1() -> void:
	assert_eq(_stage("u1a").size(), GoldenKit.seeds().size())
	_same(_stage("u1a"), _stage("v201"), "u1a=v201")
	_same(_stage("u1a"), _stage("s1"), "u1a=s1")


func test_u1b_gunslinger_hash_differs_from_u1a_for_every_seed() -> void:
	assert_eq(_stage("u1b").size(), GoldenKit.seeds().size())
	for s in GoldenKit.seeds():
		var k := str(s)
		assert_ne(int(_stage("u1b")[k]["hash"]), int(_stage("u1a")[k]["hash"]), "tohum %s" % k)


func test_u1b_gunslinger_live_run_equals_record() -> void:
	for s in GoldenKit.seeds():
		var want: Dictionary = _stage("u1b")[str(s)]
		var got := GoldenKit.run(s, &"gunslinger")
		assert_eq(got["hash"], int(want["hash"]), "tohum %d: state_hash" % s)
		assert_eq(got["rng_combat"], want["rng_combat"], "tohum %d: rng_combat" % s)
		for k in ["steps", "level_ups", "kills", "elites", "pickups", "state"]:
			assert_eq(got[k], int(want[k]), "tohum %d: %s" % [s, k])


func test_u1b_zyfen_record_is_a_running_sim() -> void:
	# u1b Zyfen kaydı tarihsel (no-op gövdeler). U2'de Rüzgar Kesiği gerçek davranış kazandı: canlı koşu artık bu kayda eşit
	# değildir (bkz. test_v202_rig_golden.gd: u2). Kayıt yalnız "sim çalışıyordu" kanıtı olarak denetlenir.
	var rec := _stage("u1b", "zyfen")
	assert_eq(rec.size(), GoldenKit.seeds().size())
	for s in GoldenKit.seeds():
		var want: Dictionary = rec[str(s)]
		assert_gte(int(want["steps"]), GoldenKit.STEPS, "Zyfen sim'i çalışır")
		assert_eq(int(want["state"]), 0, "Zyfen koşusu RUNNING bitti")


func test_u1b_seeds_share_rng_stream_with_u1a_at_start() -> void:
	# rng_combat kaydı u1a ile aynı kalır: değişim savaş akışında değil, kart havuzu (kimin hangi kartı gördüğü) üzerindedir.
	for s in GoldenKit.seeds():
		var k := str(s)
		assert_eq(_stage("u1b")[k]["rng_combat"], _stage("u1a")[k]["rng_combat"], "tohum %s" % k)
