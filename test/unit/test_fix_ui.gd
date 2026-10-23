extends GutTest
## Ara denetim düzeltmeleri (ekranlar): V-05 sonuç çipi metni >= 26 px, F-ashen-bastion-022 boş durum etiketi ve menü sütunu.

const NOTCH := Vector4(48.0, 130.0, 48.0, 80.0)


func _e(score: int, won: bool) -> Dictionary:
	return {"score": score, "time": 1200, "won": won, "level": 5, "unix": 1_700_000_000}


func _screen(entries: Array[Dictionary]) -> HighscoreScreen:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var s := HighscoreScreen.new()
	host.add_child(s)
	s.show_scores(entries, -1)
	return s


func _ten() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in 10:
		out.append(_e(246350 - i * 1000, i % 2 == 0))
	return out


# --- V-05 --------------------------------------------------------------------------------------------------


func test_result_chip_text_is_at_least_26px() -> void:
	assert_gte(HighscoreScreen.ResultChip.FONT_SIZE, 26)


func test_result_chip_fits_row_and_does_not_collide_with_score_or_time() -> void:
	for extra in [Vector4.ZERO, NOTCH]:
		var s := _screen(_ten())
		s.apply_safe_area(extra)
		await get_tree().process_frame
		for row in s.rows:
			var inner := row.get_node("Inner") as Control
			var chip := inner.get_node("Chip") as Control
			var score := inner.get_node("Score") as Control
			var time := inner.get_node("Time") as Control
			var chip_r := Rect2(chip.position, chip.size)
			assert_gte(chip_r.size.y, 40.0, "çip yüksekliği metne yeter")
			assert_lte(chip_r.end.y, row.size.y + 0.01, "çip satırın içinde")
			assert_false(chip_r.intersects(Rect2(score.position, score.size)), "skor ile çakışmaz")
			assert_false(chip_r.intersects(Rect2(time.position, time.size)), "süre ile çakışmaz")


# --- F-ashen-bastion-022 -----------------------------------------------------------------------------------


func test_empty_state_label_is_bounded_to_its_text_after_safe_area() -> void:
	var s := _screen([] as Array[Dictionary])
	s.apply_safe_area(NOTCH)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(s.empty_text.size.y, 200.0, "etiket 2202 px şişmez")
	assert_lte(s.empty_text.position.y + s.empty_text.size.y, s.empty_box.size.y, "kutunun içinde")
	s.apply_safe_area(Vector4.ZERO)
	await get_tree().process_frame
	assert_lte(s.empty_text.size.y, 200.0)


func test_menu_column_is_936_wide_and_toggles_fit_454() -> void:
	var m := MainMenu.new()
	add_child_autofree(m)
	await get_tree().process_frame
	await get_tree().process_frame
	for sound in [true, false]:
		for vib in [true, false]:
			m.set_settings(sound, vib)
			await get_tree().process_frame
			assert_lte(m.sound_button.get_combined_minimum_size().x, 454.0, "SES ×%s" % sound)
			assert_lte(
				m.vibration_button.get_combined_minimum_size().x, 454.0, "TİTREŞİM ×%s" % vib
			)
	assert_almost_eq(m.scores_button.size.x, 936.0, 0.5, "sütun 936")
	assert_almost_eq(m.sound_button.size.x, m.vibration_button.size.x, 1.0)
