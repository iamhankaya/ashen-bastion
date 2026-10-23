extends GutTest
## HighscoreScreen: 0/3/10 giriş, boş durum, satır parçaları, odak, güvenli alan, sinyaller.


func _e(score: int, won: bool, time: int, unix: int) -> Dictionary:
	return {"score": score, "time": time, "won": won, "level": 5, "unix": unix}


func _screen(entries: Array[Dictionary], highlight: int = -1) -> HighscoreScreen:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var s := HighscoreScreen.new()
	host.add_child(s)
	s.show_scores(entries, highlight)
	return s


func _entries(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in n:
		out.append(_e(246350 - i * 1000, i % 2 == 0, 1200 - i * 60, 1_700_000_000 + i * 86400))
	return out


func _row_text(s: HighscoreScreen, i: int, node: String) -> String:
	return ((s.rows[i].get_node("Inner") as Control).get_node(node) as Label).text


func test_empty_state_shows_texts_play_button_and_focus() -> void:
	var s := _screen([] as Array[Dictionary])
	await get_tree().process_frame
	assert_true(s.empty)
	assert_true(s.empty_box.visible)
	assert_eq(s.empty_title.text, "HENÜZ SKOR YOK")
	assert_eq(s.empty_text.text, "İlk oyunundan sonra en iyi on sonucun burada listelenir.")
	assert_true(s.play_button.visible)
	assert_eq(s.play_button.text, "OYNA")
	assert_eq(s.play_button.size.y, 180.0)
	assert_eq(s.play_button.position.y, 1500.0)
	for r in s.rows:
		assert_false(r.visible, "boşken satır yok")
	assert_true(s.play_button.has_focus(), "boşta varsayılan odak OYNA")


func test_filled_state_focus_is_back_and_play_hidden() -> void:
	var s := _screen(_entries(3))
	await get_tree().process_frame
	assert_false(s.empty)
	assert_false(s.play_button.visible)
	assert_true(s.back_button.has_focus())
	assert_eq(s.back_button.text, "GERİ")


func test_three_entries_fill_three_rows_and_seven_empty_slots() -> void:
	var s := _screen(_entries(3))
	assert_eq(s.rows.size(), 10)
	for i in 10:
		assert_true(s.rows[i].visible)
		var filled := i < 3
		assert_eq((s.rows[i].get_node("Dash") as Control).visible, not filled, "boş yuva kesikli")
		assert_eq(
			((s.rows[i].get_node("Inner") as Control).get_node("Score") as Control).visible, filled
		)


func test_row_parts_text_formats() -> void:
	var s := _screen(_entries(2))
	assert_eq(_row_text(s, 0, "Score"), "246.350")
	assert_eq(_row_text(s, 0, "Time"), "20:00")
	assert_eq(_row_text(s, 1, "Time"), "19:00")
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	assert_eq(_row_text(s, 0, "Date"), Highscores.format_date(1_700_000_000, bias))
	var chip0 := (
		(s.rows[0].get_node("Inner") as Control).get_node("Chip") as HighscoreScreen.ResultChip
	)
	var chip1 := (
		(s.rows[1].get_node("Inner") as Control).get_node("Chip") as HighscoreScreen.ResultChip
	)
	assert_eq(chip0.text, "KAZANDI")
	assert_true(chip0.won)
	assert_eq(chip1.text, "YENİLDİ")
	assert_false(chip1.won)


func test_ten_rows_span_y_360_to_2028_and_back_below() -> void:
	var s := _screen(_entries(10))
	assert_eq(s.rows[0].position.y, 360.0)
	assert_eq(s.rows[0].size, Vector2(936, 156))
	assert_eq(s.rows[1].position.y, 360.0 + 168.0)
	var last := s.rows[9]
	assert_almost_eq(last.position.y + last.size.y, 2028.0, 0.01)
	assert_eq(s.back_button.size, Vector2(936, 132))
	assert_almost_eq(s.back_button.position.y + s.back_button.size.y, 2400.0 - 72.0, 0.01)
	assert_gt(s.back_button.position.y, last.position.y + last.size.y)
	assert_eq(s.title_label.text, "EN İYİ SKORLAR")
	assert_eq(s.sub_label.text, "Bu cihazdaki en iyi 10 sonuç")


func test_more_than_ten_entries_are_cut_to_ten() -> void:
	var s := _screen(_entries(14))
	assert_true(s._entries.size() == 10)


func test_highlight_marks_new_row_only() -> void:
	var s := _screen(_entries(5), 2)
	for i in 5:
		var tag := (s.rows[i].get_node("Inner") as Control).get_node("New") as Control
		assert_eq(tag.visible, i == 2)
	assert_eq(s.highlight, 2)
	var plain := _screen(_entries(5), -1)
	assert_eq(plain.highlight, -1)
	var bad := _screen(_entries(2), 7)
	assert_eq(bad.highlight, -1, "geçersiz indeks yok sayılır")


func test_signals() -> void:
	var s := _screen([] as Array[Dictionary])
	watch_signals(s)
	s.back_button.pressed.emit()
	s.play_button.pressed.emit()
	assert_signal_emit_count(s, "back_requested", 1)
	assert_signal_emit_count(s, "play_requested", 1)


func test_safe_area_extra_keeps_content_inside() -> void:
	var s := _screen(_entries(10))
	s.apply_safe_area(Vector4(0, 100, 0, 150))
	assert_gte(s.title_label.position.y, 96.0 + 100.0)
	var limit := 2400.0 - 72.0 - 150.0
	assert_lte(s.back_button.position.y + s.back_button.size.y, limit)
	for r in s.rows:
		assert_lte(r.position.y + r.size.y, s.back_button.position.y, "satırlar GERİ'nin üstünde")
		assert_gte(r.position.y, 96.0 + 100.0)
	s.apply_safe_area(Vector4.ZERO)
	assert_eq(s.rows[0].position.y, 360.0)
	assert_eq(s.rows[0].size.y, 156.0)


func test_empty_state_safe_area() -> void:
	var s := _screen([] as Array[Dictionary])
	s.apply_safe_area(Vector4(0, 100, 0, 150))
	var limit := 2400.0 - 72.0 - 150.0
	assert_lte(s.back_button.position.y + s.back_button.size.y, limit)
	assert_lte(s.play_button.position.y + s.play_button.size.y, s.back_button.position.y)
