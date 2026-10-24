extends GutTest


func test_fixed_points() -> void:
	var hp := {300.0: 1.6625, 600.0: 2.65, 900.0: 3.9625, 1200.0: 5.6}
	var dmg := {300.0: 1.2, 600.0: 1.7, 900.0: 2.2, 1200.0: 2.7}
	var cap := {300.0: 130, 600.0: 220, 900.0: 310, 1200.0: 400}
	for t in hp.keys():
		assert_almost_eq(Difficulty.enemy_hp_mult(t), hp[t], 1e-6, "hp %d" % t)
		assert_almost_eq(Difficulty.enemy_dmg_mult(t), dmg[t], 1e-6, "dmg %d" % t)
		assert_eq(Difficulty.alive_cap(t), cap[t], "cap %d" % t)


func test_start_values_and_speed_cap() -> void:
	assert_almost_eq(Difficulty.enemy_hp_mult(0.0), 1.0, 1e-9)
	assert_almost_eq(Difficulty.enemy_speed_mult(0.0), 1.0, 1e-9)
	assert_almost_eq(Difficulty.enemy_speed_mult(600.0), 1.12, 1e-6)
	assert_almost_eq(Difficulty.enemy_speed_mult(5000.0), 1.25, 1e-9)
	assert_eq(Difficulty.alive_cap(0.0), 40)


func test_alive_cap_passes_300_at_about_867_seconds() -> void:
	assert_lt(Difficulty.alive_cap(860.0), 300)
	assert_gt(Difficulty.alive_cap(870.0), 297)
	assert_eq(Difficulty.alive_cap(10000.0), EnemyPool.CAP)
