extends GutTest
## MainMenu v2.0 (S3 düzen sözleşmesi): OYNA y1556, KARAKTERLER|BAŞARIMLAR y1763, EN İYİ SKORLAR y1922, SES|TİTREŞİM y2081,
## sürüm y2240; hero 960×960 y 560–1520; 454×132 hedefler; alt satırlar; sinyaller; odak sırası; sürüm etiketi.


func _menu() -> MainMenu:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	var m := MainMenu.new()
	host.add_child(m)
	return m


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_column_geometry_matches_design() -> void:
	var m := _menu()
	await _settle()
	assert_almost_eq(m.play_button.global_position.y, 1556.0, 0.5)
	assert_eq(m.play_button.size.y, 180.0)
	assert_almost_eq(m.characters_button.global_position.y, 1763.0, 0.5)
	assert_almost_eq(m.achievements_button.global_position.y, 1763.0, 0.5)
	assert_almost_eq(m.scores_button.global_position.y, 1922.0, 0.5)
	assert_almost_eq(m.sound_button.global_position.y, 2081.0, 0.5)
	assert_almost_eq(m.vibration_button.global_position.y, 2081.0, 0.5)
	assert_almost_eq(m.version_label.global_position.y, 2240.0, 0.5)
	assert_almost_eq(m.play_button.global_position.x, 72.0, 0.5)
	assert_gte(m.play_button.size.x, 936.0 - 0.5)


func test_half_buttons_are_454x132_with_27_gap() -> void:
	var m := _menu()
	await _settle()
	for b in [m.characters_button, m.achievements_button, m.sound_button, m.vibration_button]:
		assert_almost_eq(b.size.x, 454.5, 1.0, b.name)
		assert_eq(b.size.y, 132.0, b.name)
	var gap := (
		m.achievements_button.global_position.x
		- (m.characters_button.global_position.x + m.characters_button.size.x)
	)
	assert_almost_eq(gap, 27.0, 0.5)
	assert_almost_eq(m.characters_button.size.x, m.achievements_button.size.x, 1.0)
	assert_eq(m.characters_button.text, "KARAKTERLER")
	assert_eq(m.achievements_button.text, "BAŞARIMLAR")


func test_vertical_gaps_are_27() -> void:
	var m := _menu()
	await _settle()
	var ys := [
		m.play_button.global_position.y + 180.0,
		m.characters_button.global_position.y + 132.0,
		m.scores_button.global_position.y + 132.0,
		m.sound_button.global_position.y + 132.0,
	]
	var next := [
		m.characters_button.global_position.y,
		m.scores_button.global_position.y,
		m.sound_button.global_position.y,
		m.version_label.global_position.y,
	]
	for i in 4:
		assert_almost_eq(next[i] - ys[i], 27.0, 0.5, "boşluk %d" % i)


func test_column_fits_above_bottom_margin() -> void:
	var m := _menu()
	await _settle()
	assert_lte(m.version_label.global_position.y + m.version_label.size.y, 2400.0 - 72.0 + 0.5)


func test_hero_box_960_square_y560_to_1520() -> void:
	var m := _menu()
	await _settle()
	if m.hero == null:
		pending("ana görsel dosyası yok")
		return
	assert_eq(m.hero.offset_right - m.hero.offset_left, 960.0)
	assert_eq(m.hero.offset_bottom - m.hero.offset_top, 960.0)
	assert_almost_eq(1200.0 + m.hero.offset_top, 560.0, 0.01)
	assert_almost_eq(1200.0 + m.hero.offset_bottom, 1520.0, 0.01)
	assert_almost_eq(540.0 + m.hero.offset_left, 60.0, 0.01, "hero x 60..1020")
	assert_lte(
		1200.0 + m.hero.offset_bottom, m.play_button.global_position.y, "hero düğmelerin üstünde"
	)


func test_notch_top_inset_moves_hero_top_with_title_k01() -> void:
	# K-01: üst pay başlığı indirir; ana görselin üstü de aynı farkla inmeli (başlık–görsel aralığı sabit).
	var m := _menu()
	await _settle()
	if m.hero == null:
		pending("ana görsel dosyası yok")
		return
	m.apply_safe_area(Vector4(48, 0, 48, 80))
	await _settle()
	var gap_flat := 1200.0 + m.hero.offset_top - m._head.offset_top
	m.apply_safe_area(Vector4(48, 130, 48, 80))
	await _settle()
	var gap_notch := 1200.0 + m.hero.offset_top - m._head.offset_top
	assert_almost_eq(gap_notch, gap_flat, 0.01, "başlık–görsel aralığı çentikte de korunur")
	assert_gt(m._head.offset_top, 150.0, "başlık gerçekten indi")
	assert_lte(
		1200.0 + m.hero.offset_bottom, m.play_button.global_position.y, "görsel düğmelerin üstünde"
	)
	m.apply_safe_area(Vector4.ZERO)
	await _settle()
	assert_almost_eq(1200.0 + m.hero.offset_top, 560.0, 0.01, "çentiksiz görünüm değişmez")


func test_signals() -> void:
	var m := _menu()
	watch_signals(m)
	m.characters_button.pressed.emit()
	m.achievements_button.pressed.emit()
	m.achievements_button.pressed.emit()
	assert_signal_emit_count(m, "characters_requested", 1)
	assert_signal_emit_count(m, "achievements_requested", 2)
	assert_signal_not_emitted(m, "scores_requested")


func test_default_sublines_and_version() -> void:
	var m := _menu()
	await _settle()
	assert_eq((m.characters_button.get_node("Sub") as Label).text, "Gunslinger")
	assert_eq((m.achievements_button.get_node("Sub") as Label).text, "0/22")
	assert_eq(m.version_label.text, "Sürüm 2.0 · Gunslinger")


func test_set_character_name_updates_sub_and_version() -> void:
	var m := _menu()
	m.set_character_name("Barutçu")
	assert_eq((m.characters_button.get_node("Sub") as Label).text, "Barutçu")
	assert_eq(m.version_label.text, "Sürüm 2.0 · Barutçu")


func test_set_achievement_count() -> void:
	var m := _menu()
	m.set_achievement_count(8, 22)
	assert_eq((m.achievements_button.get_node("Sub") as Label).text, "8/22")
	m.set_achievement_count(0, 22)
	assert_eq((m.achievements_button.get_node("Sub") as Label).text, "0/22")


func test_clip_name_limits_to_24_letters_with_ellipsis() -> void:
	assert_eq(MainMenu.clip_name("Barutçu"), "Barutçu")
	assert_eq(MainMenu.clip_name("a".repeat(24)), "a".repeat(24))
	assert_eq(MainMenu.clip_name("a".repeat(25)), "a".repeat(24) + "…")
	assert_eq(MainMenu.clip_name(""), "")


func test_clip_name_keeps_turkish_dotted_and_dotless_i() -> void:
	var long := "ılık İşçi ğüzel çöl ıssız dağ"  # 29 harf
	var got := MainMenu.clip_name(long)
	assert_true(got.ends_with("…"))
	assert_true(got.begins_with("ılık İşçi ğüzel çöl ıss"), got)
	assert_eq(MainMenu.clip_name("ıİiI"), "ıİiI", "büyük/küçük harf dönüşümü yapılmaz")


func test_clip_name_does_not_split_combining_marks() -> void:
	# 23 düz harf + "e" + birleştirici akut (U+0301) + "x": 25. harf "x" kesilir, işaret kendi harfiyle kalır.
	var s := "a".repeat(23) + "é" + "x"
	assert_eq(MainMenu.clip_name(s), "a".repeat(23) + "é" + "…")
	# birleştirici işaretler harf sayılmaz: 24 harf + işaretler sığar
	var t := "á".repeat(24)
	assert_eq(MainMenu.clip_name(t), t)


func test_long_name_never_widens_version_label_text_beyond_clip() -> void:
	var m := _menu()
	m.set_character_name("x".repeat(40))
	assert_eq(m.version_label.text, "Sürüm 2.0 · " + "x".repeat(24) + "…")


func test_focus_order_follows_tree_order() -> void:
	var m := _menu()
	await _settle()
	var col := m.play_button.get_parent() as Control
	var tree_order: Array[Node] = col.find_children("*", "Button", true, false)
	var want: Array[Node] = [
		m.play_button,
		m.characters_button,
		m.achievements_button,
		m.scores_button,
		m.sound_button,
		m.vibration_button
	]
	assert_eq(tree_order, want, "OYNA → KARAKTERLER → BAŞARIMLAR → EN İYİ SKORLAR → SES → TİTREŞİM")
	for c in want:
		assert_eq((c as Control).focus_mode, Control.FOCUS_ALL, c.name)


func test_safe_area_extra_lifts_whole_column_and_restores() -> void:
	var m := _menu()
	await _settle()
	m.apply_safe_area(Vector4(0, 100, 0, 150))
	await _settle()
	assert_lte(
		m.version_label.global_position.y + m.version_label.size.y, 2400.0 - 72.0 - 150.0 + 0.5
	)
	assert_almost_eq(
		m.play_button.global_position.y, 1556.0 - 102.0, 0.5, "alt pay 150: sütun 102 px yukarı"
	)
	m.apply_safe_area(Vector4.ZERO)
	await _settle()
	assert_almost_eq(m.play_button.global_position.y, 1556.0, 0.5)
	assert_almost_eq(m.version_label.global_position.y, 2240.0, 0.5)
