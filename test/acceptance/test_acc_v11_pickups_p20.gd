extends GutTest
## Kabul (v1.1 D2): P20 - her 60 adımda değişmezler boş; politika başına ayrı test (R3a: test_acc_v11_pickups.gd'den ayrıldı).

const SLICE := "D2"
const HZ := 60


func _p20(pol: StringName) -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := SimKit.make(51, {"data_kind": "real", "log_events": false})
	var rng := Bots.make_rng(51)
	var r := Bots.play(sim, pol, 240 * HZ, rng, 60)
	assert_eq(
		(r["violations"] as PackedStringArray).size(), 0, "%s: %s" % [pol, str(r["violations"])]
	)


func test_p20_invariants_empty_every_60_steps_idle() -> void:
	_p20(&"idle")


func test_p20_invariants_empty_every_60_steps_kite() -> void:
	_p20(&"kite")


func test_p20_invariants_empty_every_60_steps_greedy() -> void:
	_p20(&"greedy")


func test_p20_invariants_empty_every_60_steps_greedy_pickup() -> void:
	_p20(&"greedy_pickup")
