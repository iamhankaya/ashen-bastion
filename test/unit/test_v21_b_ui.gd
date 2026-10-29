extends GutTest
## v2.1 B dilimi (U4b): sonuç çipleri/Kolay notu/sıra satırı/+44 kaydı, skorlar ekranı sekmeleri, Sonsuz kilometre taşı
## bandı, HUD debug sayacı, müzik kararı. Godot yerelde koşmaz: CI.

const STATS := {
	"time": 1500.0,
	"level": 12,
	"kills": 400,
	"score": 9000,
	"best_mult": 3,
	"evolutions": [],
	"score_parts": {"kills": 100, "streak": 10, "evolution": 0, "survival": 50, "lord": 0},
}

var fake: V21Kit.FakeSettings


func before_each() -> void:
	fake = V21Kit.use_fake_settings()


func after_each() -> void:
	V21Kit.clear_fake_settings()


func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1080, 2400)
	add_child_autofree(host)
	return host


func _stats(mode: String, diff: String, extra: Dictionary = {}) -> Dictionary:
	var d := STATS.duplicate(true)
	d["mode"] = mode
	d["diff"] = diff
	d.merge(extra, true)
	return d


func _combos(n: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for k in n:
		rows.append({"id": &"zincirleme_patlama", "name": "Kıyamet", "pair": "A + B", "icon": ""})
	return rows


func _result(
	p_won: bool, stats: Dictionary, n_combos: int = 0, rec: Dictionary = {}
) -> ResultScreen:
	var r := ResultScreen.new()
	_host().add_child(r)
	r.show_result(p_won, stats, _combos(n_combos), "", rec)
	return r


func _entry(score: int) -> Dictionary:
	return {"score": score, "time": 600, "won": true, "level": 5, "unix": 1_700_000_000}


func _scores(
	entries: Array[Dictionary] = [], mode := &"normal", diff := &"normal"
) -> HighscoreScreen:
	var s := HighscoreScreen.new()
	_host().add_child(s)
	s.show_scores(entries, -1, mode, diff)
	return s


# --- saf metinler --------------------------------------------------------------------------------------------


func test_b1_mss_has_no_leading_zero_minute() -> void:
	assert_eq(MilestoneBand.mss(300.0), "5:00")
	assert_eq(MilestoneBand.mss(468.9), "7:48")
	assert_eq(MilestoneBand.mss(-3.0), "0:00")


func test_b2_band_hint_follows_the_repeat_interval() -> void:
	assert_eq(MilestoneBand.hint_text(300.0), "Lord 5:00 sonra daha güçlü döner.")
	assert_eq(MilestoneBand.hint_text(0.0), "", "tekrar kapalıysa satır yok")


func test_b3_rank_line_is_mode_then_difficulty() -> void:
	assert_eq(ResultScreen.rank_line(&"normal", &"hard", 3), "Normal · Zor listesinde 3. sıra")
	assert_eq(ResultScreen.rank_line(&"endless", &"hard", 1), "Sonsuz · Zor listesinde 1. sıra")
	assert_eq(ResultScreen.rank_line(&"normal", &"hard", 0), "", "10 dışı: satır gizlenir")
	assert_eq(ResultScreen.rank_line(&"", &"", 2), "", "mod bilinmiyorsa boş")


func test_b4_endless_sub_counts_from_the_first_lord_death() -> void:
	assert_eq(
		ResultScreen.endless_sub(1668.0, 1200.0), "Lord'u devirdin; sonra 7:48 daha dayandın."
	)
	assert_eq(ResultScreen.endless_sub(1668.0, -1.0), "", "kilometre taşı yoksa boş")


func test_b5_empty_tab_text_names_the_pair() -> void:
	assert_eq(
		HighscoreScreen.empty_text_for(&"endless", &"hard"),
		"Sonsuz · Zor listesinde kayıt yok.\nBu ayarla oynayıp ilk skoru yaz."
	)


# --- kilometre taşı bandı ------------------------------------------------------------------------------------


func test_b6_band_phase_enters_holds_and_fades() -> void:
	var start := MilestoneBand.phase(0.0, false)
	assert_almost_eq(float(start["alpha"]), 0.0, 1e-6)
	assert_lt(float(start["dy"]), 0.0, "yukarıdan kayar")
	var mid := MilestoneBand.phase(1.0, false)
	assert_eq([mid["alpha"], mid["dy"]], [1.0, 0.0])
	var fading := MilestoneBand.phase(MilestoneBand.SHOW_SEC - 0.2, false)
	assert_almost_eq(float(fading["alpha"]), 0.5, 1e-3)
	assert_false(MilestoneBand.phase(MilestoneBand.SHOW_SEC, false)["visible"])


func test_b7_reduced_motion_is_instant_but_lasts_the_same() -> void:
	var p := MilestoneBand.phase(0.0, true)
	assert_eq([p["alpha"], p["dy"]], [1.0, 0.0])
	assert_true(MilestoneBand.phase(MilestoneBand.SHOW_SEC - 0.01, true)["visible"])
	assert_false(MilestoneBand.phase(MilestoneBand.SHOW_SEC, true)["visible"])


func test_b8_band_ignores_touch_and_hides_after_3_2_seconds() -> void:
	var b := MilestoneBand.new()
	_host().add_child(b)
	b.show_band(300.0, false)
	assert_true(b.visible)
	assert_eq(b.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(b.hint_label.text, "Lord 5:00 sonra daha güçlü döner.")
	b.advance(3.0)
	assert_true(b.visible)
	b.advance(0.3)
	assert_false(b.visible)
	assert_eq(b.size, Vector2(MilestoneBand.W, MilestoneBand.H))


func test_b9_hud_shows_the_band_on_milestone_and_counts_in_endless() -> void:
	var sim := GameSim.new(5, &"gunslinger", V21Kit.profile(&"endless", &"hard").opts())
	var hud := Hud.new()
	_host().add_child(hud)
	hud.bind(sim)
	assert_false(hud.milestone_band.visible)
	sim.bus.milestone_reached.emit()
	assert_true(hud.milestone_band.visible)
	hud.refresh(4.0)
	assert_false(hud.milestone_band.visible, "3,2 sn sonra söner")
	assert_string_contains(Hud.endless_counter_text(sim), "Lord ×0")
	assert_string_contains(Hud.endless_counter_text(sim), "düşman 0/")
	hud.bind(null)
	assert_false(hud.milestone_band.visible)


# --- sonuç ekranı --------------------------------------------------------------------------------------------


func test_b10_result_blocks_shift_44_px_and_chips_sit_at_352() -> void:
	assert_eq(ResultScreen.Y_DIV, 424.0)
	assert_eq(ResultScreen.Y_STRIP, 1228.0 + 44.0)
	assert_eq(ResultScreen.Y_COMBOS, 1422.0 + 44.0)
	var r := _result(false, _stats("normal", "hard"))
	assert_true(r.chip_holder.visible)
	assert_eq(r.chip_holder.position.y, ResultScreen.Y_CHIPS + r._dy)
	assert_not_null(r.chip_holder.find_child("ModeChip", true, false))
	assert_not_null(r.chip_holder.find_child("DiffChip", true, false))
	assert_null(r.chip_holder.find_child("LordChip", true, false), "Lord çipi yalnız Sonsuz")


func test_b11_lord_chip_only_in_endless_with_kills() -> void:
	var e := _result(true, _stats("endless", "normal", {"lords_killed": 2, "milestone_t": 1200.0}))
	var chip := e.chip_holder.find_child("LordChip", true, false)
	assert_not_null(chip)
	assert_eq(((chip as Node).find_children("*", "Label", true, false)[0] as Label).text, "LORD ×2")
	var none := _result(false, _stats("endless", "normal", {"lords_killed": 0}))
	assert_null(none.chip_holder.find_child("LordChip", true, false))
	var normal := _result(true, _stats("normal", "normal", {"lords_killed": 3}))
	assert_null(normal.chip_holder.find_child("LordChip", true, false))


func test_b12_stats_without_mode_keep_the_old_look() -> void:
	var r := _result(false, STATS.duplicate(true))
	assert_false(r.chip_holder.visible)
	assert_false(r.easy_note.visible)


func test_b13_easy_note_shows_only_for_easy_and_pushes_combos_down() -> void:
	var easy := _result(false, _stats("normal", "easy"), 2)
	var hard := _result(false, _stats("normal", "hard"), 2)
	assert_true(easy.easy_note.visible)
	assert_false(hard.easy_note.visible)
	assert_eq(easy.easy_note.size.y, ResultScreen.NOTE_H)
	assert_almost_eq(
		easy.combo_panel.position.y - hard.combo_panel.position.y,
		ResultScreen.NOTE_H + ResultScreen.GAP,
		0.01
	)


func test_b14_endless_win_subtitle_and_loss_subtitle() -> void:
	var win := _result(true, _stats("endless", "hard", {"lords_killed": 1, "milestone_t": 1200.0}))
	assert_eq(win.sub_label.text, "Lord'u devirdin; sonra 5:00 daha dayandın.")
	var lost := _result(false, _stats("endless", "hard"))
	assert_eq(lost.sub_label.text, ResultScreen.LOST_SUB)
	var quick := _result(true, _stats("quick", "hard"))
	assert_eq(quick.sub_label.text, ResultScreen.WON_SUB)


func test_b15_rank_line_prefixes_record_and_top10_notes() -> void:
	var top := {"rank": 3, "is_record": false, "previous_best": 900, "needed_for_top10": 0}
	var r := _result(true, _stats("normal", "hard"), 0, top)
	assert_eq(r.record_note.text, "Normal · Zor listesinde 3. sıra")
	var rec := {"rank": 1, "is_record": true, "previous_best": 154200, "needed_for_top10": 0}
	var q := _result(true, _stats("quick", "easy"), 0, rec)
	assert_eq(q.record_note.text, "Hızlı · Kolay listesinde 1. sıra · Önceki en iyi: 154.200")
	var out := {"rank": 0, "is_record": false, "previous_best": 5, "needed_for_top10": 62400}
	var o := _result(false, _stats("normal", "hard"), 0, out)
	assert_eq(o.record_note.text, "10. sıra için gereken: 62.400", "10 dışı: sıra satırı yok")


func test_b16_worst_case_blocks_do_not_overlap_and_buttons_fit() -> void:
	var r := ResultScreen.new()
	_host().add_child(r)
	r.set_new_achievements(["AİLE II", "AİLE III"] as Array[String])
	var stats := _stats(
		"endless", "easy", {"lords_killed": 3, "milestone_t": 900.0, "score_parts": {"lord": 5000}}
	)
	r.show_result(true, stats, _combos(4), "", {"rank": 2, "is_record": false, "previous_best": 1})
	var breakdown_bottom := r.breakdown_panel.position.y + r.breakdown_panel.size.y
	assert_lte(breakdown_bottom, ResultScreen.Y_STRIP + r._dy, "döküm şeritten önce biter")
	var chip_bottom := r.chip_holder.position.y + ResultScreen.CHIP_ROW_H
	assert_lte(chip_bottom, r.divider.position.y, "çipler ayraçtan önce biter")
	assert_lte(r.easy_note.position.y + r.easy_note.size.y, r.achievement_chip.position.y)
	assert_lte(r.achievement_chip.position.y + r.achievement_chip.size.y, r.combo_panel.position.y)
	assert_lte(r.content_bottom(), 2400.0 - ResultScreen.BOTTOM_DEFAULT, "düğmeler ekrana sığar")


# --- skorlar ekranı ------------------------------------------------------------------------------------------


func test_b17_two_tab_rows_with_three_tabs_each_and_open_on_the_given_pair() -> void:
	# Adı tarihsel: sekme sayısı katalogdan türer (her mod/zorluk için bir sekme), seçili sekme çiftin indeksidir.
	var s := _scores([], &"endless", &"hard")
	var modes := RunStrip.mode_order()
	var diffs := RunStrip.diff_order()
	assert_eq([s.mode_tabs.size(), s.diff_tabs.size()], [modes.size(), diffs.size()])
	assert_eq([s.sel_mode, s.sel_diff], [&"endless", &"hard"])
	for i in modes.size():
		assert_eq(s.mode_tabs[i].selected, modes[i] == &"endless", "mod sekmesi %s" % modes[i])
	for i in diffs.size():
		assert_eq(s.diff_tabs[i].selected, diffs[i] == &"hard", "zorluk sekmesi %s" % diffs[i])
	assert_eq(s.mode_tabs[0].position.y, HighscoreScreen.Y_TAB_MODE)
	assert_eq(s.diff_tabs[0].position.y, HighscoreScreen.Y_TAB_DIFF)
	assert_eq(s.mode_tabs[0].size.y, HighscoreScreen.TAB_H)
	var last_diff := s.diff_tabs[diffs.size() - 1]
	assert_lte(last_diff.position.x + last_diff.size.x, 1080.0 - 72.0 + 0.01)
	assert_lt(s.diff_tabs[0].position.y + HighscoreScreen.TAB_H, s.rows[0].position.y)


func _tab_name(kind: String, title: String, on: bool, total: int, i: int) -> String:
	var ord: String = ["birincisi", "ikincisi", "üçüncüsü"][i] if i < 3 else "%d." % (i + 1)
	return (
		"%s sekmesi, %s, %s, %s sekmeden %s"
		% [kind, title, "seçili" if on else "seçili değil", RunStrip.spoken(total), ord]
	)


func test_b18_tab_labels_and_a11y() -> void:
	# Sayı sözcüğü ve sıra katalogdan türer: Normal'in/Zor'un sırası `order`dan okunur (sabit "üç" yok).
	var s := _scores([], &"normal", &"hard")
	var modes := RunStrip.mode_order()
	var diffs := RunStrip.diff_order()
	var mi := modes.find(&"normal")
	var ni := diffs.find(&"normal")
	var hi := diffs.find(&"hard")
	assert_eq(
		s.mode_tabs[mi].accessibility_name, _tab_name("Mod", "Normal", true, modes.size(), mi)
	)
	assert_eq(
		s.diff_tabs[ni].accessibility_name, _tab_name("Zorluk", "Normal", false, diffs.size(), ni)
	)
	assert_eq(
		s.diff_tabs[hi].accessibility_name, _tab_name("Zorluk", "Zor", true, diffs.size(), hi)
	)
	# Biçim sabiti (katalogdan bağımsız): üçlü katalogda üçüncü sekme.
	assert_eq(
		_tab_name("Zorluk", "Zor", true, 3, 2), "Zorluk sekmesi, Zor, seçili, üç sekmeden üçüncüsü"
	)


func test_b19_pressing_a_tab_loads_that_list() -> void:
	var hs := Highscores.new()
	var s := _scores([], &"normal", &"normal")
	s.store = hs
	watch_signals(s)
	s.mode_tabs[0].pressed.emit()
	assert_eq([s.sel_mode, s.sel_diff], [&"quick", &"normal"])
	s.diff_tabs[2].pressed.emit()
	assert_eq([s.sel_mode, s.sel_diff], [&"quick", &"hard"], "ikinci sıra ilkini korur")
	assert_signal_emit_count(s, "tab_changed", 2)
	assert_eq(s.empty_text.text, HighscoreScreen.empty_text_for(&"quick", &"hard"))


func test_b20_filled_tab_shows_rows_and_empty_tab_shows_play_button() -> void:
	var hs := Highscores.new()
	var s := _scores([_entry(5000), _entry(4000)], &"normal", &"normal")
	s.store = hs  # depoda hiçbir liste yok: sekme değişince boş sekme
	assert_false(s.empty)
	assert_false(s.play_button.visible)
	s.diff_tabs[0].pressed.emit()
	assert_true(s.empty)
	assert_true(s.play_button.visible)
	assert_eq(s.play_button.text, "BU AYARLA OYNA")
	assert_eq(s.play_button.accessibility_name, "Normal modda, Kolay zorlukta oyna")


func test_b21_play_button_carries_the_tab_pair() -> void:
	var s := _scores([], &"endless", &"hard")
	watch_signals(s)
	s.play_button.pressed.emit()
	assert_signal_emitted_with_parameters(s, "play_with_requested", [&"endless", &"hard"])
	assert_signal_emit_count(s, "play_requested", 1, "eski sözleşme sinyali de yayılır")


func test_b22_ten_rows_end_above_back_button_with_tabs() -> void:
	var list: Array[Dictionary] = []
	for i in 10:
		list.append(_entry(9000 - i))
	var s := _scores(list)
	var last := s.rows[9]
	assert_almost_eq(last.position.y + last.size.y, 2172.0, 0.01)
	assert_gte(last.size.y, HighscoreScreen.ROW_MIN_H)
	s.apply_safe_area(Vector4(0, 100, 0, 150))
	var limit := 2400.0 - 72.0 - 150.0
	assert_lte(s.back_button.position.y + s.back_button.size.y, limit)
	for r in s.rows:
		assert_lte(r.position.y + r.size.y, s.back_button.position.y)
	assert_gte(s.mode_tabs[0].position.y, 96.0 + 100.0)


# --- müzik kararı --------------------------------------------------------------------------------------------


func test_b23_music_plays_win_cue_only_after_an_endless_milestone_run_ends() -> void:
	var sim := GameSim.new(5, &"gunslinger", V21Kit.profile(&"endless", &"hard").opts())
	sim.milestone_won = true
	assert_false(V21Runs.music_won(sim), "koşu sürerken savaş müziği")
	assert_false(V21Runs.music_lost(sim))
	sim.state = GameSim.State.LOST
	assert_true(V21Runs.music_won(sim), "kilometre taşı sonrası ölüm = zafer müziği")
	assert_false(V21Runs.music_lost(sim))
	sim.milestone_won = false
	assert_true(V21Runs.music_lost(sim))
	assert_false(V21Runs.music_won(null))
	assert_false(V21Runs.music_lost(null))
