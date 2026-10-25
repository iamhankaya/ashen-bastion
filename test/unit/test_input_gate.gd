extends GutTest
## InputGate: ilk parmak kuralı, ikinci parmak yok sayılır, 600 ms kilit, 120 ms sönme, |move| <= 1.


func _gate() -> InputGate:
	return InputGate.new()


func test_first_finger_drives_move() -> void:
	var g := _gate()
	g.touch(0, true, Vector2(500, 1500))
	g.drag(0, Vector2(500.0 + InputGate.MAX_RADIUS, 1500))
	assert_true(g.is_active())
	assert_almost_eq(g.move().x, 1.0, 0.0001)
	assert_almost_eq(g.move().y, 0.0, 0.0001)


func test_second_finger_is_ignored() -> void:
	var g := _gate()
	g.touch(0, true, Vector2(500, 1500))
	g.drag(0, Vector2(500, 1400))
	var before := g.move()
	g.touch(1, true, Vector2(100, 100))
	g.drag(1, Vector2(900, 900))
	assert_eq(g.finger, 0)
	assert_eq(g.move(), before)
	g.touch(1, false, Vector2(900, 900))
	assert_true(g.is_active(), "ikinci parmağın kalkması joystick'i bırakmaz")


func test_release_stops_move_and_fades_in_120ms() -> void:
	var g := _gate()
	g.touch(0, true, Vector2(500, 1500))
	g.drag(0, Vector2(600, 1500))
	g.touch(0, false, Vector2(600, 1500))
	assert_eq(g.move(), Vector2.ZERO)
	assert_almost_eq(g.visibility(), 1.0, 0.001)
	g.tick(0.06)
	assert_almost_eq(g.visibility(), 0.5, 0.01)
	g.tick(0.07)
	assert_eq(g.visibility(), 0.0)


func test_after_release_a_new_first_finger_takes_over() -> void:
	var g := _gate()
	g.touch(0, true, Vector2(500, 1500))
	g.touch(0, false, Vector2(500, 1500))
	g.touch(3, true, Vector2(200, 2000))
	assert_eq(g.finger, 3)
	assert_eq(g.origin, Vector2(200, 2000))


func test_lock_blocks_input_for_600ms() -> void:
	var g := _gate()
	g.lock()
	g.touch(0, true, Vector2(500, 1500))
	assert_false(g.is_active(), "kilitte dokunma yok sayılır")
	g.tick(0.59)
	assert_true(g.is_locked())
	g.tick(0.02)
	assert_false(g.is_locked())
	g.touch(0, true, Vector2(500, 1500))
	assert_true(g.is_active())


func test_lock_releases_held_finger_and_zeroes_move() -> void:
	var g := _gate()
	g.touch(0, true, Vector2(500, 1500))
	g.drag(0, Vector2(500, 1300))
	g.lock()
	assert_eq(g.move(), Vector2.ZERO)
	assert_false(g.is_active())


func test_held_finger_can_resume_by_dragging_after_lock() -> void:
	var g := _gate()
	g.lock()
	g.drag(0, Vector2(400, 1600))
	assert_false(g.is_active())
	g.tick(0.61)
	g.drag(0, Vector2(400, 1600))
	assert_true(g.is_active())
	assert_eq(g.origin, Vector2(400, 1600))
	assert_eq(g.move(), Vector2.ZERO)


func test_move_magnitude_never_exceeds_one() -> void:
	var g := _gate()
	g.touch(0, true, Vector2.ZERO)
	for p in [Vector2(5000, 0), Vector2(-900, 900), Vector2(150, 150), Vector2(0, -151)]:
		g.drag(0, p)
		assert_lte(g.move().length(), 1.0 + 1e-5)


func test_reset_clears_everything() -> void:
	var g := _gate()
	g.touch(0, true, Vector2(1, 2))
	g.lock()
	g.reset()
	assert_false(g.is_active())
	assert_false(g.is_locked())
	assert_eq(g.visibility(), 0.0)


# --- T20261025-82: seviye atlama / modal sonrası joystick takılması ---------------------------


func test_t82_finger_touched_during_lock_drives_when_lock_ends_without_lifting() -> void:
	var g := _gate()
	g.lock()  # seviye ekranı kapandı
	g.touch(0, true, Vector2(300, 1700))  # parmak kilit sırasında basıldı, kıpırdamıyor
	assert_eq(g.move(), Vector2.ZERO, "kilitte yön yok")
	g.tick(InputGate.LOCK_TIME + 0.01)
	assert_true(g.is_active(), "kilit bitince parmak kaldırılmadan joystick etkin")
	assert_eq(g.origin, Vector2(300, 1700))
	assert_eq(g.move(), Vector2.ZERO, "vektör sıfır başlar, takılı yön yok")
	g.drag(0, Vector2(300.0 + InputGate.MAX_RADIUS, 1700))
	assert_almost_eq(g.move().x, 1.0, 0.0001, "ilk sürüklemede hemen tepki")


func test_t82_pending_finger_origin_follows_drag_during_lock() -> void:
	var g := _gate()
	g.lock()
	g.touch(0, true, Vector2(300, 1700))
	g.drag(0, Vector2(350, 1650))
	g.tick(InputGate.LOCK_TIME + 0.01)
	assert_eq(g.origin, Vector2(350, 1650))
	assert_eq(g.move(), Vector2.ZERO)


func test_t82_finger_lifted_during_lock_leaves_no_stuck_direction() -> void:
	var g := _gate()
	g.lock()
	g.touch(0, true, Vector2(300, 1700))
	g.touch(0, false, Vector2(300, 1700))
	g.tick(InputGate.LOCK_TIME + 0.01)
	assert_false(g.is_active())
	assert_eq(g.move(), Vector2.ZERO)


func test_t82_lift_and_press_again_after_lock_reacts_on_first_touch() -> void:
	var g := _gate()
	g.lock()
	g.touch(0, true, Vector2(300, 1700))
	g.tick(InputGate.LOCK_TIME + 0.01)
	g.touch(0, false, Vector2(300, 1700))
	assert_false(g.is_active())
	g.touch(0, true, Vector2(600, 1500))
	g.drag(0, Vector2(600, 1500.0 - InputGate.MAX_RADIUS))
	assert_almost_eq(g.move().y, -1.0, 0.0001)


func test_t82_multitouch_card_finger_and_new_finger() -> void:
	# Parmak 0 kartta (kilit sırasında kalktı), parmak 1 joystick için kilit sırasında basıldı.
	var g := _gate()
	g.lock()
	g.touch(1, true, Vector2(300, 1700))
	g.touch(0, true, Vector2(540, 900))  # ikinci parmak: bekleyen değişmez
	g.touch(0, false, Vector2(540, 900))
	g.tick(InputGate.LOCK_TIME + 0.01)
	assert_eq(g.finger, 1)
	assert_eq(g.origin, Vector2(300, 1700))
	g.touch(1, false, Vector2(300, 1700))
	assert_eq(g.move(), Vector2.ZERO)
	assert_false(g.is_active())


func test_t82_new_lock_and_reset_clear_pending_finger() -> void:
	var g := _gate()
	g.lock()
	g.touch(0, true, Vector2(300, 1700))
	g.reset()
	g.tick(1.0)
	assert_false(g.is_active(), "reset bekleyen parmağı da siler")
	g.lock()
	g.touch(0, true, Vector2(300, 1700))
	g.lock()  # yeni modal: bekleyen parmak eski modala aitti
	g.tick(1.0)
	assert_false(g.is_active())
