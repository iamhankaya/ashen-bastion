extends GutTest
## ScoreKeeper: öldürme puanı, SERİ pencere/eşik, bozulma, bonuslar. Tüm kurallar tam sayı adımdır.

var _gained: Array = []
var _streaks: Array = []


func _keeper() -> ScoreKeeper:
	var d := GameData.load_default()
	var k := ScoreKeeper.new(d.score_table)
	k.gained.connect(func(g: int, s: StringName) -> void: _gained.append([g, s]))
	k.streak_changed.connect(func(m: int, l: float) -> void: _streaks.append([m, l]))
	return k


func before_each() -> void:
	_gained.clear()
	_streaks.clear()


func test_first_kill_scores_table_value_at_mult_1() -> void:
	var k := _keeper()
	assert_eq(k.on_kill(&"curumus_piyade", 10), 10)
	assert_eq(k.on_kill(&"elit_karga", 11), 1500)
	assert_eq(k.kills_part, 1510)
	assert_eq(k.streak_part, 0)
	assert_eq(k.total(), 1510)
	assert_eq(_gained[0], [10, &"kill"])


func test_unknown_type_scores_zero_but_counts_in_streak() -> void:
	var k := _keeper()
	assert_eq(k.on_kill(&"yok_boyle_tur", 1), 0)
	assert_eq(k.streak_count, 1)


func test_tenth_kill_gets_the_new_multiplier() -> void:
	var k := _keeper()
	for i in 9:
		assert_eq(k.on_kill(&"curumus_piyade", 1 + i), 10, "%d. öldürme x1" % (i + 1))
	assert_eq(k.mult, 1)
	assert_eq(k.on_kill(&"curumus_piyade", 10), 20, "10. öldürme x2")
	assert_eq(k.mult, 2)
	assert_eq(k.kills_part, 100)
	assert_eq(k.streak_part, 10)
	assert_eq(_streaks.back(), [2, 3.0])


func test_tier_thresholds_25_50_100() -> void:
	var k := _keeper()
	for i in 24:
		k.on_kill(&"curumus_piyade", i)
	assert_eq(k.mult, 2)
	k.on_kill(&"curumus_piyade", 24)
	assert_eq(k.mult, 3)
	for i in 24:
		k.on_kill(&"curumus_piyade", 25 + i)
	assert_eq(k.mult, 3)
	k.on_kill(&"curumus_piyade", 49)
	assert_eq(k.mult, 4)
	for i in 49:
		k.on_kill(&"curumus_piyade", 50 + i)
	assert_eq(k.mult, 4)
	k.on_kill(&"curumus_piyade", 99)
	assert_eq(k.mult, 5)
	assert_eq(k.best_mult, 5)


func test_window_180_steps_keeps_181_resets() -> void:
	var k := _keeper()
	for i in 10:
		k.on_kill(&"curumus_piyade", i)
	assert_eq(k.mult, 2)
	k.on_kill(&"curumus_piyade", 9 + 180)
	assert_eq(k.streak_count, 11, "tam 180 adım: seri sürer")
	var k2 := _keeper()
	for i in 10:
		k2.on_kill(&"curumus_piyade", i)
	_streaks.clear()
	k2.tick(9 + 180)
	assert_eq(_streaks.size(), 0, "180. adımda henüz bozulmaz")
	k2.tick(9 + 181)
	assert_eq(k2.mult, 1)
	assert_eq(k2.streak_count, 0)
	assert_eq(_streaks.back(), [1, 0.0])


func test_kill_after_window_without_tick_starts_fresh_series() -> void:
	var k := _keeper()
	for i in 10:
		k.on_kill(&"curumus_piyade", i)
	assert_eq(k.on_kill(&"curumus_piyade", 9 + 181), 10, "yeni seri x1")
	assert_eq(k.streak_count, 1)
	assert_eq(k.mult, 1)


func test_break_streak_resets_and_next_kill_restarts() -> void:
	var k := _keeper()
	for i in 25:
		k.on_kill(&"curumus_piyade", i)
	assert_eq(k.mult, 3)
	_streaks.clear()
	k.break_streak(30)
	assert_eq(k.mult, 1)
	assert_eq(k.streak_count, 0)
	assert_eq(_streaks.back(), [1, 0.0])
	assert_eq(k.on_kill(&"curumus_piyade", 30), 10)
	assert_eq(k.streak_count, 1)


func test_break_streak_without_series_is_silent() -> void:
	var k := _keeper()
	k.break_streak(5)
	assert_eq(_streaks.size(), 0)


func test_streak_left_counts_down_from_3_to_0() -> void:
	var k := _keeper()
	assert_eq(k.streak_left(0), 0.0)
	k.on_kill(&"curumus_piyade", 100)
	assert_almost_eq(k.streak_left(100), 3.0, 1e-6)
	assert_almost_eq(k.streak_left(160), 2.0, 1e-6)
	assert_almost_eq(k.streak_left(280), 0.0, 1e-6)
	assert_eq(k.streak_left(400), 0.0, "geçmişte kalan: 0")


func test_evolution_and_lord_bonuses() -> void:
	var k := _keeper()
	assert_eq(k.on_evolution(), 2000)
	assert_eq(k.on_evolution(), 2000)
	assert_eq(k.evolution_part, 4000)
	assert_eq(k.on_lord(), 25000)
	assert_eq(k.lord_part, 25000)
	assert_eq(_gained[0], [2000, &"evolution"])
	assert_eq(_gained[2], [25000, &"lord"])


func test_survival_is_integer_division_of_steps_and_silent() -> void:
	var k := _keeper()
	k.tick(600)
	assert_eq(k.survival_part, 50)
	k.tick(601)
	assert_eq(k.survival_part, 50, "5*601/60 = 50 (tamsayı bölme)")
	k.tick(1200)
	assert_eq(k.survival_part, 100)
	assert_eq(_gained.size(), 0, "hayatta kalma sızması kazanç yayınlamaz")


func test_total_equals_sum_of_parts() -> void:
	var k := _keeper()
	for i in 12:
		k.on_kill(&"sovalye_hayaleti", i)
	k.on_evolution()
	k.on_lord()
	k.tick(300)
	var p := k.parts()
	assert_eq(k.total(), p["kills"] + p["streak"] + p["evolution"] + p["survival"] + p["lord"])
	assert_eq(p["kills"], 600)
	assert_eq(p["streak"], 3 * 50, "10., 11. ve 12. öldürme x2: 3 x 50 x (2-1)")


func test_two_kills_same_step_are_ordered_by_call_order() -> void:
	var k := _keeper()
	for i in 9:
		k.on_kill(&"curumus_piyade", 5)
	assert_eq(k.on_kill(&"elit_piyade", 5), 800, "aynı adımda 10. öldürme x2")
	assert_eq(k.on_kill(&"curumus_piyade", 5), 20)
