extends GutTest
## Kabul (v2.1 S): Sonsuz mod s26 (R3a: test_acc_v21_endless.gd'den ayrıldı; 60*400 adımlık ağır koşu, shard dengesi).

const START := 1190.0


func _endless(diff: StringName = &"hard", extra: Dictionary = {}) -> GameSim:
	var o := {
		"data": V21Acc.lord_only_data(),
		"run_profile": V21Kit.profile(&"endless", diff),
		"start_time": START,
	}
	o.merge(extra, true)
	var s := GameSim.new(5, &"gunslinger", o)
	V21Acc.quiet_player(s)
	return s


func test_s26_a_lord_that_never_dies_does_not_repeat() -> void:
	if V21Slice.require(self, "S"):
		return
	var s := _endless()
	var w := V21Acc.watch(s)
	V21Acc.run_until(s, 60 * 400)
	assert_eq(w["spawns"].size(), 1, "ölmeyen Lord için tekrar yok")
	assert_false(s.milestone_won)
