extends GutTest
## Kabul (v2.0.2 K, P): altın hash zinciri (plan "Plan notları" #5): v201 = s1 = u1a (havuz ayrımı + sözleşme davranışı
## DEĞİŞTİRMEZ), u1b ≠ u1a (tek sebep: dinamit çıkışı), u2/u3'te Gunslinger = u1b (Zyfen işi Gunslinger'ı etkilemez),
## `zyfen_u3` canlı koşuyla aynı. Kayıtlar test/fixtures/golden_hashes.json; senaryo GoldenKit. Karşılaştırıcının kendisi
## de sınanır (p5): bilinçli bozulmuş kayıtla kırmızı verir. Havuz-süzgeci / altın-hash mutasyon kanıtı kapanış raporunda.

const FIELDS := ["hash", "steps", "level_ups", "kills", "elites", "pickups", "state"]

var _fix: Dictionary


func before_all() -> void:
	_fix = GoldenKit.load_fixture()


func _rec(stage: String, character: String, seed_value: int) -> Dictionary:
	return _fix.get("stages", {}).get(stage, {}).get(character, {}).get(str(seed_value), {})


## İki kaydın farkı (alan adları); boş dizi = aynı.
func _diff(a: Dictionary, b: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for f in FIELDS:
		if int(a.get(f, -1)) != int(b.get(f, -2)):
			out.append(f)
	if str(a.get("rng_combat", "a")) != str(b.get("rng_combat", "b")):
		out.append("rng_combat")
	return out


func test_p1_gunslinger_v201_equals_s1_equals_u1a_for_every_seed() -> void:
	if V202Slice.require(self, "P"):
		return
	assert_gt(GoldenKit.seeds().size(), 1, "en az 2 sabit tohum")
	for s in GoldenKit.seeds():
		var v := _rec("v201", "gunslinger", s)
		assert_false(v.is_empty(), "v201 kaydı tohum %d" % s)
		assert_eq(
			_diff(_rec("s1", "gunslinger", s), v), PackedStringArray(), "s1=v201 tohum %d" % s
		)
		assert_eq(
			_diff(_rec("u1a", "gunslinger", s), v), PackedStringArray(), "u1a=v201 tohum %d" % s
		)
		assert_gte(int(v["steps"]), 7200, "senaryo >= 7200 adım")
		assert_gte(int(v["level_ups"]), 4, "senaryo >= 4 seviye atlama")


func test_p2_dynamite_removal_changes_the_gunslinger_hash_for_every_seed() -> void:
	if V202Slice.require(self, "P"):
		return
	for s in GoldenKit.seeds():
		var a := _rec("u1a", "gunslinger", s)
		var b := _rec("u1b", "gunslinger", s)
		assert_ne(int(b["hash"]), int(a["hash"]), "u1b != u1a tohum %d" % s)


func test_p3_u2_and_u3_gunslinger_records_equal_u1b() -> void:
	if V202Slice.require(self, "P"):
		return
	for s in GoldenKit.seeds():
		var b := _rec("u1b", "gunslinger", s)
		assert_eq(_diff(_rec("u2", "gunslinger", s), b), PackedStringArray(), "u2=u1b tohum %d" % s)
	assert_true(_fix["stages"].has("zyfen_u3"), "zyfen_u3 kaydı var")
	for s in GoldenKit.seeds():
		var z := _rec("zyfen_u3", "zyfen", s)
		assert_false(z.is_empty(), "zyfen_u3 tohum %d" % s)
		assert_gte(int(z["steps"]), 7200)
		assert_eq(int(z["state"]), 0, "Zyfen koşusu RUNNING bitti")


func test_p4_live_gunslinger_run_equals_the_u1b_record() -> void:
	if V202Slice.require(self, "P"):
		return
	for s in GoldenKit.seeds():
		var got := GoldenKit.run(s, &"gunslinger")
		var want := _rec("u1b", "gunslinger", s)
		assert_eq(_diff(got, want), PackedStringArray(), "canlı koşu tohum %d" % s)


func test_p5_live_zyfen_u3_run_equals_its_record() -> void:
	if V202Slice.require(self, "P"):
		return
	var s: int = GoldenKit.seeds()[0]
	var got := GoldenKit.run(s, &"zyfen", GoldenKit.STEPS, GoldenKit.ZYFEN_U3_GRANTS)
	assert_eq(
		_diff(got, _rec("zyfen_u3", "zyfen", s)), PackedStringArray(), "zyfen_u3 tohum %d" % s
	)


func test_p6_comparator_detects_a_tampered_record() -> void:
	if V202Slice.require(self, "P"):
		return
	var s: int = GoldenKit.seeds()[0]
	var rec := _rec("u1b", "gunslinger", s)
	assert_eq(_diff(rec, rec), PackedStringArray(), "kendisiyle aynı")
	for f in FIELDS:
		var t := rec.duplicate()
		t[f] = int(t[f]) + 1
		assert_eq(_diff(t, rec), PackedStringArray([f]), "%s bozulması yakalanır" % f)
	var t2 := rec.duplicate()
	t2["rng_combat"] = "1" + str(t2["rng_combat"])
	assert_eq(_diff(t2, rec), PackedStringArray(["rng_combat"]), "rng_combat bozulması yakalanır")


func test_p7_state_hash_sees_zones_but_an_empty_zone_pool_adds_nothing() -> void:
	if V202Slice.require(self, "P"):
		return
	var g := SimKit.make(5, {"character": &"gunslinger"})
	var g2 := SimKit.make(5, {"character": &"gunslinger"})
	assert_eq(g.zones.hash_items().size(), 0, "bölge yokken hash katkısı boş dizi")
	assert_eq(g.state_hash(), g2.state_hash(), "aynı tohum aynı hash")
	var z := SimKit.make(5, {"character": &"zyfen"})
	var h0 := z.state_hash()
	z.zones.spawn(
		ZonePool.KIND_TWISTER, Vector2(300, 0), {"radius": 100.0, "life": 3.0, "tick_every": 0.4}
	)
	assert_ne(z.state_hash(), h0, "bölge varken hash değişir")
