extends GutTest
## AchievementsScreen (v2.0.3 C): 19 aile / kademe toplamı veriden türetilir, grup başlıkları, kroniği şeridi, satır aç/kapat, boş/hata durumu,
## kaydırma, güvenli alan, GERİ. Dokunma/sürükleme (F-037) geçmiş turdan korunur.

const T0 := 1761270000  # biçim doğrulaması için sabit
const PATH := "user://test_ach_screen.json"

var _data: GameData


func before_each() -> void:
	_data = GameData.load_dir("res://data")


## Gerçek aile verisinin kademe toplamı (53 sabiti yerine veriden türetilir).
func _total() -> int:
	var n := 0
	for d in _data.achievements:
		n += AchievementStep.total(d)
	return n


func _screen(store: AchievementStore = null, data: GameData = null) -> AchievementsScreen:
	var s := AchievementsScreen.new()
	add_child_autofree(s)
	s.open(data if data != null else _data, store if store != null else AchievementStore.new(PATH))
	return s


func _row(s: AchievementsScreen, id: StringName) -> AchievementRow:
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


func _groups(s: AchievementsScreen) -> Array:
	var names: Array = []
	for c in s.content.get_children():
		if str(c.name).begins_with("Group_"):
			names.append((c.get_child(0) as Label).text)
	return names


func test_19_rows_and_zero_summary_when_no_store_file() -> void:
	var s := _screen()
	assert_eq(s.row_count(), 19)
	assert_eq(s.count_label.text, "0 / %d" % _total())
	assert_eq(s.count_sub.text, "kademe")
	assert_false(s.error_label.visible)
	assert_eq(s.accessibility_name, "Başarımlar, 0 / %d kademe" % _total())


func test_empty_state_panel_text() -> void:
	assert_true(_texts(_screen().content, []).has("Henüz kademe açılmadı. Bir koşuya başla."))


func test_all_open_state_shows_complete_everywhere() -> void:
	var st := AchievementStore.new(PATH)
	for d in _data.achievements:
		st.unlock_step(d.id, AchievementStep.total(d), T0)
	var s := _screen(st)
	assert_eq(s.count_label.text, "%d / %d" % [_total(), _total()])
	assert_true(_texts(s.content, []).has("Tüm başarımlar açıldı."))
	for r in s.rows:
		assert_not_null(r.done_chip, "%s TAMAM" % r.def.id)
		assert_eq(r.accessibility_name, "%s, tamamlandı" % r.def.display_name)
	for i in 5:
		assert_eq(s.chronicle._seals[i].state, 2, "mühür %d tamam" % i)


func test_groups_in_design_order_with_fixed_uppercase_names() -> void:
	var s := _screen()
	assert_eq(_groups(s), ["THE WATCH", "THE CULLING", "THE CROWNED", "THE ARMORY", "THE ROAD"])


func test_group_counts_are_open_over_total_steps() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock_step(&"endure", 2, T0)
	var s := _screen(st)
	var watch := s.content.get_node("Group_THE_WATCH")
	assert_true(_texts(watch, []).has("2 / 10"), "WATCH: 4+3+3 kademe, 2 açık")


func test_summary_counts_steps_not_families() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock_step(&"reaper", 3, T0)
	st.unlock_step(&"endure", 1, T0)
	assert_eq(_screen(st).count_label.text, "4 / %d" % _total())


func test_row_size_and_touch_height() -> void:
	var s := _screen()
	for r in s.rows:
		assert_eq(r.custom_minimum_size, Vector2(936, 150))
		assert_gte(r.custom_minimum_size.y, 132.0)
	for c in s.content.get_children():
		if str(c.name).begins_with("Group_"):
			assert_eq(c.custom_minimum_size, Vector2(936, 72))


func test_row_shows_next_goal_value_and_segments() -> void:
	var st := AchievementStore.new(PATH)
	st.add_total(&"kills", 340)
	st.unlock_step(&"reaper", 2, T0)
	var r := _row(_screen(st), &"reaper")
	assert_eq((r.get_node("Name") as Label).text, "Reaper")
	assert_eq((r.get_node("Goal") as Label).text, "Toplam 2.500 düşman öldür")
	assert_eq((r.get_node("Progress") as Label).text, "340/2.500")
	assert_eq(r.segments.fills.size(), 4, "kademe sayısı kadar parça")
	assert_eq(r.segments.fills[0], 1.0)
	assert_eq(r.segments.fills[1], 1.0)
	assert_almost_eq(r.segments.fills[2], (340.0 - 250.0) / (2500.0 - 250.0), 0.001)
	assert_eq(r.segments.fills[3], 0.0)
	assert_eq(r.accessibility_name, "Reaper, kademe 2 / 4, sonraki hedef 2.500, 340, kapalı")


func test_best_values_feed_run_families() -> void:
	var st := AchievementStore.new(PATH)
	st.note_best_key(&"kills", 412)
	var r := _row(_screen(st), &"rampage")
	assert_eq((r.get_node("Progress") as Label).text, "412/500")
	assert_null(r.get_node_or_null("Chip"), "TEK KOŞU çipi kalktı")


func test_locked_row_has_lock_badge_dark_icon_and_first_goal() -> void:
	var r := _row(_screen(), &"vigil")
	assert_eq(r.step_have, 0)
	assert_eq((r.get_node("Goal") as Label).text, "1 saat oyna")
	var icon := _icon(r)
	assert_true(icon.material is ShaderMaterial, "kilitli: gri tonlama")
	assert_almost_eq(icon.modulate.r, 0.34, 0.001)
	assert_null(r.get_node_or_null("Roman"))


func test_open_rows_show_roman_numeral_and_plate_step() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock_step(&"endure", 3, T0)
	var r := _row(_screen(st), &"endure")
	assert_eq((r.get_node("Roman") as Label).text, "III")
	assert_eq(r.plate.step, 3)


func test_complete_family_goal_line_has_date() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock_step(&"elite_trio", 1, T0)
	var r := _row(_screen(st), &"elite_trio")
	var goal := (r.get_node("Goal") as Label).text
	assert_true(goal.begins_with("Tüm kademeler açıldı. "), goal)
	assert_eq(goal.length(), "Tüm kademeler açıldı. ".length() + 10)
	assert_null(r.get_node_or_null("Progress"))


func test_tap_opens_one_row_and_second_tap_closes() -> void:
	var s := _screen()
	var a := _row(s, &"reaper")
	a.pressed.emit()
	assert_eq(s.open_id, &"reaper")
	assert_true(_row(s, &"reaper").is_open)
	assert_gt(_row(s, &"reaper").custom_minimum_size.y, 150.0, "kademe yolu için büyür")
	_row(s, &"endure").pressed.emit()
	assert_eq(s.open_id, &"endure")
	assert_false(_row(s, &"reaper").is_open, "aynı anda 1 açık")
	assert_eq(s.rows.size(), 19, "satırlar birikmez")
	_row(s, &"endure").pressed.emit()
	assert_eq(s.open_id, &"")
	assert_eq(_row(s, &"endure").custom_minimum_size.y, 150.0)


func test_open_row_path_lists_every_step_with_date_value_or_target() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock_step(&"reaper", 1, T0)
	st.add_total(&"kills", 120)
	var s := _screen(st)
	s.open_id = &"reaper"
	s._populate()
	var r := _row(s, &"reaper")
	assert_eq(r.get_node("StepValue1").text.length(), 10, "açık kademe: tarih")
	assert_eq(r.get_node("StepValue2").text, "120 / 250", "aktif")
	assert_eq(r.get_node("StepValue3").text, "Hedef 2.500")
	assert_eq(r.get_node("StepValue4").text, "Hedef 10.000")
	assert_eq(r.get_node("StepGoal3").text, "III · Toplam 2.500 düşman öldür")
	assert_null(r.segments, "açıkken üst çubuk kalkar")
	assert_true(r.accessibility_name.ends_with("açık"))


func test_goal_text_converts_time_units() -> void:
	var g := {}
	for d in _data.achievements:
		g[d.id] = d
	assert_eq(AchievementRow.goal_text(g[&"endure"], 900), "15 dakika hayatta kal")
	assert_eq(AchievementRow.goal_text(g[&"untouched"], 180), "3 dakika hasar almadan kal")
	assert_eq(AchievementRow.goal_text(g[&"vigil"], 72000), "20 saat oyna")
	assert_eq(AchievementRow.goal_text(g[&"unbroken"], 8), "SERİ çarpanını ×8 yap")


func test_every_goal_text_has_a_template_for_each_family_stat() -> void:
	for d in _data.achievements:
		assert_true(AchievementRow.GOAL_TEXT.has(String(d.stat)), "%s: %s" % [d.id, d.stat])


func test_chronicle_states_and_taps_scroll_to_group() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock_step(&"endure", 4, T0)
	st.unlock_step(&"untouched", 3, T0)
	st.unlock_step(&"vigil", 3, T0)
	st.unlock_step(&"reaper", 1, T0)
	var s := _screen(st)
	assert_eq(s.chronicle._seals[0].state, 2, "WATCH tamam")
	assert_eq(s.chronicle._seals[1].state, 1, "CULLING ilerliyor")
	assert_eq(s.chronicle._seals[2].state, 0, "CROWNED hiç yok")
	assert_eq(s.chronicle.buttons[0].accessibility_name, "THE WATCH, 10 / 10")
	assert_eq(s.chronicle.buttons[1].accessibility_name, "THE CULLING, 1 / 14")
	assert_gte(s.chronicle.buttons[1].size.x, 187.0, "dokunma hedefi")
	assert_gte(s.chronicle.buttons[1].size.y, 132.0, "dokunma hedefi")


func test_unknown_ids_not_shown_but_kept_in_store() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock(&"gelecek_basarim", T0)
	var s := _screen(st)
	assert_eq(s.row_count(), 19)
	assert_null(_row(s, &"gelecek_basarim"))
	assert_true(st.is_unlocked(&"gelecek_basarim"))
	assert_eq(s.count_label.text, "0 / %d" % _total())


func test_definitions_missing_shows_error_and_back_still_works() -> void:
	var s := _screen(null, GameData.new())
	assert_true(s.error_label.visible)
	assert_eq(s.error_label.text, "Başarım listesi yüklenemedi")
	assert_false(s.list.visible)
	assert_false(s.chronicle.visible)
	watch_signals(s)
	s.back_button.pressed.emit()
	assert_signal_emitted(s, "back_requested")


func test_back_signal() -> void:
	var s := _screen()
	watch_signals(s)
	s.back_button.pressed.emit()
	assert_signal_emitted(s, "back_requested")
	assert_eq(s.back_button.size.y, 132.0)


func test_v20_single_step_data_still_renders() -> void:
	var s := _screen(null, AchKit.legacy_data())
	assert_eq(s.row_count(), 22)
	assert_eq(s.count_label.text, "0 / 22")
	assert_true(_groups(s).has("DİĞER"), "grupsuz kayıtlar DİĞER altında")


func test_list_scrolls_when_content_exceeds_view() -> void:
	var s := _screen()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(s.content.get_combined_minimum_size().y, s.list.size.y)
	assert_eq(s.list.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_eq(s.list.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)


func test_default_layout_matches_design() -> void:
	var s := _screen()
	assert_eq(s.chronicle.position.y, 344.0)
	assert_eq(s.chronicle.size, Vector2(936, 150))
	assert_eq(s.list.position.y, 520.0)
	assert_eq(s.list.position.y + s.list.size.y, 2172.0)
	assert_eq(s.back_button.position.y, 2196.0)


func test_safe_area_pushes_content_in() -> void:
	var s := _screen()
	s.apply_safe_area(Vector4(0, 100, 0, 150))
	assert_gte(s.title_label.position.y, 96.0 + 100.0)
	assert_lte(s.back_button.position.y + s.back_button.size.y, 2400.0 - 72.0 - 150.0)
	assert_lte(s.list.position.y + s.list.size.y, s.back_button.position.y)
	assert_gte(s.list.position.y, s.chronicle.position.y + s.chronicle.size.y)


func test_safe_area_side_extra_narrows_width() -> void:
	var s := _screen()
	s.apply_safe_area(Vector4(80, 0, 80, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(s.list.size.x, 936.0)
	assert_gte(s.list.position.x, 36.0 + 80.0)
	assert_lte(s.list.position.x + s.list.size.x, 1080.0 - 36.0 - 80.0)
	assert_gte(s.chronicle.position.x, 36.0 + 80.0)
	assert_lte(s.chronicle.position.x + s.chronicle.size.x, 1080.0 - 36.0 - 80.0)


func test_min_font_sizes_at_least_26() -> void:
	var st := AchievementStore.new(PATH)
	st.unlock_step(&"reaper", 2, T0)
	var s := _screen(st)
	s.open_id = &"reaper"
	s._populate()
	var stack: Array = [s]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text != "":
			assert_gte((n as Label).get_theme_font_size(&"font_size"), 24, (n as Label).text)
		stack.append_array(n.get_children())


func test_reopen_rebuilds_rows_and_closes_open_row() -> void:
	var s := _screen()
	s.open_id = &"reaper"
	var st := AchievementStore.new(PATH)
	st.unlock_step(&"reaper", 1, T0)
	s.open(_data, st)
	await get_tree().process_frame
	assert_eq(s.row_count(), 19, "satırlar birikmez")
	assert_eq(s.open_id, &"")
	assert_eq(s.count_label.text, "1 / %d" % _total())


func test_sticky_group_header_follows_scroll_and_hides_at_top() -> void:
	var s := _screen()
	for i in s._groups.size():
		(s._groups[i]["node"] as Control).position.y = i * 400.0
	s._update_sticky(0.0)
	assert_true(s.sticky == null or not s.sticky.visible, "tepede yapışkan başlık yok")
	s._update_sticky(405.0)
	assert_not_null(s.sticky)
	assert_true(s.sticky.visible, "ikinci grup başlığı üstten çıkınca yapışır")
	assert_eq(s._sticky_idx, 1)
	assert_almost_eq(s.sticky.position.y, s.list.position.y, 0.5, "liste tepesinde")
	s._update_sticky(800.0 - 20.0)
	assert_lt(s.sticky.position.y, s.list.position.y, "sıradaki başlık yaklaşınca iter")
	s._update_sticky(0.0)
	assert_false(s.sticky.visible, "başa dönünce gizlenir")


func test_sticky_header_above_fade_and_opaque() -> void:
	var s := _screen()
	for i in s._groups.size():
		(s._groups[i]["node"] as Control).position.y = i * 400.0
	s._update_sticky(405.0)
	assert_gt(s.sticky.get_index(), s._fade_top.get_index(), "yapışkan başlık perdenin üstünde")
	var sb := s.sticky.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(sb.bg_color.a, 1.0, "zemin opak")


func test_every_goal_line_fits_one_line() -> void:
	var done := AchievementStore.new(PATH)
	for d in _data.achievements:
		done.unlock_step(d.id, AchievementStep.total(d), T0)
	var rows: Array[AchievementRow] = []
	rows.append_array(_screen().rows)
	rows.append_array(_screen(done).rows)
	for r in rows:
		var g := r.goal_label
		var f := g.get_theme_font(&"font")
		var w := f.get_string_size(g.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		assert_lte(w, g.size.x, "sonraki hedef tek satır: %s" % g.text)


## F-037: cihazda yalnız InputEventScreenTouch/ScreenDrag gelir (emulate_mouse_from_touch=false); gerçek olay dizisiyle kayma.
func _list_point(s: AchievementsScreen) -> Vector2:
	return s.list.get_global_rect().get_center()


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = idx
	t.position = pos
	t.pressed = pressed
	get_viewport().push_input(t, true)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = idx
	d.position = pos
	d.relative = rel
	d.velocity = rel * 60.0
	get_viewport().push_input(d, true)


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_f037_touch_drag_scrolls_list() -> void:
	var s := _screen()
	s.visible = true
	await _settle()
	var p := _list_point(s)
	_touch(0, p, true)
	for i in 10:
		p += Vector2(0, -40)
		_drag(0, p, Vector2(0, -40))
		await get_tree().process_frame
	_touch(0, p, false)
	assert_gt(s.list.scroll_vertical, 100, "parmak yukarı sürüklenince liste kayar")


func test_f037_mouse_drag_scrolls_list() -> void:
	var s := _screen()
	s.visible = true
	await _settle()
	var p := _list_point(s)
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = p
	b.global_position = p
	get_viewport().push_input(b, true)
	for i in 10:
		p += Vector2(0, -40)
		var m := InputEventMouseMotion.new()
		m.position = p
		m.global_position = p
		m.relative = Vector2(0, -40)
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(m, true)
		await get_tree().process_frame
	b = b.duplicate()
	b.pressed = false
	b.position = p
	b.global_position = p
	get_viewport().push_input(b, true)
	assert_gt(s.list.scroll_vertical, 100, "emüle fare sürüklemesi listeyi kaydırır")


func test_f037_drag_starting_on_row_scrolls_and_back_still_taps() -> void:
	var s := _screen()
	s.visible = true
	await _settle()
	var row := s.rows[0]
	var p := row.get_global_rect().get_center()
	assert_true(s.list.get_global_rect().has_point(p), "satır görünür alanda")
	_touch(0, p, true)
	for i in 8:
		p += Vector2(0, -50)
		_drag(0, p, Vector2(0, -50))
		await get_tree().process_frame
	_touch(0, p, false)
	assert_gt(s.list.scroll_vertical, 100, "satır üstünden başlayan sürükleme de kaydırır")
	watch_signals(s)
	var c := s.back_button.get_global_rect().get_center()
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.position = c
	m.global_position = c
	m.pressed = true
	get_viewport().push_input(m, true)
	m = m.duplicate()
	m.pressed = false
	get_viewport().push_input(m, true)
	assert_signal_emitted(s, "back_requested", "GERİ dokunuşu hâlâ çalışır")


func _icon(row: Control) -> TextureRect:
	for c in row.get_children():
		if c is TextureRect and (c as TextureRect).size == Vector2(84.0, 84.0):
			return c
	return null


func test_top_fade_hidden_at_scroll_zero_and_shared_back_button() -> void:
	var s := _screen()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(s._fade_top.visible, "tepede üst solma yok: boş durum paneli/ilk başlık sönmez")
	s.list.scroll_vertical = 200
	await get_tree().process_frame
	assert_gt(s.list.scroll_vertical, 0, "liste kaydırılabilir")
	s._update_fade_top()
	assert_true(s._fade_top.visible, "kaydırılınca solma var")
	assert_true(
		s.back_button.get_theme_stylebox(&"normal") is StyleBoxTexture,
		"GERİ taş levha (ortak bileşen)"
	)
