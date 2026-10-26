extends GutTest
## v2.0.3 D: yeniden tasarlanan ayarlar ekranı ve ana sayfa hareketi (docs/design/v2.0.3/DESIGN.md §2, §3, §6).

const TMP := "user://test_v203_d_settings.cfg"

var st: Node
var _saved := {}


func before_each() -> void:
	st = get_node(^"/root/Settings")
	_saved = {
		"path": st.store_path,
		"snd": st.sound_on,
		"ha": st.hareket_azalt,
		"m": st.music_pct,
		"s": st.sfx_pct,
		"vib": st.vibration_on
	}
	st.store_path = TMP
	st.sound_on = true
	st.hareket_azalt = false
	st.apply_audio()


func after_each() -> void:
	st.store_path = _saved["path"]
	st.sound_on = _saved["snd"]
	st.hareket_azalt = _saved["ha"]
	st.music_pct = _saved["m"]
	st.sfx_pct = _saved["s"]
	st.vibration_on = _saved["vib"]
	st.apply_audio()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _screen() -> SettingsScreen:
	var sc := SettingsScreen.new()
	add_child_autofree(sc)
	sc.open()
	return sc


func test_d1_sections_follow_design_order_with_prefixed_names() -> void:
	var sc := _screen()
	var got: Array[String] = []
	for c in sc.column.get_children():
		got.append(c.name)
	var want: Array[String] = []
	for id in SettingsSections.IDS:
		want.append(SettingsSections.node_name(id))
	assert_eq(got, want)


func test_d2_every_previous_option_is_still_there() -> void:
	var sc := _screen()
	assert_not_null(sc.music_slider)
	assert_not_null(sc.sfx_slider)
	assert_not_null(sc.vibration_button)
	watch_signals(sc)
	sc.vibration_button.pressed.emit()
	assert_signal_emitted_with_parameters(sc, "vibration_toggled", [false])
	sc.back_button.pressed.emit()
	assert_signal_emitted(sc, "back_requested")


func test_d3_hareket_azalt_toggle_writes_settings_and_defaults_off() -> void:
	var sc := _screen()
	assert_false(st.hareket_azalt, "varsayılan KAPALI")
	watch_signals(sc)
	sc.hareket_button.pressed.emit()
	assert_true(st.hareket_azalt)
	assert_signal_emitted_with_parameters(sc, "hareket_azalt_toggled", [true])
	assert_eq(sc.hareket_button.accessibility_name, "Hareketi azalt, açık")
	sc.hareket_button.pressed.emit()
	assert_false(st.hareket_azalt)


func test_d4_master_sound_toggle_dims_sliders_and_slider_touch_reenables() -> void:
	var sc := _screen()
	sc.sound_button.pressed.emit()
	assert_false(st.sound_on)
	assert_true(sc.muted_note.visible, "Ses kapalı satırı")
	sc.sfx_slider.value = 40
	assert_true(st.sound_on, "kaydırıcıya dokunmak ana anahtarı açar")
	assert_false(sc.muted_note.visible)


func test_d5_rows_are_at_least_132_tall_and_texts_are_uppercase_turkish() -> void:
	var sc := _screen()
	for b in [sc.sound_button, sc.vibration_button, sc.hareket_button]:
		assert_gte((b as Button).custom_minimum_size.y, 132.0)
	assert_eq(sc.title_label.text, "AYARLAR")
	assert_eq(SettingsScreen.SECTION_TITLES[&"dokunus"], "DOKUNUŞ")
	assert_eq(sc.back_button.text, "GERİ")


func test_d6_safe_area_title_list_and_back_stay_inside() -> void:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var sc := SettingsScreen.new()
	host.add_child(sc)
	sc.open()
	await get_tree().process_frame
	var e := Vector4(40, 130, 20, 150)
	sc.apply_safe_area(e)
	await get_tree().process_frame
	assert_gte(sc.title_label.get_global_rect().position.y, 96.0 + e.y - 0.5)
	assert_gte(sc.scroll.get_global_rect().position.y, 250.0 + e.y - 0.5)
	assert_lte(sc.back_button.get_global_rect().end.y, 2400.0 - 72.0 - e.w + 0.5)
	assert_lte(sc.scroll.get_global_rect().end.y, sc.back_button.get_global_rect().position.y)
	assert_gte(
		sc.back_button.get_global_rect().position.x, UiKit.SIDE + e.x * 0.5 - e.z * 0.5 - 0.5
	)
	assert_eq(sc.back_button.get_global_rect().size.y, 132.0)
	sc.apply_safe_area(Vector4.ZERO)
	await get_tree().process_frame
	assert_almost_eq(sc.back_button.get_global_rect().position.y, 2196.0, 0.5)


func test_d7_version_comes_from_project_setting() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/version"), "2.0.3")
	assert_eq(MainMenu.version_text(), "Sürüm 2.0.3")
	assert_eq(SettingsScreen.version_text(), "2.0.3")


func test_d8_menu_reduce_motion_stops_embers_and_breath() -> void:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var m := MainMenu.new()
	host.add_child(m)
	await get_tree().process_frame
	assert_lte(m.embers.amount, 40, "tasarım tavanı 40 parçacık")
	assert_true(m.embers.emitting)
	st.set_hareket_azalt(true)
	assert_false(m.embers.emitting, "ayar değişince anında durur")
	assert_false(m.embers.visible)
	m._process(1.0)
	if m.hero != null:
		assert_eq(m.hero.scale, Vector2.ONE, "nefes durur")
	st.set_hareket_azalt(false)
	assert_true(m.embers.visible)


func test_d9_licenses_row_opens_subscreen_and_back_returns_to_settings() -> void:
	var sc := _screen()
	assert_false(sc.licenses.visible)
	sc.licenses_button.pressed.emit()
	assert_true(sc.licenses.visible)
	for r in SettingsScreen.LICENSE_ROWS:
		assert_true(AchKit.any_text_contains(sc.licenses, r[0]), r[0])
	assert_true(AchKit.any_text_contains(sc.licenses, "LICENSES-audio.md"))
	watch_signals(sc)
	sc.close()  # Android geri: yalnız alt ekran kapanır
	assert_false(sc.licenses.visible)
	assert_true(sc.visible, "ayarlar açık kalır")
	assert_signal_not_emitted(sc, "back_requested")
	sc.licenses_button.pressed.emit()
	sc.lic_back_button.pressed.emit()
	assert_false(sc.licenses.visible)
	assert_true(sc.visible)


func test_d10_licenses_subscreen_respects_safe_area() -> void:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var sc := SettingsScreen.new()
	host.add_child(sc)
	sc.open()
	sc.licenses_button.pressed.emit()
	sc.apply_safe_area(Vector4(0, 130, 0, 150))
	await get_tree().process_frame
	assert_lte(sc.lic_back_button.get_global_rect().end.y, 2400.0 - 72.0 - 150.0 + 0.5)
	assert_gte(sc.licenses.find_child("*", true, false).get_global_rect().position.y, 0.0)


func test_d11_switch_fades_in_140ms_and_is_instant_with_reduced_motion() -> void:
	var sc := _screen()
	var sw := sc.vibration_button.get_meta(&"switch") as SettingsScreen.Switch
	sc.vibration_button.pressed.emit()
	assert_eq(sw.plate.get_child_count(), 1, "eski mühür solarak kalır")
	await get_tree().create_timer(SettingsScreen.SWITCH_SEC + 0.1).timeout
	assert_eq(sw.plate.get_child_count(), 0, "140 ms sonra temizlenir")
	st.set_hareket_azalt(true)
	sc.vibration_button.pressed.emit()
	assert_eq(sw.plate.get_child_count(), 0, "hareket azalt açık: anlık")


func test_d12_big_font_scale_stacks_half_buttons_in_one_column_without_clipping() -> void:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var m := MainMenu.new()
	host.add_child(m)
	await get_tree().process_frame
	assert_false(m.is_stacked())
	m.set_font_scale(2.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(m.is_stacked())
	var prev_end := m.play_button.get_global_rect().end.y
	for b in [m.characters_button, m.achievements_button, m.scores_button, m.settings_button]:
		var r := (b as Button).get_global_rect()
		assert_almost_eq(r.size.x, 936.0, 1.0, "%s tam genişlik" % b.name)
		assert_gte(r.size.y, 168.0 - 0.5, b.name)
		assert_gte(r.position.y, prev_end + 27.0 - 1.0, "%s üstündekiyle örtüşmez" % b.name)
		prev_end = r.end.y
	assert_lte(m.version_label.get_global_rect().end.y, 2400.0 - 72.0 + 0.5)
	if m.hero != null:
		var hr := m.hero.get_global_rect()
		assert_almost_eq(hr.size.x, 512.0, 1.0, "karakter %80")
		assert_lte(hr.end.y, m.play_button.get_global_rect().position.y)
		assert_gte(hr.position.y, m._head.get_global_rect().position.y + 300.0, "başlığın altında")
	m.set_font_scale(1.0)
	await get_tree().process_frame
	assert_almost_eq(m.play_button.global_position.y, 1763.0, 0.5, "1× düzen geri gelir")
