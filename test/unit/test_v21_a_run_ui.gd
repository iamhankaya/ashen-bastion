extends GutTest
## v2.1 A dilimi (U4a): koşu şeridi (ana sayfa), KOŞU ekranı, duraklatma çipleri. Metinler/sayılar run_profiles.json'dan;
## seçim V21Runs üzerinden sahte Settings'e yazılır (gerçek user://settings.cfg'ye dokunulmaz). Godot yerelde koşmaz: CI.

var fake: V21Kit.FakeSettings
var _saved: Array = []


func before_each() -> void:
	fake = V21Kit.use_fake_settings()
	var st := get_node_or_null(^"/root/Settings")
	if st != null:  # RunScreen yazı ölçeği/hareket ayarını gerçek Settings'ten okur: testten önce sabitle, sonra geri al
		_saved = [st.buyuk_yazi, st.hareket_azalt]
		st.buyuk_yazi = false
		st.hareket_azalt = false


func after_each() -> void:
	V21Kit.clear_fake_settings()
	var st := get_node_or_null(^"/root/Settings")
	if st != null and _saved.size() == 2:
		st.buyuk_yazi = _saved[0]
		st.hareket_azalt = _saved[1]


func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	return host


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _screen() -> RunScreen:
	var s := RunScreen.new()
	_host().add_child(s)
	s.visible = true
	return s


func _menu() -> MainMenu:
	var m := MainMenu.new()
	_host().add_child(m)
	return m


func _detail_values(s: RunScreen) -> Array:
	var out := []
	for row in s.detail_panel.get_child(0).get_children():
		out.append((row.get_child(1) as Label).text)
	return out


# --- saf metin kaynağı (RunStrip) --------------------------------------------------------------------------


func test_a1_durations_come_from_the_profile_file() -> void:
	var cfg := V21Kit.cfg()
	assert_eq(RunStrip.duration_text(&"quick", cfg), "10 DK")
	assert_eq(RunStrip.duration_text(&"normal", cfg), "20 DK")
	assert_eq(RunStrip.duration_text(&"endless", cfg), "∞")
	var tuned := V21Kit.mutated(cfg, "modes.quick.time_scale", 0.75)
	assert_eq(RunStrip.duration_text(&"quick", tuned), "15 DK", "süre time_scale'den, sabit değil")
	assert_eq(RunStrip.mode_desc(&"quick", tuned), "Kısa koşu. Lord 15. dakikada gelir.")


func test_a2b_missing_profile_data_never_prints_fake_durations() -> void:
	assert_eq(RunStrip.duration_text(&"normal", {}), "")
	assert_eq(RunStrip.mode_desc(&"quick", {}), "Kısa koşu.")
	assert_eq(RunStrip.title_text(&"normal", {}), "NORMAL")


func test_a2_strip_title_has_no_duration_for_endless() -> void:
	var cfg := V21Kit.cfg()
	assert_eq(RunStrip.title_text(&"normal", cfg), "NORMAL · 20 DK")
	assert_eq(RunStrip.title_text(&"quick", cfg), "HIZLI · 10 DK")
	assert_eq(RunStrip.title_text(&"endless", cfg), "SONSUZ")


func test_a3_detail_rows_show_deltas_from_the_difficulty_table() -> void:
	var cfg := V21Kit.cfg()
	assert_eq(
		RunStrip.detail_rows(&"normal", cfg),
		[
			["Düşman canı", "−%15"],
			["Düşman hasarı", "−%25"],
			["Düşman sayısı", "−%15"],
			["Kazanılan XP", "aynı"]
		]
	)
	assert_eq(RunStrip.detail_rows(&"easy", cfg)[3], ["Kazanılan XP", "+%25"])
	assert_eq(RunStrip.detail_rows(&"hard", cfg)[0], ["Düşman canı", "tam"], "Zor = bugünkü eğri")
	assert_eq(RunStrip.detail_rows(&"hard", cfg)[3], ["Kazanılan XP", "aynı"])
	var tuned := V21Kit.mutated(cfg, "difficulties.easy.enemy_hp", 0.5)
	assert_eq(RunStrip.detail_rows(&"easy", tuned)[0][1], "−%50", "levha veriyi izler")
	assert_eq(RunStrip.detail_rows(&"yok", cfg), [], "bilinmeyen zorluk: boş")


func test_a4_rule_lines_warn_only_when_needed() -> void:
	assert_eq(RunStrip.rule_lines(&"normal", &"normal").size(), 1)
	assert_false(RunStrip.rule_lines(&"quick", &"hard")[0]["warn"], "ilk satır nötr")
	var easy := RunStrip.rule_lines(&"normal", &"easy")
	assert_eq(easy.size(), 2)
	assert_true(easy[1]["warn"])
	assert_eq(easy[1]["text"], "Kolay'da Lord başarımları ve toplam sayaçlar ilerlemez.")
	var endless := RunStrip.rule_lines(&"endless", &"hard")
	assert_eq(endless[1]["text"], "İlk Lord'u devirmek zaferdir; koşu sen ölene kadar sürer.")
	assert_eq(RunStrip.rule_lines(&"endless", &"easy").size(), 3)


func test_a5_numbers_are_spoken_in_turkish() -> void:
	assert_eq(RunStrip.spoken(10), "on")
	assert_eq(RunStrip.spoken(20), "yirmi")
	assert_eq(RunStrip.spoken(25), "yirmi beş")
	assert_eq(RunStrip.spoken(45), "kırk beş")
	assert_eq(RunStrip.spoken(30), "otuz")


func test_a6_talkback_names_match_the_design() -> void:
	var cfg := V21Kit.cfg()
	assert_eq(
		RunStrip.strip_a11y(&"normal", &"normal", cfg),
		"Koşu: Normal, yirmi dakika. Zorluk: Normal. Değiştirmek için çift dokun."
	)
	assert_eq(
		RunStrip.strip_a11y(&"endless", &"hard", cfg),
		"Koşu: Sonsuz. Zorluk: Zor. Değiştirmek için çift dokun."
	)
	assert_eq(
		RunStrip.mode_a11y(&"quick", cfg, true),
		"Hızlı mod, on dakika, Lord on dakikada gelir, seçili"
	)
	assert_eq(
		RunStrip.mode_a11y(&"endless", cfg, false),
		"Sonsuz mod, Lord devrilince koşu sürer, ölene kadar, seçili değil"
	)
	assert_eq(
		RunStrip.diff_a11y(&"easy", false),
		"Kolay zorluk, bir kalkan üç üzerinden, daha az ve zayıf düşman, seçili değil"
	)
	assert_eq(
		RunStrip.detail_a11y(&"easy", cfg),
		(
			"Kolay zorluk ayrıntıları: düşman canı yüzde otuz az, düşman hasarı yüzde kırk beş az, "
			+ "düşman sayısı yüzde otuz az, kazanılan XP yüzde yirmi beş fazla."
		)
	)


# --- KOŞU ekranı ---------------------------------------------------------------------------------------------


func test_a10_screen_has_three_mode_rows_and_three_difficulty_cards() -> void:
	var s := _screen()
	await _settle()
	assert_eq(s.mode_buttons.keys(), [&"quick", &"normal", &"endless"])
	assert_eq(s.diff_buttons.keys(), [&"easy", &"normal", &"hard"])
	for m in s.mode_buttons:
		var b: Button = s.mode_buttons[m]
		assert_almost_eq(b.size.x, 936.0, 1.0, "mod satırı genişliği")
		assert_almost_eq(b.size.y, 184.0, 0.5, "mod satırı yüksekliği")
	for d in s.diff_buttons:
		var b: Button = s.diff_buttons[d]
		assert_almost_eq(b.size.x, 296.0, 1.5, "zorluk kartı genişliği")
		assert_almost_eq(b.size.y, 272.0, 0.5, "zorluk kartı yüksekliği")
	assert_eq(s.back_button.text, "GERİ")
	assert_almost_eq(s.back_button.global_position.y, 2196.0, 0.5)


func test_a11_tapping_a_difficulty_selects_and_saves_it_at_once() -> void:
	var s := _screen()
	await _settle()
	watch_signals(s)
	s.diff_buttons[&"hard"].pressed.emit()
	assert_eq(fake.run_diff, "hard")
	assert_eq(fake.run_mode, "normal", "mod değişmez")
	assert_gte(fake.saves, 1, "anında kaydedilir")
	assert_signal_emitted_with_parameters(s, "selection_changed", [&"normal", &"hard"])
	s.mode_buttons[&"endless"].pressed.emit()
	assert_eq(fake.run_mode, "endless")
	assert_eq(fake.run_diff, "hard", "zorluk değişmez")


func test_a12_selection_has_a_seal_and_a_spoken_state_not_just_a_colour() -> void:
	var s := _screen()
	await _settle()
	s.mode_buttons[&"quick"].pressed.emit()
	s.diff_buttons[&"easy"].pressed.emit()
	for m in s.mode_buttons:
		var b: Button = s.mode_buttons[m]
		var on: bool = m == &"quick"
		assert_eq(s._seals[b].visible, on, "mühür yalnız seçilide: %s" % m)
		assert_true(b.accessibility_name.ends_with("seçili" if on else "seçili değil"), str(m))
	for d in s.diff_buttons:
		var b: Button = s.diff_buttons[d]
		var on: bool = d == &"easy"
		assert_eq(s._seals[b].visible, on, "mühür yalnız seçilide: %s" % d)
		assert_true(b.accessibility_name.ends_with("seçili" if on else "seçili değil"), str(d))


func test_a13_detail_and_rule_panels_follow_the_selection() -> void:
	var s := _screen()
	await _settle()
	assert_eq(_detail_values(s), ["−%15", "−%25", "−%15", "aynı"], "varsayılan Normal/Normal")
	assert_eq(s.rules_panel.get_child(0).get_child_count(), 1, "yalnız nötr satır")
	s.diff_buttons[&"easy"].pressed.emit()
	assert_eq(_detail_values(s), ["−%30", "−%45", "−%30", "+%25"])
	assert_eq(s.rules_panel.get_child(0).get_child_count(), 2, "Kolay uyarısı eklendi")
	assert_true(s.rules_panel.accessibility_name.contains("Uyarı: Kolay'da Lord başarımları"))
	s.mode_buttons[&"endless"].pressed.emit()
	assert_eq(s.rules_panel.get_child(0).get_child_count(), 3, "Kolay + Sonsuz uyarıları")
	s.diff_buttons[&"hard"].pressed.emit()
	s.mode_buttons[&"normal"].pressed.emit()
	assert_eq(s.rules_panel.get_child(0).get_child_count(), 1)
	assert_eq(_detail_values(s), ["tam", "tam", "tam", "aynı"])


func test_a14_opening_shows_the_saved_selection() -> void:
	fake.run_mode = "quick"
	fake.run_diff = "hard"
	var s := RunScreen.new()
	_host().add_child(s)
	await _settle()
	s.visible = true
	await _settle()
	assert_eq(s.selection(), {"mode": &"quick", "diff": &"hard"})
	assert_true(s._seals[s.mode_buttons[&"quick"]].visible)
	assert_false(s._seals[s.mode_buttons[&"normal"]].visible)
	assert_true(s._seals[s.diff_buttons[&"hard"]].visible)


func test_a15_big_font_stacks_cards_vertically_and_keeps_everything_inside() -> void:
	var s := _screen()
	await _settle()
	s.set_font_scale(2.0)
	await _settle()
	assert_true(s.is_big())
	var prev := -1.0
	for d in [&"easy", &"normal", &"hard"]:
		var b: Button = s.diff_buttons[d]
		assert_almost_eq(b.size.x, 936.0, 12.0, "kart tam genişlik (kaydırma çubuğu payı)")
		assert_almost_eq(b.size.y, 260.0, 0.5)
		assert_gt(b.global_position.y, prev, "dikey sıra")
		prev = b.global_position.y
	for m in s.mode_buttons:
		assert_almost_eq((s.mode_buttons[m] as Button).size.y, 336.0, 0.5, "2× mod satırı")
	assert_gt(s.column.get_combined_minimum_size().y, s.scroll.size.y, "içerik taşar: liste kayar")
	s.set_font_scale(1.0)
	await _settle()
	assert_almost_eq((s.diff_buttons[&"hard"] as Button).size.y, 272.0, 0.5, "1× geri gelir")
	assert_gt(
		(s.diff_buttons[&"normal"] as Button).global_position.x,
		(s.diff_buttons[&"easy"] as Button).global_position.x,
		"1×'te yan yana"
	)


func test_a16_every_target_is_at_least_132_px_and_safe_area_moves_back() -> void:
	var s := _screen()
	await _settle()
	for b in s.mode_buttons.values() + s.diff_buttons.values() + [s.back_button]:
		assert_gte((b as Button).size.y, 132.0, (b as Button).name)
	s.apply_safe_area(Vector4(0, 100, 0, 150))
	await _settle()
	assert_almost_eq(
		s.back_button.global_position.y, 2196.0 - 150.0, 0.5, "GERİ alt paya göre yukarı"
	)
	assert_almost_eq(s.scroll.global_position.y, 250.0 + 100.0, 0.5, "liste üst paya göre aşağı")
	assert_lte(s.back_button.get_global_rect().end.y, 2400.0 - 72.0 - 150.0 + 0.5)
	s.apply_safe_area(Vector4.ZERO)
	await _settle()
	assert_almost_eq(s.back_button.global_position.y, 2196.0, 0.5)


func test_a17_back_hides_the_screen_and_signals() -> void:
	var s := _screen()
	await _settle()
	watch_signals(s)
	s.back_button.pressed.emit()
	assert_false(s.visible)
	assert_signal_emitted(s, "back_requested")


# --- ana sayfa koşu şeridi ------------------------------------------------------------------------------------


func test_a20_strip_sits_27_px_above_play_without_moving_it() -> void:
	var m := _menu()
	await _settle()
	assert_almost_eq(m.run_button.global_position.y, 1604.0, 0.5)
	assert_almost_eq(m.run_button.size.y, 132.0, 0.5)
	assert_almost_eq(m.run_button.size.x, 936.0, 1.5)
	assert_almost_eq(m.play_button.global_position.y, 1763.0, 0.5, "OYNA yerinde")
	assert_almost_eq(
		m.play_button.global_position.y - m.run_button.get_global_rect().end.y, 27.0, 0.5
	)


func test_a21_strip_is_the_first_focus_stop_and_opens_the_run_screen() -> void:
	var m := _menu()
	await _settle()
	assert_eq(m.run_button.focus_mode, Control.FOCUS_ALL)
	assert_eq(
		(m.play_button.get_parent() as Control).find_children("*", "Button", true, false)[0],
		m.run_button
	)
	watch_signals(m)
	m.run_button.pressed.emit()
	assert_signal_emitted(m, "run_requested")


func test_a22_strip_reads_the_saved_selection_and_refreshes() -> void:
	fake.run_mode = "quick"
	fake.run_diff = "easy"
	var m := _menu()
	await _settle()
	assert_eq(m.run_button._title.text, "HIZLI · 10 DK")
	assert_eq(m.run_button._sub.text, "Zorluk: Kolay")
	assert_eq(m.run_button._shields.count, 1)
	assert_eq(
		m.run_button.accessibility_name,
		"Koşu: Hızlı, on dakika. Zorluk: Kolay. Değiştirmek için çift dokun."
	)
	fake.run_mode = "endless"
	fake.run_diff = "hard"
	m.refresh_run()
	assert_eq(m.run_button._title.text, "SONSUZ", "Sonsuz'da süre yazılmaz")
	assert_eq(m.run_button._shields.count, 3)


func test_a23_big_font_grows_the_strip_and_lifts_the_column_to_y1106() -> void:
	var m := _menu()
	await _settle()
	m.set_font_scale(2.0)
	await _settle()
	assert_true(m.run_button.is_big())
	assert_almost_eq(m.run_button.size.y, 168.0, 0.5)
	assert_almost_eq(m.run_button.global_position.y, 1106.0, 1.0, "sütun üstü")
	assert_lte(m.version_label.get_global_rect().end.y, 2400.0 - 72.0 + 0.5, "hiçbir şey taşmaz")
	var prev := m.run_button.get_global_rect().end.y
	for b in [
		m.play_button,
		m.characters_button,
		m.achievements_button,
		m.scores_button,
		m.settings_button
	]:
		assert_gte((b as Button).global_position.y, prev + 27.0 - 1.0, "%s örtüşmez" % b.name)
		prev = (b as Button).get_global_rect().end.y
	if m.hero != null:
		assert_almost_eq(m.hero.get_global_rect().size.x, 320.0, 1.0, "karakter ölçeği 0,5")
		assert_lte(m.hero.get_global_rect().end.y, m.run_button.global_position.y, "şeridi örtmez")
	m.set_font_scale(1.0)
	await _settle()
	assert_almost_eq(m.run_button.global_position.y, 1604.0, 0.5, "1× düzen geri gelir")
	assert_almost_eq(m.run_button.size.y, 132.0, 0.5)


func test_a24_safe_area_lifts_the_strip_with_the_column() -> void:
	var m := _menu()
	await _settle()
	m.apply_safe_area(Vector4(0, 100, 0, 150))
	await _settle()
	assert_almost_eq(m.run_button.global_position.y, 1604.0 - 150.0, 0.5)
	assert_almost_eq(m.play_button.global_position.y, 1763.0 - 150.0, 0.5)


# --- duraklatma çipleri ---------------------------------------------------------------------------------------


func test_a30_pause_shows_info_only_run_chips() -> void:
	fake.run_mode = "quick"
	fake.run_diff = "hard"
	var p := PauseScreen.new()
	_host().add_child(p)
	await _settle()
	p.open([] as Array[SkillState], [] as Array[SkillState], true, true)
	await _settle()
	assert_not_null(p.chips)
	assert_eq(p.chips.get_child_count(), 2)
	var mode_chip := p.chips.get_node("ModeChip") as Control
	var diff_chip := p.chips.get_node("DiffChip") as Control
	assert_eq(mode_chip.find_children("*", "Label", true, false)[0].text, "HIZLI · 10 DK")
	assert_eq(diff_chip.find_children("*", "Label", true, false)[0].text, "ZOR")
	assert_eq(mode_chip.accessibility_name, "Mod: Hızlı, on dakika.")
	assert_eq(diff_chip.accessibility_name, "Zorluk: Zor.")
	for c in [p.chips, mode_chip, diff_chip]:
		assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "çip dokunma almaz")
	fake.run_mode = "endless"
	fake.run_diff = "easy"
	p.open([] as Array[SkillState], [] as Array[SkillState], true, true)
	assert_eq(
		p.chips.get_node("ModeChip").find_children("*", "Label", true, false)[0].text, "SONSUZ"
	)
	assert_eq(p.chips_slot.get_child_count(), 1, "eski çipler birikmez")


func test_a31_chips_do_not_push_the_pause_actions_off_screen() -> void:
	var p := PauseScreen.new()
	_host().add_child(p)
	await _settle()
	p.open([] as Array[SkillState], [] as Array[SkillState], true, true)
	p.apply_safe_area(Vector4.ZERO)
	await _settle()
	var chips_rect := p.chips_slot.get_global_rect()
	assert_gte(chips_rect.position.y, p.column.global_position.y, "çipler sütun içinde")
	assert_lte(chips_rect.end.y, p.resume_button.global_position.y, "DEVAM ET'in üstünde")
	assert_lte(p.column.get_global_rect().end.y, 2400.0 - UiKit.DEFAULT_BOTTOM + 0.5)
