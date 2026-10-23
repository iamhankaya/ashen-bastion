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


func test_unlimited_keeps_count_and_cycles_rhythm_index() -> void:
	var m := _mag()
	m.set_unlimited(true)
	var seen: Array[int] = []
	var lasts := 0
	for _k in 14:
		var r := m.consume()
		assert_true(r["ok"])
		seen.append(r["index"])
		if r["is_last"]:
			lasts += 1
		assert_eq(m.count, m.cap, "sayaç düşmez")
	assert_eq(seen, [1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6, 1, 2])
	assert_eq(lasts, 2, "ritim: son mermi her cap'te bir")


func test_unlimited_continues_cycle_from_current_position() -> void:
	var m := _mag()
	m.consume()
	m.consume()
	m.set_unlimited(true)  # count 4: sıradaki 3. mermi
	assert_eq(m.count, 6)
	assert_eq(m.consume()["index"], 3)


func test_unlimited_cancels_reload_and_emits_finished() -> void:
	var m := _mag()
	m.count = 0
	m.start_reload(StatBlock.new())
	var finished := [0]
	m.reload_finished.connect(func() -> void: finished[0] += 1)
	m.set_unlimited(true)
	assert_false(m.reloading)
	assert_eq(m.count, m.cap)
	assert_eq(finished[0], 1)
	assert_eq(m.consume()["index"], 1, "doldururken alınırsa döngü 1'den")


func test_unlimited_disables_reload_tick_and_refund_and_restores_full_on_end() -> void:
	var m := _mag()
	m.set_unlimited(true)
	m.tick(0.5, StatBlock.new())
	assert_false(m.reloading)
	m.refund(3)
	assert_eq(m.count, m.cap)
	m.set_unlimited(false)
	assert_eq(m.count, m.cap)
	assert_false(m.reloading, "bitişte doldurma tetiklenmez")
	assert_eq(m.consume()["index"], 1)
	assert_eq(m.count, 5, "normal tüketim geri gelir")


func test_set_unlimited_is_idempotent() -> void:
	var m := _mag()
	m.consume()
	m.set_unlimited(true)
	m.consume()
	m.set_unlimited(true)
	assert_eq(m.consume()["index"], 3, "ikinci çağrı döngüyü sıfırlamaz")
