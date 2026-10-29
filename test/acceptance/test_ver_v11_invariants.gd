extends GutTest
## Doğrulama (T20261023-98) P20 kısa sürüm: bot koşularında her 60 adımda `check_invariants()` boş.
## Gate'te kısa: erken oyun (doğal, ölüm dahil) + geç oyun (14 dk'dan, ölümsüz) × politikalar × eklentili/eklentisiz.
## 20 dk'lık tam koşular `test/long/test_ver_v11_long.gd` (bash tools/verify_long.sh).

const EARLY_STEPS := 7200  # 2 dk
const LATE_START := 840.0  # 14 dk
const LATE_STEPS := 7200


func _policies(with_pickups: bool) -> Array[StringName]:
	var out: Array[StringName] = Bots.POLICIES.duplicate()
	if with_pickups:
		out.append_array(Bots.PICKUP_POLICIES)
	return out


func test_p20_early_game_invariants_every_60_steps_all_policies_both_arms() -> void:
	for with_pickups in [true, false]:
		for policy in _policies(with_pickups):
			var r := (
				AbRunner
				. run(
					{
						"seed": 20,
						"policy": policy,
						"pickups": with_pickups,
						"max_steps": EARLY_STEPS,
						"check_every": 60,
					}
				)
			)
			assert_eq(
				r["violations"], PackedStringArray(), "erken %s pickups=%s" % [policy, with_pickups]
			)
			assert_gt(int(r["checks"]), 0)


func test_p20_late_game_crowd_invariants_every_60_steps_all_policies_both_arms() -> void:
	var max_alive := 0
	for with_pickups in [true, false]:
		for policy in _policies(with_pickups):
			var r := (
				AbRunner
				. run(
					{
						"seed": 21,
						"policy": policy,
						"pickups": with_pickups,
						"max_steps": LATE_STEPS,
						"check_every": 60,
						"godmode": true,
						"start_time": LATE_START,
					}
				)
			)
			assert_eq(
				r["violations"], PackedStringArray(), "geç %s pickups=%s" % [policy, with_pickups]
			)
			assert_eq(int(r["steps"]), LATE_STEPS, "ölümsüz koşu tam adım oynar")
			max_alive = maxi(max_alive, int(r["max_alive"]))
	assert_gt(max_alive, 150, "geç oyun koşusu gerçekten kalabalık (en çok %d)" % max_alive)


func test_p20_pickup_arm_actually_exercises_pickups_and_off_arm_never_does() -> void:
	var on := (
		AbRunner
		. run(
			{
				"seed": 22,
				"policy": &"greedy_pickup",
				"pickups": true,
				"max_steps": 14400,
				"check_every": 60,
				"godmode": true,
			}
		)
	)
	var off := (
		AbRunner
		. run(
			{
				"seed": 22,
				"policy": &"greedy_pickup",
				"pickups": false,
				"max_steps": 14400,
				"check_every": 60,
				"godmode": true,
			}
		)
	)
	assert_gt((on["pickups_collected"] as Dictionary).size(), 0, "eklentili kolda eklenti toplandı")
	assert_eq((off["pickups_collected"] as Dictionary).size(), 0, "eklentisiz kolda toplanan yok")
	assert_eq((off["buff_starts"] as Dictionary).size(), 0)
	assert_eq(on["violations"], PackedStringArray())
	assert_eq(off["violations"], PackedStringArray())
