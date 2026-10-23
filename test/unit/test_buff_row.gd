extends GutTest
## BuffRow: konum, saniye metni, yanıp sönme, rozet sayısı ve kayma.


func _sim() -> GameSim:
	return SimKit.make(1, {"data_kind": "quiet", "pickups": false})


func test_badge_x_and_seconds_text_and_blinking() -> void:
	assert_eq(BuffRow.badge_x(0), 231.0)
	assert_eq(BuffRow.badge_x(1), 351.0)
	assert_eq(BuffRow.badge_x(2), 471.0)
	assert_eq(BuffRow.seconds_text(720), "12")
	assert_eq(BuffRow.seconds_text(719), "12")
	assert_eq(BuffRow.seconds_text(61), "2")
	assert_eq(BuffRow.seconds_text(60), "1")
	assert_eq(BuffRow.seconds_text(1), "1")
	assert_eq(BuffRow.seconds_text(0), "0")
	assert_false(BuffRow.blinking(3.01))
	assert_true(BuffRow.blinking(3.0))
	assert_true(BuffRow.blinking(0.5))


func test_hidden_until_bound_and_counts_active_badges() -> void:
	var row := BuffRow.new()
	add_child_autofree(row)
	assert_false(row.visible)
	var sim := _sim()
	row.bind(sim)
	assert_true(row.visible)
	assert_eq(row.badge_count(), 0)
	sim.buffs.start(BuffManager.Kind.DAMAGE, 720, 1.5)
	sim.buffs.start(BuffManager.Kind.UNLIMITED, 600)
	row.refresh(0.016)
	assert_eq(row.badge_count(), 2)
	assert_eq(row._target_x[BuffManager.Kind.DAMAGE], 231.0)
	assert_eq(row._target_x[BuffManager.Kind.UNLIMITED], 351.0)


func test_remaining_badges_slide_left_when_one_ends() -> void:
	var row := BuffRow.new()
	add_child_autofree(row)
	var sim := _sim()
	row.bind(sim)
	sim.buffs.start(BuffManager.Kind.DAMAGE, 3, 1.5)
	sim.buffs.start(BuffManager.Kind.FIRE_RATE, 700, 1.4)
	row.refresh(0.016)
	assert_eq(row._x[BuffManager.Kind.FIRE_RATE], 351.0)
	var ended := PackedInt32Array()
	for _s in 3:
		sim.buffs.tick(ended)
	row.refresh(0.016)
	assert_eq(row._target_x[BuffManager.Kind.FIRE_RATE], 231.0)
	assert_eq(row.badge_count(), 2, "kapanan 220 ms sürer")
	for _f in 20:
		row.refresh(0.016)
	assert_eq(row.badge_count(), 1)
	assert_almost_eq(row._x[BuffManager.Kind.FIRE_RATE], 231.0, 0.5)


func test_refresh_triggers_pop_and_never_more_than_three_badges() -> void:
	var row := BuffRow.new()
	add_child_autofree(row)
	var sim := _sim()
	row.bind(sim)
	sim.buffs.start(BuffManager.Kind.DAMAGE, 100, 1.5)
	row.refresh(0.016)
	row._pop[0] = 0.0
	sim.buffs.start(BuffManager.Kind.DAMAGE, 720, 1.5)
	row.refresh(0.016)
	assert_gt(row._pop[0], 0.0, "yenileme pop yapar")
	for k in 3:
		sim.buffs.start(k, 600)
	row.refresh(0.016)
	assert_lte(row.badge_count(), 3)


func test_draw_runs_headless_without_error() -> void:
	var row := BuffRow.new()
	row.size = Vector2(500, 108)
	add_child_autofree(row)
	var sim := _sim()
	row.bind(sim)
	for k in 3:
		sim.buffs.start(k, 100 + k * 100)
	row.refresh(0.016)
	row.queue_redraw()
	await get_tree().process_frame
	assert_eq(row.badge_count(), 3)
