extends GutTest
## U1 altın hash zinciri (Gunslinger): v201 = s1 = u1a (havuz ayrımı davranışı değiştirmez). u1b'de `dinamit`
## çıkınca zincir kırılır; kırılmanın tek sebebi o çıkıştır (bkz. test_v202_pool_golden_u1b.gd).
## Kayıtlar: test/fixtures/golden_hashes.json; senaryo: GoldenKit.

var _fix: Dictionary


func before_all() -> void:
	_fix = GoldenKit.load_fixture()


func _stage(key: String) -> Dictionary:
	return _fix.get("stages", {}).get(key, {}).get("gunslinger", {})


func test_u1a_record_has_every_seed() -> void:
	var rec := _stage("u1a")
	assert_eq(rec.size(), GoldenKit.seeds().size())
	for s in GoldenKit.seeds():
		assert_true(rec.has(str(s)), "tohum %d" % s)


func test_u1a_record_equals_v201_and_s1() -> void:
	for s in GoldenKit.seeds():
		var k := str(s)
		for f in ["hash", "steps", "level_ups", "kills", "elites", "pickups", "state"]:
			assert_eq(
				int(_stage("u1a")[k][f]), int(_stage("v201")[k][f]), "u1a=v201 %s/%s" % [k, f]
			)
			assert_eq(int(_stage("u1a")[k][f]), int(_stage("s1")[k][f]), "u1a=s1 %s/%s" % [k, f])
		assert_eq(_stage("u1a")[k]["rng_combat"], _stage("v201")[k]["rng_combat"])
