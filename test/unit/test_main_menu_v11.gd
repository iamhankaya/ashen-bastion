extends GutTest
## MainMenu v1.1: EN İYİ SKORLAR düğmesi, düzen, hero kutusu, güvenli alan.


func _menu() -> MainMenu:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var m := MainMenu.new()
	host.add_child(m)
	return m


func test_button_order_play_half_row_scores_toggles() -> void:
	var m := _menu()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(m.scores_button)
	assert_eq(m.scores_button.text, "EN İYİ SKORLAR")
	var col := m.play_button.get_parent() as Control
	assert_eq(m.scores_button.get_parent(), col)
	assert_eq(m.play_button.get_index(), 0)
	assert_eq(m.characters_button.get_parent().get_index(), 1, "v2.0: KARAKTERLER | BAŞARIMLAR 2.")
	assert_eq(m.scores_button.get_index(), 2)
	assert_eq(m.sound_button.get_parent().get_index(), 3, "ses/titreşim sırası 4.")
	assert_lt(m.play_button.global_position.y, m.scores_button.global_position.y)
	assert_lt(m.scores_button.global_position.y, m.sound_button.global_position.y)
	assert_eq(m.scores_button.size.y, 132.0)
	assert_gte(m.scores_button.size.x, 936.0)
	assert_eq(m.play_button.size.y, 180.0)


func test_column_top_at_least_1556_and_gap_27() -> void:
	var m := _menu()
	await get_tree().process_frame
	await get_tree().process_frame
	var col := m.play_button.get_parent() as Control
	assert_gte(col.global_position.y, 1556.0 - 0.01)
	var gap := m.characters_button.global_position.y - (m.play_button.global_position.y + 180.0)
	assert_almost_eq(gap, 27.0, 0.5)


func test_hero_box_960x960_ends_by_1520() -> void:
	var m := _menu()
	await get_tree().process_frame
	if m.hero == null:
		pending("ana görsel dosyası yok: hero kutusu kurulmaz")
		return
	assert_eq(m.hero.offset_right - m.hero.offset_left, 960.0)
	assert_eq(m.hero.offset_bottom - m.hero.offset_top, 960.0)
	assert_lte(1200.0 + m.hero.offset_bottom, 1520.0 + 0.01)
	assert_gte(1200.0 + m.hero.offset_top, 560.0 - 0.01)


func test_scores_requested_signal() -> void:
	var m := _menu()
	watch_signals(m)
	m.scores_button.pressed.emit()
	assert_signal_emit_count(m, "scores_requested", 1)


func test_safe_area_extra_moves_column_up_and_title_down() -> void:
	var m := _menu()
	await get_tree().process_frame
	await get_tree().process_frame
	var col := m.play_button.get_parent() as Control
	m.apply_safe_area(Vector4(0, 100, 0, 150))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(col.global_position.y + col.size.y, 2400.0 - 72.0 - 150.0 + 0.5)
	var head := m._head
	assert_gte(head.global_position.y, 96.0 + 100.0 - 0.5)
	m.apply_safe_area(Vector4.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gte(col.global_position.y, 1556.0 - 0.5)


func test_play_button_keeps_focus_on_open() -> void:
	var m := _menu()
	m.open(true, true)
	await get_tree().process_frame
	assert_true(m.play_button.has_focus())
