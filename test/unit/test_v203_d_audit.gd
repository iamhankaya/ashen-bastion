extends GutTest
## v2.0.3 D düzeltme turu (ara denetim T20261026-65, docs/design/audit/v2.0.3-ara/FINDINGS.md): #1 BÜYÜK YAZI kaynağı ve
## ayarlar 2× düzeni, #2 lisans kartı kayar, #3 çizili hoparlör, #4 mini portre, #5 2× tek sütun hizası ve zemin yaması kırpması.

const TMP := "user://test_v203_d_audit.cfg"

var st: Node
var _saved := {}


func before_each() -> void:
	st = get_node(^"/root/Settings")
	_saved = {
		"path": st.store_path, "snd": st.sound_on, "big": st.buyuk_yazi, "ha": st.hareket_azalt
	}
	st.store_path = TMP
	st.sound_on = true
	st.buyuk_yazi = false
	st.hareket_azalt = false
	st.apply_audio()


func after_each() -> void:
	st.store_path = _saved["path"]
	st.sound_on = _saved["snd"]
	st.buyuk_yazi = _saved["big"]
	st.hareket_azalt = _saved["ha"]
	st.apply_audio()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	return host


func test_d20_buyuk_yazi_is_saved_and_old_files_default_to_off() -> void:
	st.set_buyuk_yazi(true)
	assert_eq(st.font_scale(), 2.0)
	st.buyuk_yazi = false
	st.load_settings(TMP)
	assert_true(st.buyuk_yazi, "kayıttan okunur")
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string('{"ses": true}')
	f.close()
	st.load_settings(TMP)
	assert_false(st.buyuk_yazi, "eski dosya: kapalı")
	assert_eq(st.font_scale(), 1.0)


func test_d21_toggle_in_settings_stacks_menu_and_enlarges_settings() -> void:
	var host := _host()
	var m := MainMenu.new()
	host.add_child(m)
	var sc := SettingsScreen.new()
	host.add_child(sc)
	sc.open()
	await get_tree().process_frame
	assert_false(m.is_stacked())
	assert_false(sc.is_big())
	sc.buyuk_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(st.buyuk_yazi)
	assert_true(sc.is_big(), "ayarlar 2× düzeni")
	assert_true(m.is_stacked(), "ana sayfa tek sütun")
	# 2× düzen: etiket 72; kaydırıcıların tamamı hâlâ var, anahtar etiketin altında
	var cap_row := sc.sound_button.find_child("Speaker", true, false).get_parent()
	assert_eq((cap_row.get_child(1) as Label).get_theme_font_size(&"font_size"), 72)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lt((cap_row.get_child(1) as Label).size.y, 120.0, "başlık tek satır (harf harf sarmaz)")
	var cap := sc.hareket_button.get_child(0).get_child(0) as Label
	var sw := sc.hareket_button.get_meta(&"switch") as Control
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(
		sw.get_global_rect().position.y,
		cap.get_global_rect().end.y - 1.0,
		"anahtar etiketin altında"
	)
	assert_gte(sc.hareket_button.size.y, 132.0)
	sc.buyuk_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(sc.is_big())
	assert_false(m.is_stacked())


func test_d22_big_settings_keep_back_fixed_and_list_scrolls() -> void:
	var host := _host()
	var sc := SettingsScreen.new()
	host.add_child(sc)
	st.set_buyuk_yazi(true)
	sc.open()
	for i in 4:
		await get_tree().process_frame
	assert_true(sc.is_big())
	assert_gt(
		sc.column.get_combined_minimum_size().y, sc.scroll.size.y, "içerik taşar, liste kayar"
	)
	assert_almost_eq(sc.back_button.get_global_rect().end.y, 2196.0 + 132.0, 1.0, "GERİ sabit")
	assert_lte(sc.scroll.get_global_rect().end.y, sc.back_button.get_global_rect().position.y)
	for c in sc.column.get_children():
		assert_lte(
			c.get_global_rect().end.x, 1080.0 - 72.0 + 1.0, "%s sağ kenardan taşmaz" % c.name
		)


func test_d23_license_card_is_scrollable_and_back_stays_visible() -> void:
	var host := _host()
	var sc := SettingsScreen.new()
	host.add_child(sc)
	sc.open()
	sc.licenses_button.pressed.emit()
	await get_tree().process_frame
	assert_true(sc.licenses.find_child("LicScroll", true, false) is ScrollContainer)
	var card := sc.licenses.find_child("LicScroll", true, false) as ScrollContainer
	assert_lte(card.get_global_rect().end.y, sc.lic_back_button.get_global_rect().position.y)
	sc.apply_safe_area(Vector4(0, 130, 0, 150))
	await get_tree().process_frame
	assert_lte(card.get_global_rect().end.y, sc.lic_back_button.get_global_rect().position.y)


func test_d24_muted_state_shows_struck_speaker_next_to_text() -> void:
	var sc := SettingsScreen.new()
	add_child_autofree(sc)
	sc.open()
	var sp := sc.sound_button.find_child("Speaker", true, false) as UiKit.Glyph
	assert_not_null(sp)
	assert_eq(sp.kind, &"speaker")
	sc.sound_button.pressed.emit()
	assert_false(st.sound_on)
	assert_eq(sp.kind, &"speaker_muted", "sessizde çizili hoparlör")
	assert_true(sc.muted_note.visible, "metin de kalır (tek kanal değil)")
	sc.sound_button.pressed.emit()
	assert_eq(sp.kind, &"speaker")


func test_d25_mini_portrait_replaces_person_icon_and_falls_back() -> void:
	var m := MainMenu.new()
	add_child_autofree(m)
	await get_tree().process_frame
	var mini := m.characters_button.get_node("MiniPortrait") as TextureRect
	assert_false(mini.visible, "doku yokken kişi ikonu")
	m.set_character_portrait(
		ImageTexture.create_from_image(Image.create(1024, 1536, false, Image.FORMAT_RGBA8))
	)
	assert_true(mini.visible)
	assert_eq(mini.size, Vector2(68, 68))
	m.set_character_portrait(null)
	assert_false(mini.visible, "doku kalkarsa ikon geri gelir")
	m.set_character_portrait(
		ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	)
	assert_false(mini.visible, "küçük/bozuk doku kırpmaz, ikon kalır")


func test_d26_stacked_icons_are_vertically_centered_and_floor_patch_is_clipped() -> void:
	var host := _host()
	var m := MainMenu.new()
	host.add_child(m)
	await get_tree().process_frame
	m.set_font_scale(2.0)
	for i in 3:
		await get_tree().process_frame
	for b in [m.characters_button, m.achievements_button]:
		for c in (b as Button).get_children():
			if c is UiKit.Glyph and c.visible or c is MainMenu.AchRing:
				var mid: float = c.position.y + c.size.y * 0.5
				assert_almost_eq(
					mid, (168.0 - 40.0) * 0.5, 1.0, "%s ikonu başlıkla hizalı" % b.name
				)
	var scene := m.get_node("Scene") as Control
	assert_lte(
		scene.get_global_rect().end.y,
		m.play_button.get_global_rect().position.y,
		"sahne sütunun üstünde biter"
	)
	m.set_font_scale(1.0)
	await get_tree().process_frame
	assert_almost_eq(scene.get_global_rect().end.y, 2400.0, 1.0, "1×'te sahne tam")
