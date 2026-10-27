extends GutTest
## v2.1 U6 denetim düzeltmeleri, skorlar ekranı (#1 taş dili, #2 2× yazı + kaydırma, #6 sekme glifi, #11 YENİ ≥26).
## Godot yerelde koşmaz: CI.

var _saved_big: Variant = null


func before_each() -> void:
	var st := get_node_or_null(^"/root/Settings")
	if st != null:  # ekran yazı ölçeğini gerçek Settings'ten okur: testten önce sabitle, sonra geri al
		_saved_big = st.buyuk_yazi
		st.buyuk_yazi = false


func after_each() -> void:
	var st := get_node_or_null(^"/root/Settings")
	if st != null and _saved_big != null:
		st.buyuk_yazi = _saved_big


func _entry(score: int) -> Dictionary:
	return {"score": score, "time": 600, "won": true, "level": 5, "unix": 1_700_000_000}


func _ten() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for i in 10:
		list.append(_entry(1_234_567 - i))
	return list


func _scores(entries: Array[Dictionary], highlight := -1) -> HighscoreScreen:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var s := HighscoreScreen.new()
	host.add_child(s)
	s.show_scores(entries, highlight)
	return s


func _inner(s: HighscoreScreen, i: int, node: String) -> Control:
	return (s.rows[i].get_node("Inner") as Control).get_node(node) as Control


func _fs(c: Control) -> int:
	return c.get_theme_font_size(&"font_size")


func _rect(c: Control) -> Rect2:
	return Rect2(c.position, c.size)


# #1: MOR_900 zemin/MOR_800 satır varken kırmızı.
func test_b60_scores_screen_uses_stone_surface_not_purple() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/highscore_screen.gd")
	assert_false(src.contains("MOR_"), "mor ailesi kalmamalı")
	var s := _scores(_ten())
	var bg: ColorRect = null
	for c in s.get_children():
		if c is ColorRect:
			bg = c
			break
	assert_not_null(bg)
	assert_eq(bg.color, UiKit.TAS_900)


# #6: set_selected glifi güncellemeden kırmızı.
func test_b61_selected_tab_glyph_is_bronz_300_unselected_bronz_500() -> void:
	var s := _scores(_ten())
	var on := s.mode_tabs[1].get_child(0).get_child(0) as Control
	var off := s.mode_tabs[0].get_child(0).get_child(0) as Control
	assert_eq(on.get(&"color"), UiKit.BRONZ_300)
	assert_eq(off.get(&"color"), UiKit.BRONZ_500)
	s.select_tab(&"quick", &"hard")
	assert_eq((s.mode_tabs[0].get_child(0).get_child(0) as Control).get(&"color"), UiKit.BRONZ_300)
	assert_eq(on.get(&"color"), UiKit.BRONZ_500)
	assert_eq((s.diff_tabs[2].get_child(0).get_child(0) as Control).get(&"color"), UiKit.BRONZ_300)


# #11: YENİ 22 px ve 90×34 kutu iken kırmızı.
func test_b62_new_tag_is_at_least_26_and_clear_of_date_in_both_scales() -> void:
	var s := _scores(_ten(), 0)
	for big in [false, true]:
		s.set_font_scale(2.0 if big else 1.0)
		var tag := _inner(s, 0, "New") as Label
		var date := _inner(s, 0, "Date")
		assert_gte(_fs(tag), 26)
		assert_gte(tag.size.y, 26.0)
		assert_false(_rect(tag).intersects(_rect(date)), "YENİ tarihle çakışmaz (büyük=%s)" % big)
		assert_gte(tag.position.x, 0.0)
		assert_lte(tag.position.x + tag.size.x, s._w)
		assert_lte(tag.position.y + tag.size.y, s.rows[0].size.y)


# #2: set_font_scale/is_big/scroll yokken kırmızı.
func test_b63_big_text_tab_labels_40_rows_156_and_list_scrolls() -> void:
	var s := _scores(_ten())
	assert_false(s.is_big())
	assert_eq(s.mode_tabs[0].label_size(), 34)
	assert_eq(s.rows[0].get_parent(), s, "1× yerleşim: satırlar ekranın doğrudan çocuğu")
	s.set_font_scale(2.0)
	assert_true(s.is_big())
	assert_eq(s.mode_tabs[0].label_size(), 40)
	assert_eq(s.diff_tabs[2].label_size(), 40)
	assert_eq(s.rows[0].size.y, HighscoreScreen.ROW_H)
	assert_eq(s.rows[9].size.y, HighscoreScreen.ROW_H, "pitch sıkıştırılmaz")
	assert_eq(s.rows[1].position.y - s.rows[0].position.y, 168.0)
	var scroll := s.list_scroll
	assert_not_null(scroll)
	assert_eq(s.rows[0].get_parent().get_parent(), scroll, "satırlar kaydırma kabının içeriğinde")
	assert_true(scroll.visible)
	assert_lt(scroll.size.y, 10.0 * 168.0 - 12.0, "10 satır sığmaz: kayar")
	assert_lte(scroll.position.y + scroll.size.y, s.back_button.position.y, "GERİ sabit ve açık")
	assert_eq(s.mode_tabs[0].size.y, HighscoreScreen.TAB_H)
	s.set_font_scale(1.0)
	assert_false(s.is_big())
	assert_eq(s.rows[0].get_parent(), s)
	assert_eq(s.mode_tabs[0].label_size(), 34)
	assert_false(scroll.visible)


# #2: satır içi yazı büyümeden kırmızı; kutular satıra sığar.
func test_b64_big_row_text_grows_and_fits_inside_156() -> void:
	var s := _scores(_ten())
	var small := [_fs(_inner(s, 0, "Score")), _fs(_inner(s, 0, "Time")), _fs(_inner(s, 0, "Date"))]
	var chip_small := (_inner(s, 0, "Chip") as HighscoreScreen.ResultChip).font_px()
	s.set_font_scale(2.0)
	assert_gt(_fs(_inner(s, 0, "Score")), small[0])
	assert_gt(_fs(_inner(s, 0, "Time")), small[1])
	assert_gt(_fs(_inner(s, 0, "Date")), small[2])
	var chip := _inner(s, 0, "Chip") as HighscoreScreen.ResultChip
	assert_gt(chip.font_px(), chip_small)
	for n in ["Rank", "Score", "Chip", "Time", "Date"]:
		var c := _inner(s, 0, n)
		assert_gte(c.position.y, 0.0, n)
		assert_lte(c.position.y + c.size.y, HighscoreScreen.ROW_H, n)
		assert_lte(c.position.x + c.size.x, s._w, n)
	var score := _rect(_inner(s, 0, "Score"))
	var chip_r := _rect(chip)
	var time := _rect(_inner(s, 0, "Time"))
	var date := _rect(_inner(s, 0, "Date"))
	assert_false(score.intersects(chip_r))
	assert_false(score.intersects(date))
	assert_false(chip_r.intersects(time))
	assert_false(time.intersects(date))


# #2: ekran görününce Settings'ten okur.
func test_b65_reads_font_scale_from_settings_on_show() -> void:
	var st := get_node_or_null(^"/root/Settings")
	if st == null:
		pending("Settings autoload yok")
		return
	st.buyuk_yazi = true
	var s := _scores(_ten())
	assert_eq(s.is_big(), st.font_scale() > 1.3)
