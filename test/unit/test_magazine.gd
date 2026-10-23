extends GutTest
## Şarjör kuralları: tüketim indeksleri, otomatik doldurma, cap değişimi, refund, refund_used.


func _mag(cap: int = 6) -> Magazine:
	var m := Magazine.new()
	m.cap = cap
	m.count = cap
	return m


func test_consume_indices_and_last_flag() -> void:
	var m := _mag()
	for expected in range(1, 7):
		var r := m.consume()
		assert_true(r["ok"])
		assert_eq(r["index"], expected)
		assert_eq(r["is_last"], expected == 6)
	assert_eq(m.count, 0)
	assert_false(m.can_fire())


func test_consume_when_empty_or_reloading_changes_nothing() -> void:
	var m := _mag()
	m.count = 0
	assert_false(m.consume()["ok"])
	m.count = 3
	m.reloading = true
	assert_false(m.consume()["ok"])
	assert_eq(m.count, 3)


func test_empty_magazine_starts_reload_at_next_tick_and_fills_after_one_second() -> void:
	var m := _mag()
	var stats := StatBlock.new()
	m.count = 0
	m.tick(1.0 / 60.0, stats)
	assert_true(m.reloading)
	assert_almost_eq(m.reload_total, 1.0, 1e-6)
	var steps := 0
	while m.reloading and steps < 200:
		m.tick(1.0 / 60.0, stats)
		steps += 1
	assert_between(steps, 59, 61)
	assert_eq(m.count, 6)
	assert_false(m.reloading)


func test_reload_time_uses_multiplier_with_floor() -> void:
	var m := _mag()
	var stats := StatBlock.new()
	stats.reload_time_mult = 0.5
	m.start_reload(stats)
	assert_almost_eq(m.reload_total, 0.5, 1e-6)
	var m2 := _mag()
	stats.reload_time_mult = 0.1
	m2.start_reload(stats)
	assert_almost_eq(m2.reload_total, Magazine.MIN_RELOAD, 1e-6)


func test_stat_change_mid_reload_does_not_affect_current_reload() -> void:
	var m := _mag()
	var stats := StatBlock.new()
	m.start_reload(stats)
	stats.reload_time_mult = 0.5
	m.tick(0.1, stats)
	assert_almost_eq(m.reload_total, 1.0, 1e-6)


func test_cap_increase_adds_bullets_immediately_unless_reloading() -> void:
	var m := _mag()
	m.count = 2
	m.set_cap(9)
	assert_eq(m.cap, 9)
	assert_eq(m.count, 5)
	var r := _mag()
	r.start_reload(StatBlock.new())
	r.set_cap(9)
	assert_eq(r.count, 6, "doldururken count değişmez; bitişte cap'e dolar")
	r.tick(2.0, StatBlock.new())
	assert_eq(r.count, 9)


func test_cap_decrease_clamps_count() -> void:
	var m := _mag(9)
	m.set_cap(6)
	assert_eq(m.count, 6)


func test_refund_ignored_while_reloading_and_capped() -> void:
	var m := _mag()
	m.count = 0
	m.refund(2)
	assert_eq(m.count, 2)
	m.refund(10)
	assert_eq(m.count, 6)
	m.count = 0
	m.start_reload(StatBlock.new())
	m.refund(2)
	assert_eq(m.count, 0)


func test_refund_on_last_bullet_prevents_auto_reload() -> void:
	var m := _mag()
	var stats := StatBlock.new()
	m.count = 1
	m.consume()
	m.refund(2)
	m.tick(1.0 / 60.0, stats)
	assert_false(m.reloading)
	assert_eq(m.count, 2)


func test_refund_used_resets_when_reload_finishes() -> void:
	var m := _mag()
	var stats := StatBlock.new()
	m.refund_used = true
	m.start_reload(stats)
	m.tick(2.0, stats)
	assert_false(m.refund_used)
	m.refund_used = true
	m.reset_cycle_flags()
	assert_false(m.refund_used)


func test_signals_fire() -> void:
	var m := _mag()
	watch_signals(m)
	m.consume()
	assert_signal_emitted(m, "changed")
	m.count = 0
	m.tick(0.01, StatBlock.new())
	assert_signal_emitted(m, "reload_started")
	m.tick(2.0, StatBlock.new())
	assert_signal_emitted(m, "reload_finished")
