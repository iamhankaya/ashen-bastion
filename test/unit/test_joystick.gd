extends GutTest
## Joystick matematiği: ölü bölge, normalizasyon, yarıçap sınırı; JoystickView yalnız InputGate'i yansıtır.


func test_dead_zone_returns_zero() -> void:
	var r := InputGate.MAX_RADIUS
	assert_eq(InputGate.stick_vector(Vector2(r * 0.05, 0)), Vector2.ZERO)
	assert_eq(InputGate.stick_vector(Vector2(0, r * 0.12)), Vector2.ZERO)
	assert_gt(InputGate.stick_vector(Vector2(0, r * 0.13)).length(), 0.0)


func test_rescaled_after_dead_zone() -> void:
	var r := InputGate.MAX_RADIUS
	var dz := InputGate.DEAD_ZONE
	var half := InputGate.stick_vector(Vector2(r * (dz + (1.0 - dz) * 0.5), 0))
	assert_almost_eq(half.x, 0.5, 1e-4)


func test_full_radius_is_unit_and_beyond_is_clamped() -> void:
	var r := InputGate.MAX_RADIUS
	assert_almost_eq(InputGate.stick_vector(Vector2(0, -r)).length(), 1.0, 1e-5)
	assert_almost_eq(InputGate.stick_vector(Vector2(r * 3, r * 3)).length(), 1.0, 1e-5)


func test_direction_is_preserved() -> void:
	var v := InputGate.stick_vector(Vector2(-90, 120))
	assert_almost_eq(v.angle(), Vector2(-90, 120).angle(), 1e-5)


func test_knob_position_limited_to_radius() -> void:
	var o := Vector2(300, 1800)
	assert_eq(JoystickView.knob_position(o, o + Vector2(50, 0), 150.0), o + Vector2(50, 0))
	var far := JoystickView.knob_position(o, o + Vector2(0, 900), 150.0)
	assert_almost_eq(far.distance_to(o), 150.0, 1e-3)


func test_view_mirrors_gate_state() -> void:
	var view := JoystickView.new()
	add_child_autofree(view)
	var g := InputGate.new()
	view.show_state(g)
	assert_eq(view.alpha, 0.0)
	g.touch(0, true, Vector2(400, 1700))
	g.drag(0, Vector2(400, 1300))
	view.show_state(g)
	assert_eq(view.alpha, 1.0)
	assert_eq(view.base_center, Vector2(400, 1700))
	assert_eq(view.knob_center, Vector2(400, 1700 - InputGate.MAX_RADIUS))
	assert_eq(view.mouse_filter, Control.MOUSE_FILTER_IGNORE)
