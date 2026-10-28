extends GutTest
## Doğrulama (T20261023-98) P20 kısa sürüm: bot koşularında her 60 adımda `check_invariants()` boş.
## Gate'te kısa: erken oyun (doğal, ölüm dahil) + geç oyun (14 dk'dan, ölümsüz) × politikalar × eklentili/eklentisiz.
## 20 dk'lık tam koşular `test/long/test_ver_v11_long.gd` (bash tools/verify_long.sh).
## Geç oyun kolu (R3a: test_ver_v11_invariants.gd'den ayrıldı).

const LATE_START := 840.0  # 14 dk
const LATE_STEPS := 7200


func _policies(with_pickups: bool) -> Array[StringName]:
	var out: Array[StringName] = Bots.POLICIES.duplicate()
	if with_pickups:
		out.append_array(Bots.PICKUP_POLICIES)
	return out


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
