extends GutTest
## Kabul (v2.0.3 D): ana sayfa ve ayarlar akışı, güvenli alan, Türkçe büyük harf, hareket azaltma.
## Kaynak: docs/design/v2.0.3/DESIGN.md §2–3 (bağlayıcı; ölçüler 1080×2400), sözleşme `SettingsSections`/`SettingsFlow`,
## `Settings.hareket_azalt`. Dilim D kapalıyken pending. Cihazda görülecekler (kaydırıcıda liste kayması, anahtar kazara tetik,
## akıcılık) bu dosyada DEĞİL, docs/dev/user-verify/v2.0.3-d.md listesindedir.

const SETTINGS_TMP := "user://test_acc_v203_settings.cfg"

var _saved_reduce: bool = false
var _saved_store_path: String = ""


func before_each() -> void:
	_saved_reduce = Settings.hareket_azalt
	# GERİ (SettingsScreen.close) varsayılan yola yazar; gerçek user://settings.cfg sızmasın.
	_saved_store_path = Settings.store_path
	Settings.store_path = SETTINGS_TMP


func after_each() -> void:
	Settings.hareket_azalt = _saved_reduce
	Settings.store_path = _saved_store_path
	for suffix in ["", ".tmp", ".bad"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TMP + suffix))


func _gate() -> bool:
	return V203Slice.require(self, "D")


func _menu() -> MainMenu:
	var host := Control.new()
	host.size = ExpectedLayoutV2.REF
	add_child_autofree(host)
	var m := MainMenu.new()
	host.add_child(m)
	return m


func _settings_screen() -> SettingsScreen:
	var host := Control.new()
	host.size = ExpectedLayoutV2.REF
	add_child_autofree(host)
	var s := SettingsScreen.new()
	host.add_child(s)
	s.open()
	return s


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _bottom(c: Control) -> float:
	return c.global_position.y + c.size.y


# --- ana sayfa ------------------------------------------------------------------------------------------------------


func test_d1_home_has_the_three_tier_column_with_designed_sizes() -> void:
	if _gate():
		return
	var m := _menu()
	await _settle()
	assert_almost_eq(m.play_button.global_position.y, 1763.0, 1.0, "OYNA y")
	assert_almost_eq(m.play_button.size.x, 936.0, 1.0)
	assert_almost_eq(m.play_button.size.y, 180.0, 1.0)
	for b in [m.characters_button, m.achievements_button]:
		assert_almost_eq(b.global_position.y, 1970.0, 1.0, "%s y" % b.name)
		assert_almost_eq(b.size.x, 454.0, 1.5, "%s x" % b.name)
		assert_almost_eq(b.size.y, 132.0, 1.0, "%s h" % b.name)
	for b in [m.scores_button, m.settings_button]:
		assert_almost_eq(b.global_position.y, 2129.0, 1.0, "%s y" % b.name)
		assert_almost_eq(b.size.x, 454.0, 1.5, "%s x" % b.name)
		assert_almost_eq(b.size.y, 132.0, 1.0, "%s h" % b.name)
	assert_almost_eq(m.version_label.global_position.y, 2288.0, 1.0, "sürüm satırı y")


func test_d1_home_buttons_use_correct_turkish_uppercase_and_keep_the_brand_line() -> void:
	if _gate():
		return
	var m := _menu()
	await _settle()
	assert_eq(m.play_button.text, "OYNA")
	assert_eq(m.characters_button.text, "KARAKTERLER")
	assert_eq(m.achievements_button.text, "BAŞARIMLAR")
	assert_eq(m.scores_button.text, "EN İYİ SKORLAR")
	assert_eq(m.settings_button.text, "AYARLAR")
	assert_true(AchKit.any_text_contains(m, "ASH AND STEEL"), "üst yazı kullanıcı kararıyla kalır")
	assert_true(AchKit.any_text_contains(m, "ASHEN"), "oyun adı")


func test_d1_version_line_is_plain_2_0_3_without_the_character_name() -> void:
	if _gate():
		return
	var m := _menu()
	m.set_character_name("Gunslinger")
	await _settle()
	assert_eq(m.version_label.text, "Sürüm 2.1.0")


## Üretim yolu: denetleyici menüyü kurunca sayaç gerçek kademe toplamını (53) gösterir; `MainMenu.DEFAULT_ACH_TOTAL`
## (22, yalnız denetleyicisiz çıplak menüde görünür) ilk karede bile ekrana sızmamalı. Karar notu: sabit eski 22'de kaldığı
## sürece çıplak menü "0/22" gösterir; bu test yalnız üretim akışını sabitler (sabitin 53'e çekilmesi önerisi rapordadır).
func test_d1b_controller_built_menu_counts_shipped_steps_not_the_old_default() -> void:
	if _gate():
		return
	var path := AchKit.tmp_path("d1b")
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.v2_opts = {"achievements_path": path, "clock": AchKit.clock()}
	add_child(c)
	c.highscores = Highscores.new(AchKit.tmp_path("d1bhs"))
	c.go_menu()
	var shown := AchKit.any_text_contains(c.menu, "0/53")
	var stale := AchKit.any_text_contains(c.menu, "0/22")
	# Denetleyici anahtarı kapalıysa (v2 akışı yok) çıplak menü varsayılanı görünür; o durum bu testin konusu değil.
	if c.get_parent() != null:
		c.get_parent().remove_child(c)
	c.free()
	AchKit.cleanup()
	assert_true(shown, "denetleyici menüsü 0/53 gösterir")
	assert_false(stale, "eski 22 varsayılanı sızmaz")


func test_d1_home_progress_ring_text_is_open_over_total_steps() -> void:
	if _gate():
		return
	var m := _menu()
	m.set_achievement_count(0, 53)
	await _settle()
	assert_true(
		AchKit.any_text_contains(m, "0/53") or AchKit.any_text_contains(m, "0 / 53"),
		"ilk açılış 0/53"
	)
	m.set_achievement_count(31, 53)
	await _settle()
	assert_true(
		AchKit.any_text_contains(m, "31/53") or AchKit.any_text_contains(m, "31 / 53"), "31/53"
	)


func test_d2_home_signals_reach_the_flow_including_settings() -> void:
	if _gate():
		return
	var m := _menu()
	await _settle()
	watch_signals(m)
	m.play_button.pressed.emit()
	m.characters_button.pressed.emit()
	m.achievements_button.pressed.emit()
	m.scores_button.pressed.emit()
	m.settings_button.pressed.emit()
	assert_signal_emitted(m, "play_requested")
	assert_signal_emitted(m, "characters_requested")
	assert_signal_emitted(m, "achievements_requested")
	assert_signal_emitted(m, "scores_requested")
	assert_signal_emitted(m, "settings_requested")


func test_d3_home_respects_the_safe_area_top_and_bottom() -> void:
	if _gate():
		return
	var m := _menu()
	var extra := Vector4(0.0, 140.0, 0.0, 110.0)
	m.apply_safe_area(extra)
	await _settle()
	assert_lte(
		_bottom(m.version_label), 2400.0 - 72.0 - extra.w + 0.5, "sürüm satırı alt paydan taşmaz"
	)
	assert_lte(
		_bottom(m.settings_button),
		m.version_label.global_position.y + 0.5,
		"düğmeler sürümün üstünde"
	)
	assert_gte(
		m.version_label.global_position.y,
		m.scores_button.global_position.y + 132.0,
		"sürüm düğmelerin altında"
	)
	for n in m.find_children("*", "Label", true, false):
		var l := n as Label
		if l.text.contains("ASHEN") and l.is_visible_in_tree():
			assert_gte(l.global_position.y, 96.0 + extra.y - 0.5, "başlık üst payın altında")


func test_d4_reduced_motion_stops_every_home_particle_emitter() -> void:
	if _gate():
		return
	Settings.hareket_azalt = true
	var m := _menu()
	await _settle()
	for n in m.find_children("*", "CPUParticles2D", true, false):
		var p := n as CPUParticles2D
		assert_false(p.emitting and p.is_visible_in_tree(), "%s: kül/kor durur" % p.name)
	for n in m.find_children("*", "GPUParticles2D", true, false):
		var p := n as GPUParticles2D
		assert_false(p.emitting and p.is_visible_in_tree(), "%s: kül/kor durur" % p.name)


# --- ayarlar ----------------------------------------------------------------------------------------------------------


func test_d5_settings_has_the_four_sections_in_order_with_the_agreed_node_names() -> void:
	if _gate():
		return
	var s := _settings_screen()
	await _settle()
	var last_y := -1.0
	for id in SettingsSections.IDS:
		var n := s.find_child(SettingsSections.node_name(id), true, false) as Control
		assert_not_null(n, "bölüm düğümü %s" % SettingsSections.node_name(id))
		if n != null:
			assert_gt(n.global_position.y, last_y, "%s ekran sırasında" % id)
			last_y = n.global_position.y


func test_d5_settings_title_is_turkish_uppercase_and_motion_row_text_matches_the_design() -> void:
	if _gate():
		return
	var s := _settings_screen()
	await _settle()
	assert_eq(s.title_label.text, "AYARLAR")
	assert_true(AchKit.any_text_contains(s, "HAREKETİ AZALT"), "HAREKETİ AZALT satırı")
	assert_true(
		AchKit.any_text_contains(s, "Hareketli portreleri ve ekran efektlerini durdurur."),
		"kapsam metni (hepsi durur)"
	)
	assert_true(AchKit.any_text_contains(s, "2.1.0"), "HAKKINDA sürüm")


func test_d5_every_settings_touch_target_is_at_least_132_px() -> void:
	if _gate():
		return
	var s := _settings_screen()
	await _settle()
	var checked := 0
	for cls in ["Button", "HSlider"]:
		for n in s.find_children("*", cls, true, false):
			var c := n as Control
			if not c.is_visible_in_tree():
				continue
			checked += 1
			assert_gte(
				maxf(c.size.y, c.custom_minimum_size.y), 132.0 - 0.5, "%s dokunma hedefi" % c.name
			)
	assert_gt(checked, 2, "ayarlar kontrolleri bulundu")


func test_d5_settings_back_button_is_fixed_936x132_and_signals_back() -> void:
	if _gate():
		return
	var s := _settings_screen()
	await _settle()
	assert_almost_eq(s.back_button.size.x, 936.0, 1.0)
	assert_almost_eq(s.back_button.size.y, 132.0, 1.0)
	assert_almost_eq(s.back_button.global_position.y, 2196.0, 1.0, "GERİ sabit y")
	watch_signals(s)
	s.back_button.pressed.emit()
	assert_signal_emitted(s, "back_requested")


func test_d6_settings_flow_remembers_both_entry_sources_and_closes() -> void:
	if _gate():
		return
	var flow := SettingsFlow.new()
	watch_signals(flow)
	flow.open(SettingsFlow.SOURCE_PAUSE)
	assert_eq(flow.source, SettingsFlow.SOURCE_PAUSE, "duraklatmadan açılış")
	flow.close()
	assert_signal_emitted(flow, "closed")
	flow.open(SettingsFlow.SOURCE_MENU)
	assert_eq(flow.source, SettingsFlow.SOURCE_MENU, "ana sayfadan açılış")


func test_d7_motion_toggle_persists_and_old_settings_file_defaults_to_motion_on() -> void:
	if _gate():
		return
	var path := SETTINGS_TMP
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"ses":true,"titresim":true,"karakter":"gunslinger"}')
	f.close()
	var st: Node = load("res://scripts/autoload/settings.gd").new()
	add_child_autofree(st)
	st.load_settings(path)
	assert_false(st.hareket_azalt, "eski dosya: hareket AÇIK (azaltma kapalı)")
	st.hareket_azalt = true
	assert_true(st.save_settings(path))
	var other: Node = load("res://scripts/autoload/settings.gd").new()
	add_child_autofree(other)
	other.load_settings(path)
	assert_true(other.hareket_azalt, "kayıtlı ayar yeniden açılışta korunur")
