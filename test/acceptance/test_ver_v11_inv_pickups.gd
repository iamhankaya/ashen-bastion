extends GutTest
## Doğrulama (T20261023-98) P20 kısa sürüm: bot koşularında her 60 adımda `check_invariants()` boş.
## Gate'te kısa: erken oyun (doğal, ölüm dahil) + geç oyun (14 dk'dan, ölümsüz) × politikalar × eklentili/eklentisiz.
## 20 dk'lık tam koşular `test/long/test_ver_v11_long.gd` (bash tools/verify_long.sh).
## Eklenti kolu (R3a: test_ver_v11_invariants.gd'den ayrıldı).


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
