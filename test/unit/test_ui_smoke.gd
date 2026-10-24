extends GutTest
## UI duman testi: her UI/görünüm sınıfı instantiate + add_child + _ready (shader derlemesi sınanmaz).
## Sim isteyen ekranlar gerçek ama adımlanmamış bir GameSim ile açılır.


func _sim() -> GameSim:
	return GameSim.new(3, &"gunslinger", {"end_mode": "timer", "end_time": 480.0})


func _choice(kind: StringName, id: StringName, from_l: int, to_l: int) -> Choice:
	var c := Choice.new()
	c.kind = kind
	c.skill_id = id
	c.from_level = from_l
	c.to_level = to_l
	c.title = "Kart"
	c.desc = "Açıklama"
	return c


func test_theme_and_fonts_load_with_turkish_glyphs() -> void:
	var t := UiKit.theme()
	assert_true(ResourceLoader.exists(UiKit.THEME_PATH))
	var f := t.get_font(&"font", &"LabelTitle")
	assert_not_null(f)
	for ch in ["İ", "ı", "Ş", "ğ", "Ç", "Ü"]:
		assert_true(f.has_char(ch.unicode_at(0)), "Cinzel: %s" % ch)
		assert_true(t.default_font.has_char(ch.unicode_at(0)), "Inter: %s" % ch)


func test_main_menu_builds() -> void:
	var m := MainMenu.new()
	add_child_autofree(m)
	assert_eq(m.play_button.text, "OYNA")
	m.open(false, true)
	assert_eq(m.sound_button.text, "SES: KAPALI")
	assert_eq(m.vibration_button.text, "TİTREŞİM: AÇIK")


func test_main_menu_version_triple_tap() -> void:
	var m := MainMenu.new()
	add_child_autofree(m)
	assert_false(m.register_version_tap())
	assert_false(m.register_version_tap())
	assert_true(m.register_version_tap())
	assert_false(m.register_version_tap(), "sayaç sıfırlanır")


func test_hud_binds_and_shows_sim_values() -> void:
	var h := Hud.new()
	add_child_autofree(h)
	var sim := _sim()
	sim.time = 125.0
	sim.hp = 20.0
	h.bind(sim)
	assert_eq(h.timer_label.text, "02:05")
	assert_eq(h.hp_label.text, "20 / 100")
	assert_eq(h.active_slots.size(), 6)
	assert_eq(h.passive_slots.size(), 6)
	assert_false(h.active_slots[0].is_empty(), "başlangıç becerisi ilk yuvada")
	assert_true(h.active_slots[5].is_empty())
	assert_eq(h.drum.count, sim.magazine.count)
	assert_eq(h.pause_button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_hud_helpers() -> void:
	assert_eq(Hud.hp_text(85.2, 120.0), "86 / 120")
	assert_eq(Hud.hp_text(-3.0, 100.0), "0 / 100")
	assert_true(Hud.is_critical(24.0, 100.0))
	assert_false(Hud.is_critical(25.0, 100.0))
	assert_eq(Hud.boss_text(&"kale_lordu"), "KALE LORDU GELİYOR")
	assert_eq(Hud.boss_text(&"elit_piyade"), "ARA BOSS YAKLAŞIYOR")


func test_magazine_drum_states() -> void:
	var d := MagazineDrum.new()
	add_child_autofree(d)
	d.set_state(4, 6, false, 0.0)
	assert_eq(d.describe(), "Şarjör 4 / 6")
	assert_true(MagazineDrum.slot_filled(3, 4, 6, false))
	assert_false(MagazineDrum.slot_filled(4, 4, 6, false))
	assert_false(MagazineDrum.slot_filled(0, 6, 6, true), "doldururken yuvalar boş")
	d.set_state(0, 6, true, 0.5)
	assert_eq(d.describe(), "Şarjör dolduruluyor")


func test_level_up_screen_orders_evolution_last_and_locks() -> void:
	var s := LevelUpScreen.new()
	add_child_autofree(s)
	var choices: Array = [
		_choice(Choice.KIND_EVOLUTION, &"zincirleme_patlama", 0, 1),
		_choice(Choice.KIND_UPGRADE, &"seken_mermi", 4, 5),
		_choice(Choice.KIND_NEW, &"hizli_doldurma", 0, 1),
	]
	s.show_choices(choices, 4)
	assert_eq(s.cards.size(), 3)
	assert_eq(s.order, PackedInt32Array([1, 2, 0]), "evrim en altta, sim indeksi korunur")
	assert_eq(s.title_label.text, "SEVİYE 4")
	assert_true(s.is_locked())
	assert_true(s.cards[0].disabled)
	watch_signals(s)
	s._on_card_pressed(1)
	assert_signal_not_emitted(s, "chosen", "500 ms kilitte seçim yok")


func test_level_up_single_heal_card() -> void:
	var s := LevelUpScreen.new()
	add_child_autofree(s)
	s.show_choices([_choice(Choice.KIND_HEAL, &"", 0, 0)], 9)
	assert_eq(s.cards.size(), 1)
	assert_eq(LevelUpScreen.tag_text(Choice.KIND_HEAL), "ŞİFA")
	assert_eq(LevelUpScreen.level_text(Choice.KIND_UPGRADE, 4, 5), "Sv. 4 › 5")


func test_pause_screen_confirm_flow() -> void:
	var p := PauseScreen.new()
	add_child_autofree(p)
	var sim := _sim()
	p.open(sim.loadout.actives(), sim.loadout.passives(), true, false)
	assert_eq(p.vibration_button.text, "TİTREŞİM: KAPALI")
	assert_false(p.is_confirm_open())
	p.open_confirm(PauseScreen.Confirm.MENU)
	assert_true(p.is_confirm_open())
	assert_eq(p.dialog_ok.text, "ANA MENÜYE DÖN")
	watch_signals(p)
	p._on_confirm_ok()
	assert_signal_emitted(p, "menu_confirmed")
	assert_false(p.is_confirm_open())


func test_result_screen_empty_and_combo_states() -> void:
	var r := ResultScreen.new()
	add_child_autofree(r)
	r.show_result(false, {"time": 872.0, "level": 17, "kills": 1482, "evolutions": []})
	assert_eq(r.title_label.text, "OYUN BİTTİ")
	assert_false(r.buttons_enabled(), "800 ms düğme gecikmesi")
	assert_true(r.replay_button.disabled)
	r.finish_count()
	assert_eq(r.time_value.text, "14:32")
	assert_eq(r.kills_value.text, "1.482")
	assert_eq(r.combo_box.get_child_count(), 1)
	var rows: Array[Dictionary] = [{"id": &"zincirleme_patlama", "name": "Zincirleme", "pair": ""}]
	r.show_result(true, {"time": 480.0, "level": 9, "kills": 12, "evolutions": []}, rows)
	assert_eq(r.title_label.text, "KAZANDIN")


func test_formatters() -> void:
	assert_eq(UiKit.format_time(0.0), "00:00")
	assert_eq(UiKit.format_time(479.9), "07:59")
	assert_eq(UiKit.format_thousands(2941), "2.941")
	assert_eq(UiKit.format_thousands(1234567), "1.234.567")
	assert_eq(UiKit.format_thousands(12), "12")


func test_game_controller_screen_flow() -> void:
	var c := GameController.new()
	c.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}  # v2.0 izolasyon: yazılamaz yol, gerçek dosya oluşmaz
	c.process_mode = Node.PROCESS_MODE_DISABLED  # sim adımlanmaz; yalnız geçişler
	add_child_autofree(c)
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	assert_true(c.menu.visible)
	c.start_run()
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	assert_not_null(c.sim)
	assert_true(c.hud.visible)
	c.pause_game()
	assert_eq(c.screen, PauseLogic.Screen.PAUSED)
	c._on_back()
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "geri tuşu duraklatmada devam eder")
	assert_true(c.gate.is_locked(), "devam sonrası 600 ms kilit")
	c._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(c.screen, PauseLogic.Screen.PAUSED, "arka plana alınınca duraklar")
	c.go_menu()
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	assert_null(c.sim)


# --- v1.1 iskeleti: HUD öğeleri gizli, denetleyici çağrı satırları yerinde ---------------------------


class SpyController:
	extends GameController
	var calls: Array = []

	func _v11_build_world() -> void:
		calls.append(["build_world"])

	func _v11_bind(new_sim: GameSim) -> void:
		calls.append(["bind", new_sim])

	func _v11_update_views(view_dt: float) -> void:
		calls.append(["update_views", view_dt])

	func _v11_on_run_ended(won: bool, stats: Dictionary) -> void:
		calls.append(["run_ended", won, stats])

	func _v11_on_screen(next: int) -> void:
		calls.append(["screen", next])


func test_hud_v11_elements_exist_hidden_and_sit_in_the_safe_layer() -> void:
	var h := Hud.new()
	add_child_autofree(h)
	for c in [h.score_block, h.buff_row, h.offscreen_arrow, h.float_text]:
		assert_not_null(c)
		assert_false(c.visible, "%s gizli doğar (v1 HUD davranışı aynen)" % c.name)
		assert_true(h.safe.is_ancestor_of(c), "%s güvenli katman içinde" % c.name)
		assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	# DESIGN §3.2 / §2.4: skor sütunu sağ 36, üst 284; rozet satırı sol alt, alt 72.
	assert_eq(h.score_block.anchor_left, 1.0)
	assert_eq(h.score_block.offset_right, -36.0)
	assert_eq(h.score_block.offset_top, 284.0)
	assert_eq(h.buff_row.anchor_top, 1.0)
	assert_eq(h.buff_row.offset_bottom, -72.0)
	assert_eq(h.buff_row.offset_bottom - h.buff_row.offset_top, 108.0)
	assert_eq(h.buff_row.offset_left, 0.0)
	assert_eq(h.buff_row.offset_right, 231.0 + 3 * 120.0 - 12.0)
	h.apply_safe_area(Vector4(40, 20, 10, 5))
	assert_true(h.safe.is_ancestor_of(h.score_block), "çentik payı yeni öğelere de uygulanır")


func test_hud_bind_and_refresh_with_v11_elements_leave_no_stub_calls() -> void:
	var h := Hud.new()
	add_child_autofree(h)
	var sim := _sim()
	h.bind(sim)
	for i in 3:
		h.refresh(0.016)
	h.bind(null)
	assert_eq(Stub.calls().size(), 0, "gizli öğeler iskelete düşmez: %s" % [Stub.calls()])


func test_controller_v11_call_lines_are_placed_once() -> void:
	var c := SpyController.new()
	c.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}  # v2.0 izolasyon
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(c)
	assert_eq(c.calls[0], ["build_world"], "açılışta bir kez, world ve ui kurulduktan sonra")
	assert_eq(c.calls.count(["build_world"]), 1)
	assert_true(c.calls.has(["bind", null]), "go_menu -> _bind(null)")
	assert_true(c.calls.has(["screen", PauseLogic.Screen.MENU]))
	assert_not_null(c.highscores)
	c.calls.clear()
	c.start_run()
	assert_eq(c.calls[0], ["bind", c.sim], "_bind sonunda, sim ile")
	assert_true(
		c.calls.has(["update_views", 0.0]),
		"start_run ilk güncelleme: ekran henüz PLAYING değil -> view_dt 0"
	)
	assert_eq(c.calls[c.calls.size() - 1], ["screen", PauseLogic.Screen.PLAYING])
	c.calls.clear()
	c._update_views(0.5)
	assert_eq(c.calls, [["update_views", 0.5]], "PLAYING iken view_dt = dt")
	c.pause_game()
	c.calls.clear()
	c._update_views(0.5)
	assert_eq(c.calls, [["update_views", 0.0]], "duraklatmada view_dt = 0")
	c.calls.clear()
	c._on_run_ended(false, {"time": 1.0})
	assert_eq(c.calls, [["run_ended", false, {"time": 1.0}]])
	assert_false(c._run_won)
	assert_eq(Stub.calls().size(), 0)
	Stub.reset()


func after_each() -> void:
	Stub.reset()
