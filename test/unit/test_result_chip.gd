extends GutTest
## ResultScreen yeni başarım çipi (B4/M5): özet metni, kombo ≤3 satır, düğmeler sığar, boşken v1.1 düzeni aynen.

const STATS := {
	"time": 321.0,
	"level": 7,
	"kills": 99,
	"score": 4200,
	"best_mult": 3,
	"evolutions": [],
	"score_parts": {"kills": 100, "streak": 10, "evolution": 0, "survival": 50, "lord": 0},
}


func _screen() -> ResultScreen:
	var r := ResultScreen.new()
	add_child_autofree(r)
	return r


func _combos(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in n:
		out.append({"id": &"x%d" % i, "name": "Kombo %d" % i, "pair": "A + B", "icon": ""})
	return out


func _names(n: int) -> Array[String]:
	var out: Array[String] = []
	for i in n:
		out.append(["İlk Kan", "Beş Dakika", "Kırım", "Seri Ustası"][i])
	return out


func test_m5_empty_summary_keeps_v11_layout() -> void:
	var a := _screen()
	a.show_result(false, STATS, _combos(4))
	var b := _screen()
	b.set_new_achievements([] as Array[String])
	b.show_result(false, STATS, _combos(4))
	assert_false(b.achievement_chip.visible)
	assert_eq(b.combo_panel.position, a.combo_panel.position)
	assert_eq(b.replay_button.position, a.replay_button.position)
	assert_eq(b.combo_box.get_child_count(), 4, "özet yokken 4 kombo")


func test_b4_chip_texts_two_names_plus_k() -> void:
	var r := _screen()
	r.set_new_achievements(_names(1))
	assert_eq(r.chip_title.text, "YENİ BAŞARIM · 1")
	assert_eq(r.chip_names.text, "İlk Kan")
	r.set_new_achievements(_names(2))
	assert_eq(r.chip_names.text, "İlk Kan, Beş Dakika")
	r.set_new_achievements(_names(4))
	assert_eq(r.chip_title.text, "YENİ BAŞARIM · 4")
	assert_eq(r.chip_names.text, "İlk Kan, Beş Dakika +2")
	assert_eq(
		r.achievement_chip.accessibility_name,
		"4 yeni başarım: İlk Kan, Beş Dakika, Kırım, Seri Ustası"
	)


func test_b4_chip_geometry_between_strip_and_combos() -> void:
	var r := _screen()
	r.set_new_achievements(_names(2))
	r.show_result(false, STATS, _combos(2))
	r.finish_count()
	assert_eq(r.achievement_chip.size, Vector2(936, 96))
	assert_eq(
		r.achievement_chip.position.y,
		ResultScreen.Y_STRIP + ResultScreen.STRIP_H + ResultScreen.GAP
	)
	assert_gte(r.combo_panel.position.y, r.achievement_chip.position.y + 96.0 + ResultScreen.GAP)
	assert_eq(r.achievement_chip.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_b4_combo_lines_at_most_three_with_chip_and_plus_n() -> void:
	var r := _screen()
	r.set_new_achievements(_names(1))
	r.show_result(false, STATS, _combos(5))
	# v2.1 U6: satır azaltılmaz; "+N" satırı çocuk sayısına girer (3 satır + "+2" = 4 çocuk)
	assert_lte(r.combo_box.get_child_count(), 4, "özet varken kombo bloğu en çok 3 satır + '+N'")
	var rows := 0
	var plus := ""
	for c in r.combo_box.get_children():
		if c is HBoxContainer:
			rows += 1
		elif c is Label and (c as Label).text.begins_with("+"):
			plus = (c as Label).text
	assert_lte(rows, 3, "özet varken en çok 3 kombo satırı")
	assert_eq(plus, "+%d" % (5 - rows), "taşan kombolar '+N' olur")
	# 3 kombo özetle birlikte sığıyorsa hepsi görünür.
	var r3 := _screen()
	r3.set_new_achievements(_names(1))
	r3.show_result(false, STATS, _combos(3))
	assert_eq(r3.combo_box.get_child_count(), 3)


func test_m5_buttons_fit_with_chip_and_four_combos() -> void:
	var r := _screen()
	r.set_new_achievements(_names(2))
	r.show_result(false, STATS, _combos(4))
	assert_lte(r.content_bottom(), 2400.0 - 72.0)
	assert_gte(r.replay_button.position.y, 1500.0)


func test_m5_buttons_fit_with_chip_and_safe_area() -> void:
	var r := _screen()
	r.set_new_achievements(_names(2))
	r.show_result(false, STATS, _combos(4))
	# v2.1 U6: satır azaltma kalktı; çentik payı (üst 60, alt 40) kademelerle sığar (aşırı 100/150 payı sığmaz)
	r.apply_safe_area(Vector4(0, 60, 0, 40))
	assert_lte(r.content_bottom(), 2400.0 - 72.0 - 40.0)


func test_m5_detail_text_is_at_least_26() -> void:
	var r := _screen()
	r.show_result(true, STATS, [])
	for row in r.breakdown_rows:
		var det := row.get_node("Detail") as Label
		assert_gte(det.get_theme_font_size(&"font_size"), 26)
	var bottom := r.breakdown_panel.position.y + r.breakdown_panel.size.y
	assert_lte(bottom, ResultScreen.Y_STRIP, "döküm şerit başlamadan biter")


func test_b4_chip_enters_at_1100ms_with_200ms_slide() -> void:
	var r := _screen()
	r.set_new_achievements(_names(1))
	r.show_result(false, STATS, [])
	r._apply(1.0)
	assert_almost_eq(r.achievement_chip.modulate.a, 0.0, 1e-6)
	r._apply(1.4)
	assert_almost_eq(r.achievement_chip.modulate.a, 1.0, 1e-6)
	var base := ResultScreen.Y_COMBOS + r._dy
	assert_almost_eq(r.achievement_chip.position.y, base, 1e-4)
	r._apply(1.1 + 0.1)
	assert_between(r.achievement_chip.modulate.a, 0.01, 0.99)


func test_b4_tap_skip_shows_chip_immediately() -> void:
	var r := _screen()
	r.set_new_achievements(_names(1))
	r.show_result(false, STATS, [])
	r.finish_count()
	assert_almost_eq(r.achievement_chip.modulate.a, 1.0, 1e-6)


func test_b4_chip_title_and_names_font_sizes() -> void:
	var r := _screen()
	r.set_new_achievements(_names(2))
	assert_gte(r.chip_title.get_theme_font_size(&"font_size"), 26)
	assert_gte(r.chip_names.get_theme_font_size(&"font_size"), 26)
