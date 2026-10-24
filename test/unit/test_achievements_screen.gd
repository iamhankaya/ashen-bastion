extends GutTest
## AchievementsScreen (B4): 22 satır, gruplar, ilerleme/tarih/TEK KOŞU, boş/hata durumu, kaydırma, güvenli alan, GERİ.

const T0 := 1761270000  # 24.10.2026 civarı; yalnız biçim doğrulanır
const PATH := "user://test_ach_screen.json"

var _data: GameData


func before_each() -> void:
	_data = GameData.load_default()


func _screen(store: AchievementStore = null, data: GameData = null) -> AchievementsScreen:
	var s := AchievementsScreen.new()
	add_child_autofree(s)
	s.open(data if data != null else _data, store if store != null else AchievementStore.new(PATH))
	return s


func _row(s: AchievementsScreen, id: StringName) -> Control:
	for r in s.rows:
		if r.get_meta(&"id") == id:
			return r
	return null


func _texts(n: Node, out: Array) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)
	return out


func test_b6_22_rows_and_summary_zero_when_no_store_file() -> void:
	var s := _screen()
	assert_eq(s.row_count(), 22)
	assert_eq(s.count_label.text, "0 / 22")
	assert_false(s.error_label.visible, "hata iletisi yok")


func test_b6_empty_state_panel_text() -> void:
	var s := _screen()
	var texts := _texts(s.content, [])
	assert_true(texts.has("Henüz açılan başarım yok. Bir koşuya başla."))


func test_b6_all_open_state() -> void:
	var st := AchievementStore.new(PATH)
	for d in _data.achievements:
		st.unlock(d.id, T0)
	var s := _screen(st)
	assert_eq(s.count_label.text, "22 / 22")
	assert_true(_texts(s.content, []).has("Tüm başarımlar açıldı."))
	assert_eq((s.bar as AchievementsScreen.Bar).done, true)


func test_b6_row_size_and_touch_height() -> void:
	var s := _screen()
	for r in s.rows:
		assert_eq(r.custom_minimum_size, Vector2(936, 156))
		assert_gte(r.custom_minimum_size.y, 132.0)
	for c in s.content.get_children():
		if str(c.name).begins_with("Group"):
			assert_eq(c.custom_minimum_size, Vector2(936, 72))


func test_b6_groups_in_tier_order_with_counts() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock(&"ilk_kan", T0)
	var s := _screen(st)
	var names: Array = []
	for c in s.content.get_children():
		if str(c.name).begins_with("Group"):
			names.append((c.get_child(0) as Label).text)
	assert_eq(names, ["KOLAY", "ORTA", "ZOR", "ÇOK ZOR"])
	var kolay := s.content.get_node("Group0")
	assert_true(_texts(kolay, []).has("1 / 6"))


func test_b6_open_rows_first_within_group_and_have_date() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock(&"alti_silah", T0)  # kolay grubun SON tanımı
	var s := _screen(st)
	assert_eq(s.rows[0].get_meta(&"id"), &"alti_silah", "grup içi: açıklar önce")
	var date := (s.rows[0].get_node("Date") as Label).text
	assert_eq(date.length(), 10)
	assert_eq(date[2], ".")
	assert_eq(date[5], ".")


func test_b6_progress_text_value_over_target() -> void:
	var st := AchievementStore.new(PATH)
	st.add_total(&"kills", 340)
	var s := _screen(st)
	assert_eq((_row(s, &"kalabalik_kesici").get_node("Progress") as Label).text, "340/10.000")


func test_b6_progress_over_target_clamped_to_target() -> void:
	var st := AchievementStore.new(PATH)
	st.add_total(&"runs", 9)  # hedef 10 -> 9/10
	st.note_best(0, 0, 14)  # seviye_20 hedefi 20 -> 14/20, seviye_10 açılmadı ama 14 > 10
	var s := _screen(st)
	assert_eq((_row(s, &"yerlesik").get_node("Progress") as Label).text, "9/10")
	assert_eq(
		(_row(s, &"seviye_10").get_node("Progress") as Label).text,
		"10/10",
		"hedefi aşan hedef/hedef"
	)


func test_b6_single_run_chip_for_sources_without_progress() -> void:
	var s := _screen()
	var r := _row(s, &"kirim")
	assert_eq((r.get_node("Chip") as Label).text, "TEK KOŞU")
	assert_eq((r.get_node("Goal") as Label).text, "Hedef 500")
	assert_null(r.get_node_or_null("Progress"))


func test_b6_unknown_ids_not_shown_but_kept_in_store() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock(&"gelecek_basarim", T0)
	var s := _screen(st)
	assert_eq(s.row_count(), 22)
	assert_null(_row(s, &"gelecek_basarim"))
	assert_true(st.is_unlocked(&"gelecek_basarim"))
	assert_eq(s.count_label.text, "0 / 22")


func test_b6_definitions_missing_shows_error_and_back_still_works() -> void:
	var s := _screen(null, GameData.new())
	assert_true(s.error_label.visible)
	assert_eq(s.error_label.text, "Başarım listesi yüklenemedi")
	assert_false(s.list.visible)
	watch_signals(s)
	s.back_button.pressed.emit()
	assert_signal_emitted(s, "back_requested")


func test_b6_back_signal() -> void:
	var s := _screen()
	watch_signals(s)
	s.back_button.pressed.emit()
	assert_signal_emitted(s, "back_requested")
	assert_eq(s.back_button.size.y, 132.0)


func test_b6_list_scrolls_when_content_exceeds_view() -> void:
	var s := _screen()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(
		s.content.get_combined_minimum_size().y, s.list.size.y, "22 satır görünür alandan uzun"
	)
	assert_eq(s.list.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_eq(s.list.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)


func test_b6_default_layout_matches_design() -> void:
	var s := _screen()
	assert_eq(s.list.position.y, 400.0)
	assert_eq(s.list.position.y + s.list.size.y, 2172.0)
	assert_eq(s.back_button.position.y, 2196.0)
	assert_eq(s.bar.size, Vector2(936, 20))
	assert_eq(s.bar.position.y, 340.0)


func test_b6_safe_area_pushes_content_in() -> void:
	var s := _screen()
	s.apply_safe_area(Vector4(0, 100, 0, 150))
	assert_gte(s.title_label.position.y, 96.0 + 100.0)
	assert_gte(s.list.position.y, 400.0)
	assert_lte(s.back_button.position.y + s.back_button.size.y, 2400.0 - 72.0 - 150.0)
	assert_lte(s.list.position.y + s.list.size.y, s.back_button.position.y)
	assert_gte(s.list.position.y, s.bar.position.y + s.bar.size.y)


func test_b6_safe_area_side_extra_narrows_width() -> void:
	var s := _screen()
	s.apply_safe_area(Vector4(80, 0, 80, 0))
	await get_tree().process_frame  # en küçük boyutlar bir kare sonra güncellenir
	await get_tree().process_frame
	assert_lte(s.list.size.x, 936.0)
	assert_gte(s.list.position.x, 36.0 + 80.0)
	assert_lte(s.list.position.x + s.list.size.x, 1080.0 - 36.0 - 80.0)


func test_b6_min_font_sizes_at_least_26() -> void:
	var s := _screen()
	var st := AchievementStore.new(PATH)
	st.unlock(&"ilk_kan", T0)
	s.open(_data, st)
	var stack: Array = [s]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text != "":
			assert_gte((n as Label).get_theme_font_size(&"font_size"), 26, (n as Label).text)
		stack.append_array(n.get_children())


func test_b6_reopen_rebuilds_rows() -> void:
	var s := _screen()
	var st := AchievementStore.new(PATH)
	st.unlock(&"ilk_kan", T0)
	s.open(_data, st)
	await get_tree().process_frame
	assert_eq(s.row_count(), 22, "satırlar birikmez")
	assert_eq(s.count_label.text, "1 / 22")


func test_b6_accessibility_names() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock(&"ilk_kan", T0)
	st.add_total(&"runs", 6)
	var s := _screen(st)
	assert_true(_row(s, &"ilk_kan").accessibility_name.begins_with("İlk Kan, açıldı "))
	assert_eq(_row(s, &"yerlesik").accessibility_name, "Yerleşik, kilitli, 6 / 10")
	assert_eq(s.accessibility_name, "Başarımlar, 1 / 22 açıldı")
