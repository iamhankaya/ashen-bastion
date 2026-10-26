extends GutTest
## v2.0.3: ana sayfa AYARLAR düğmesi sütunun son satırındadır (EN İYİ SKORLAR yanında); güvenli alan sütunla birlikte kayar.

var m: MainMenu


func before_each() -> void:
	m = MainMenu.new()
	add_child_autofree(m)
	await get_tree().process_frame
	await get_tree().process_frame


func test_settings_button_sits_in_last_row_beside_scores() -> void:
	assert_eq(m.settings_button.get_parent(), m.scores_button.get_parent())
	assert_almost_eq(m.settings_button.global_position.y, m.scores_button.global_position.y, 0.5)
	assert_eq(m.settings_button.size.y, 132.0)
	assert_eq(m.settings_button.text, "AYARLAR")


func test_settings_button_follows_bottom_inset_and_stays_in_safe_area() -> void:
	m.apply_safe_area(Vector4.ZERO)
	var base_y := m.settings_button.global_position.y
	m.apply_safe_area(Vector4(0, 0, 90, 150))
	await get_tree().process_frame
	assert_almost_eq(m.settings_button.global_position.y, base_y - 150.0, 0.5)
	var r := m.settings_button.global_position.x + m.settings_button.size.x
	assert_lte(r, m.size.x - UiKit.SIDE - 90.0 + 0.5, "sağ pay içeride")
	assert_lte(
		m.version_label.global_position.y + m.version_label.size.y, 2400.0 - 72.0 - 150.0 + 0.5
	)


func test_settings_requested_signal() -> void:
	watch_signals(m)
	m.settings_button.pressed.emit()
	assert_signal_emit_count(m, "settings_requested", 1)


func test_title_clears_top_inset() -> void:
	m.apply_safe_area(Vector4(0, 200, 0, 0))
	await get_tree().process_frame
	assert_gte(m._head.global_position.y, 96.0 + 200.0 - 0.5)
