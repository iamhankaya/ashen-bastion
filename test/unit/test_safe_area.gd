extends GutTest
## Güvenli alan (ara denetim #3) ve joystick sabitleri (#2): tek yerden ayar.


func test_no_safe_area_gives_zero_extra() -> void:
	assert_eq(UiKit.safe_extra(Vector2i(1080, 2400), Rect2i(), Vector2(1080, 2400)), Vector4.ZERO)
	assert_eq(
		UiKit.safe_extra(Vector2i(0, 0), Rect2i(0, 0, 10, 10), Vector2(1080, 2400)), Vector4.ZERO
	)


func test_full_screen_safe_area_gives_zero_extra() -> void:
	var e := UiKit.safe_extra(Vector2i(1080, 2400), Rect2i(0, 0, 1080, 2400), Vector2(1080, 2400))
	assert_eq(e, Vector4.ZERO)


func test_notch_and_rounded_corners_add_extra_beyond_defaults() -> void:
	# Pencere 2×: güvenli alan solda/sağda 100 px, üstte 240 px, altta 160 px içeride.
	var win := Vector2i(2160, 4800)
	var safe := Rect2i(100, 240, 1960, 4400)
	var e := UiKit.safe_extra(win, safe, Vector2(1080, 2400))
	assert_almost_eq(e.x, 50.0 - UiKit.SIDE, 1e-3)
	assert_almost_eq(e.y, 120.0 - UiKit.DEFAULT_TOP, 1e-3)
	assert_almost_eq(e.z, 50.0 - UiKit.SIDE, 1e-3)
	assert_almost_eq(e.w, 80.0 - UiKit.DEFAULT_BOTTOM, 1e-3)


func test_hud_keeps_at_least_36px_side_margin_and_applies_extra() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	for n in ["LevelBadge", "HpBar", "Active0", "Passive0", "MagazineDrum"]:
		var c: Control = hud.find_child(n, true, false)
		assert_not_null(c, n)
		if c != null:
			assert_gte(
				c.offset_left, 36.0 - 6.0 - 0.001, "%s sol kenar >= 30 (kalp 36'dan başlar)" % n
			)
	assert_gte((hud.find_child("LevelBadge", true, false) as Control).offset_left, 36.0)
	assert_gte((hud.find_child("Active0", true, false) as Control).offset_left, 36.0)
	assert_gte((hud.find_child("Heart", true, false) as Control).offset_left, 30.0)
	hud.apply_safe_area(Vector4(40, 20, 10, 5))
	assert_eq(hud.safe.offset_left, 40.0)
	assert_eq(hud.safe.offset_top, 20.0)
	assert_eq(hud.safe.offset_right, -10.0)
	assert_eq(hud.safe.offset_bottom, -5.0)


func test_joystick_constants_derive_from_one_place() -> void:
	assert_between(InputGate.MAX_RADIUS, 180.0, 210.0, "ara denetim önerisi 180–210 px")
	assert_almost_eq(InputGate.DEAD_ZONE * InputGate.MAX_RADIUS, InputGate.DEAD_ZONE_PX, 1e-4)
	assert_almost_eq(InputGate.DEAD_ZONE_PX, 24.0, 1e-4)
	assert_almost_eq(JoystickView.BASE_DIAMETER, InputGate.MAX_RADIUS * 2.0, 1e-4)
