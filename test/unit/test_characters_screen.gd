extends GutTest
## K2/K5/K10 vitrin ekranı: durumlar (SEÇ/SEÇİLİ/KİLİTLİ), kilit nedeni, tek karakter, güvenli alan, gizliyken hareket
## kapalı / görününce açık, kart şeridi, D-pad adımı. Gerçek data/ + kopya veri (önbellek değiştirilmez).

var _data: GameData


func before_each() -> void:
	_data = GameData.load_dir("res://data")  # özel kopya: paylaşılan önbellek değiştirilmez


func _screen(
	selected: StringName = &"gunslinger", store: AchievementStore = null
) -> CharactersScreen:
	var s := CharactersScreen.new()
	add_child_autofree(s)
	s.open(_data, store, selected)
	return s


## Kilitli karakter: özel kopyada barutcu'ya kilit bağlanır (gerçek veri dosyası değişmez).
func _lock_barutcu() -> void:
	_data.get_character(&"barutcu").unlock_achievement = &"ilk_kan"


func test_open_focuses_selected_and_state_selected() -> void:
	var s := _screen(&"gunslinger")
	assert_eq(s.focus_id(), &"gunslinger")
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.SELECTED)
	assert_false(s.press_select(), "seçili odakta SEÇ işlevsiz")


func test_invalid_selected_id_focuses_first_character() -> void:
	var s := _screen(&"yok")
	assert_eq(s.focus_id(), CharacterRoster.ids(_data)[0])


func test_focus_other_character_then_select_emits_signal() -> void:
	var s := _screen(&"gunslinger")
	watch_signals(s)
	s.set_focus_id(&"barutcu")
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.SELECT)
	assert_true(s.press_select())
	assert_signal_emitted_with_parameters(s, "selected", [&"barutcu"])
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.SELECTED)
	assert_eq(s.select_button.text, "✓ SEÇİLİ")


func test_unknown_focus_id_is_ignored() -> void:
	var s := _screen(&"gunslinger")
	s.set_focus_id(&"yok")
	assert_eq(s.focus_id(), &"gunslinger")


func test_k10_locked_character_cannot_be_selected() -> void:
	_lock_barutcu()
	var s := _screen(&"gunslinger", null)
	s.set_focus_id(&"barutcu")
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.LOCKED)
	watch_signals(s)
	assert_false(s.press_select())
	assert_signal_not_emitted(s, "selected")
	assert_eq(s.select_button.text, "KİLİTLİ")
	assert_eq(s._reason.text, "İlk Kan başarımını aç")


func test_k10_locked_when_store_corrupt() -> void:
	_lock_barutcu()
	var st := AchievementStore.new()
	st.corrupt = true
	var s := _screen(&"gunslinger", st)
	s.set_focus_id(&"barutcu")
	assert_eq(
		s.select_button_state(),
		CharactersScreen.SelectState.LOCKED,
		"okunamayan kayıt: güvenli yön"
	)


func test_k10_real_characters_have_no_lock() -> void:
	for id in CharacterRoster.ids(_data):
		assert_eq(
			_data.get_character(id).unlock_achievement,
			&"",
			"hiçbir gerçek karakterde unlock yok: %s" % id
		)
	var s := _screen(&"gunslinger")
	for id in CharacterRoster.ids(_data):
		s.set_focus_id(id)
		assert_ne(s.select_button_state(), CharactersScreen.SelectState.LOCKED)


func test_single_character_hides_strip_and_counter() -> void:
	_data.character_ids = [&"gunslinger"] as Array[StringName]
	var s := _screen(&"gunslinger")
	assert_false(s._strip.visible)
	assert_false(s.counter_label.visible)
	assert_eq(s.select_button_state(), CharactersScreen.SelectState.SELECTED)


func test_counter_and_cards() -> void:
	var s := _screen(&"gunslinger")
	assert_eq(s.cards.size(), 2)
	var pos := CharacterRoster.ids(_data).find(&"gunslinger") + 1
	assert_eq(s.counter_label.text, "%d / 2" % pos)
	assert_eq(s.cards[0].custom_minimum_size, Vector2(252, 264))


func test_name_and_stats_follow_focus() -> void:
	var s := _screen(&"gunslinger")
	s.set_focus_id(&"barutcu")
	assert_eq(s.name_label.text, "BARUTÇU")
	assert_eq(s._stat_values[0].text, "120")
	assert_eq(s._stat_values[3].text, "1,2 SN")
	assert_eq(s.skill_label.text, "DİNAMİT")
	assert_string_contains(s.blurb_label.text, "dinamit")


func test_dpad_step_does_not_wrap() -> void:
	var s := _screen(&"gunslinger")
	var ids := CharacterRoster.ids(_data)
	s.set_focus_id(ids[0])
	s._step(-1)
	assert_eq(s.focus_id(), ids[0])
	s._step(1)
	assert_eq(s.focus_id(), ids[1])
	s._step(1)
	assert_eq(s.focus_id(), ids[1])


func test_k5_hidden_stops_processing_and_particles_visible_again_restarts() -> void:
	var s := _screen()
	assert_true(s.is_processing())
	assert_true(s.particles.emitting)
	assert_eq(s.particles.amount, 12)
	s.visible = false
	assert_false(s.is_processing())
	assert_false(s.particles.emitting)
	s.visible = true
	assert_true(s.is_processing())
	assert_true(s.particles.emitting, "tekrar görününce parçacıklar yeniden başlar")


func test_motion_follows_showcase_motion() -> void:
	var s := _screen()
	s._t = 1.2
	s._place_portrait(0.0)
	assert_almost_eq(s._portrait.scale.x, ShowcaseMotion.scale_at(1.2), 1e-6)
	s._t = 1.5
	s._place_portrait(0.0)
	assert_almost_eq(
		s._portrait.position.x, (1080.0 - CharactersScreen.PORTRAIT_W) * 0.5 + 8.0, 1e-4
	)


func test_safe_area_shifts_buttons_and_stage_absorbs() -> void:
	var s := _screen()
	s.apply_safe_area(Vector4.ZERO)
	var sel_y := s.select_button.position.y
	var stage_h := s.stage.size.y
	assert_eq(sel_y, 2013.0)
	assert_eq(s.back_button.position.y, 2196.0)
	assert_eq(stage_h, 1060.0)
	s.apply_safe_area(Vector4(0, 100, 0, 150))
	assert_eq(s.select_button.position.y, sel_y - 150.0)
	assert_eq(s.back_button.position.y, 2196.0 - 150.0)
	assert_eq(s.stage.size.y, stage_h - 250.0, "sahne payı emer")
	assert_eq(s.title_label.position.y, 112.0 + 100.0)


func test_layout_constants_match_design() -> void:
	var s := _screen()
	s.apply_safe_area(Vector4.ZERO)
	assert_eq(s.stage.position.y, 190.0)
	assert_eq(s.select_button.size, Vector2(936, 156))
	assert_eq(s.back_button.size, Vector2(936, 132))
	await get_tree().process_frame
	assert_eq(s._panel.size.x, 936.0)
	assert_gte(s._panel.size.y, 446.0)
	assert_eq(s._panel.position.y + s._panel.size.y, 1696.0)


func test_accessibility_names() -> void:
	var s := _screen(&"gunslinger")
	assert_eq(s.accessibility_name, "Karakterler, seçili: Gunslinger")
	assert_eq(s.back_button.accessibility_name, "Geri")
	assert_eq(s.select_button.accessibility_name, "Seçili")
	s.set_focus_id(&"barutcu")
	assert_eq(s.select_button.accessibility_name, "Seç")


func test_missing_portrait_does_not_crash() -> void:
	_data.get_character(&"barutcu").portrait = "res://yok/yok.png"
	var s := _screen(&"gunslinger")
	s.set_focus_id(&"barutcu")
	assert_not_null(s._portrait.texture, "yer tutucu portre")


# --- v2.0 düzeltme payı (K-02..K-05, F-029, F-030) ------------------------------------------------------


func test_k02_select_state_drops_selected_overrides_so_primary_style_returns() -> void:
	var s := _screen(&"gunslinger")
	assert_true(s.select_button.has_theme_stylebox_override(&"focus"), "SEÇİLİ: özel stil")
	s.set_focus_id(&"barutcu")
	for st in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		assert_false(
			s.select_button.has_theme_stylebox_override(st), "SEÇ: %s varsayılan (bordo)" % st
		)
	s.set_focus_id(&"gunslinger")
	assert_true(s.select_button.has_theme_stylebox_override(&"focus"))


func test_k04_selected_text_is_amber_also_on_focus() -> void:
	var s := _screen(&"gunslinger")
	assert_eq(s.select_button.get_theme_color(&"font_focus_color"), UiKit.AMBER)
	assert_eq(s.select_button.get_theme_color(&"font_color"), UiKit.AMBER)


func test_k05_chip_is_capsule_and_locked_chip_has_lock_glyph() -> void:
	_lock_barutcu()
	var s := _screen(&"gunslinger")
	assert_true(s.chip_label.has_theme_stylebox_override(&"normal"), "SEÇİLİ çipi kapsül")
	assert_false(s._chip_lock.visible)
	s.set_focus_id(&"barutcu")
	assert_eq(s.chip_label.text, "KİLİTLİ")
	assert_true(s._chip_lock.visible, "kilitli çipte kilit glifi")
	assert_true(s.chip_label.has_theme_stylebox_override(&"normal"))


func test_k03_card_without_portrait_uses_fallback_not_flat_block() -> void:
	_data.get_character(&"barutcu").portrait = ""
	var s := _screen(&"gunslinger")
	var card := s.cards[1]
	assert_not_null(card.get_node_or_null("Face"), "portresiz kartta varsayılan portre")


func test_k03_placeholder_character_is_distinguishable_from_gunslinger() -> void:
	var s := _screen(&"gunslinger")
	var g_face := s.cards[0].get_node("Face") as TextureRect
	var b_face := s.cards[1].get_node("Face") as TextureRect
	assert_ne(g_face.self_modulate, b_face.self_modulate, "belirgin ton farkı")
	assert_null(s.cards[0].get_node_or_null("Monogram"))
	var m := s.cards[1].get_node_or_null("Monogram") as Label
	assert_not_null(m, "yer tutucu kartta monogram")
	assert_eq(m.text, "B")
	s.set_focus_id(&"barutcu")
	assert_eq(s._stage_mono.text, "B", "sahnede de monogram")
	s.set_focus_id(&"gunslinger")
	assert_eq(s._stage_mono.text, "")


func test_f029_name_uses_display_upper_not_dotted_i() -> void:
	var s := _screen(&"gunslinger")
	assert_eq(s.name_label.text, "GUNSLINGER")
	assert_eq(UiKit.character_upper(_data.get_character(&"barutcu")), "BARUTÇU")
	var c := CharacterDef.new()
	c.display_name = "Kirpi"
	assert_eq(UiKit.character_upper(c), UiKit.upper_tr("Kirpi"), "display_upper yoksa upper_tr")


func test_f030_gunslinger_first_by_order_field() -> void:
	assert_eq(_data.character_ids[0], &"gunslinger")
	_data.get_character(&"barutcu").order = 0
	_data._sort_character_ids()
	assert_eq(_data.character_ids[0], &"barutcu", "order küçük olan önce")
	_data.get_character(&"barutcu").order = CharacterDef.ORDER_DEFAULT
	_data.get_character(&"gunslinger").order = CharacterDef.ORDER_DEFAULT
	_data._sort_character_ids()
	assert_eq(
		_data.character_ids,
		[&"barutcu", &"gunslinger"] as Array[StringName],
		"eşitlikte dosya sırası"
	)


func test_skill_icon_has_84px_frame() -> void:
	var s := _screen(&"gunslinger")
	var box := s.find_child("SkillIconBox", true, false) as Control
	assert_not_null(box)
	assert_eq(box.custom_minimum_size, Vector2(84, 84))
	assert_not_null(box.get_node_or_null("SkillFrame"))


func test_sd01_skill_icon_is_drawn_above_frame() -> void:
	var s := _screen(&"gunslinger")
	var box := s.find_child("SkillIconBox", true, false) as Control
	var icon := box.get_node("SkillIcon") as Control
	var frame := box.get_node("SkillFrame") as Control
	assert_gt(icon.get_index(), frame.get_index(), "çerçeve altta, ikon üstte")
	for id in [&"gunslinger", &"barutcu"]:
		s.set_focus_id(id)
		assert_not_null((icon as TextureRect).texture, "başlangıç becerisi ikonu yüklü: %s" % id)


func test_sd04_locked_chip_gap_between_lock_and_text() -> void:
	_lock_barutcu()
	var s := _screen(&"gunslinger")
	s.set_focus_id(&"barutcu")
	var sb := s.chip_label.get_theme_stylebox(&"normal")
	var lock_end := s._chip_lock.position.x + s._chip_lock.size.x
	assert_gte(sb.content_margin_left - lock_end, 8.0, "kilit ile metin arası >= 8 px")
	assert_eq(s.chip_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "metin ortalanıp kilide binmez")
