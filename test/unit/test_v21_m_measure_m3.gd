extends GutTest
## v2.1 U1a (M dilimi): mid_run.gd - Lord yokken strong_lord strong ile birebir (R3a: test_v21_m_measure.gd'den ayrıldı; 18000 adımlık ağır koşu).

const MID := "res://tools/balance/mid_run.gd"

var mid: GDScript


func before_each() -> void:
	mid = load(MID)


func test_m3_strong_lord_equals_strong_when_no_lord_exists() -> void:
	var a: Dictionary = mid.run_one(41, "strong", &"gunslinger", "", "normal", 18000)
	var b: Dictionary = mid.run_one(41, "strong_lord", &"gunslinger", "", "normal", 18000)
	for k in ["time", "level", "kills", "kills5", "hp_early", "level5", "evolutions"]:
		assert_eq(b[k], a[k], "Lord yokken %s aynı olmalı (ilk 300 sn)" % k)
	assert_false(b["reached_lord"])
