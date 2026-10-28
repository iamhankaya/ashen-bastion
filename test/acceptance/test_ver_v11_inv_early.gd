extends GutTest
## Doğrulama (T20261023-98) P20 kısa sürüm: bot koşularında her 60 adımda `check_invariants()` boş.
## Gate'te kısa: erken oyun (doğal, ölüm dahil) + geç oyun (14 dk'dan, ölümsüz) × politikalar × eklentili/eklentisiz.
## 20 dk'lık tam koşular `test/long/test_ver_v11_long.gd` (bash tools/verify_long.sh).
## Erken oyun kolu: politika × kol başına ayrı test (R3a: eski tek döngü testi 7'ye bölündü; shard dengesi).

const EARLY_STEPS := 7200  # 2 dk


func _early(policy: StringName, with_pickups: bool) -> void:
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
	assert_eq(r["violations"], PackedStringArray(), "erken %s pickups=%s" % [policy, with_pickups])
	assert_gt(int(r["checks"]), 0)


func test_p20_early_idle_without_pickups_invariants_every_60_steps() -> void:
	_early(&"idle", false)


func test_p20_early_kite_without_pickups_invariants_every_60_steps() -> void:
	_early(&"kite", false)


func test_p20_early_greedy_without_pickups_invariants_every_60_steps() -> void:
	_early(&"greedy", false)


func test_p20_early_idle_with_pickups_invariants_every_60_steps() -> void:
	_early(&"idle", true)


func test_p20_early_kite_with_pickups_invariants_every_60_steps() -> void:
	_early(&"kite", true)


func test_p20_early_greedy_with_pickups_invariants_every_60_steps() -> void:
	_early(&"greedy", true)


func test_p20_early_greedy_pickup_with_pickups_invariants_every_60_steps() -> void:
	_early(&"greedy_pickup", true)
