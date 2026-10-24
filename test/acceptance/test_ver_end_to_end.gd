extends GutTest
## Doğrulama (T20261023-64): baştan sona oyun. GameController gerçek ekran akışıyla (menü → oyun → seviye atlama →
## beceri seçimi → evrim → 20. dk Kale Lordu → Lord ölümü = kazanma → sonuç ekranı → tekrar) ve ölüm yolu.
## Controller kare döngüsü (`_process`) yerine `sim.step` + `_after_step` ile elle sürülür: süre/duvar saatine bağlı iddia yok.

const WON_SUB := "Şafak söktü; kale seni yutamadı."
const LOST_SUB := "Kale seni yuttu."
## Kale Lordu'nu makul sürede devirecek donanım (denge ölçümü: tools/balance, rapor "Denge gözlemi").
const STRONG_BUILD: Array = [
	[&"seken_mermi", 5],
	[&"barut_kesesi", 3],
	[&"son_mermi_patlar", 5],
	[&"hizli_doldurma", 3],
	[&"doldurma_sacilmasi", 5],
	[&"fazladan_mermi", 3],
	[&"dinamit", 5],
	[&"keskin_nisan", 5],
	[&"agir_kursun", 5],
	[&"hizli_parmak", 5],
]

const TMP_SCORES := "user://test_end_to_end_highscores.json"


func after_all() -> void:
	for p in [TMP_SCORES, TMP_SCORES + ".tmp", TMP_SCORES + ".bad"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _controller() -> GameController:
	var c := GameController.new()
	c.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}  # v2.0 izolasyon: yazılamaz yol, gerçek dosya oluşmaz
	c.highscores = Highscores.new(TMP_SCORES)  # v2.0 izolasyon: gerçek highscores.json'a yazılmaz
	c.process_mode = Node.PROCESS_MODE_DISABLED  # sim'i test sürer
	add_child_autofree(c)
	return c


## Bir oyun adımı + controller'ın adım sonrası ekran geçişi.
func _tick(c: GameController, move: Vector2 = Vector2.ZERO) -> void:
	c.sim.step(move)
	c._after_step()
	c.flush_delay()  # v1.1: seviye ön vurgusu / sonuç gecikmesi süresini beklemeden biter


func _find_label(root: Node, text: String) -> Label:
	if root is Label and (root as Label).text == text:
		return root
	for ch in root.get_children():
		var found := _find_label(ch, text)
		if found != null:
			return found
	return null


func _card_index(sim: GameSim, kind: StringName) -> int:
	var cards := sim.pending_choices()
	for i in cards.size():
		if cards[i].kind == kind:
			return i
	return -1


func test_menu_title_tag_is_ash_and_steel() -> void:
	var c := _controller()
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	assert_not_null(_find_label(c.menu, "ASH AND STEEL"), "menü üst yazısı 'ASH AND STEEL'")
	assert_null(_find_label(c.menu, "KÜL VE ÇELİK"), "eski üst yazı kalmamalı")
	assert_not_null(_find_label(c.menu, "ASHEN\nBASTION"), "menü başlığı")


func test_full_run_menu_to_lord_victory_to_result_screen() -> void:
	seed(64)
	var c := _controller()
	c.start_run()
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	assert_eq(c.sim.end_mode, "lord", "tam oyun Lord modunda")
	assert_eq(c.sim.end_time, 1200.0, "20 dakika")
	var warned: Array = []
	var spawned: Array = []
	c.sim.bus.boss_warning.connect(func(k: StringName) -> void: warned.append(k))
	c.sim.bus.boss_spawned.connect(func(k: StringName) -> void: spawned.append(k))

	# 1) seviye atla -> beceri seç
	c.sim.debug_add_xp(c.sim.xp_to_next)
	_tick(c)
	assert_eq(c.screen, PauseLogic.Screen.LEVEL_UP, "XP eşiği ekranı seviye atlamaya geçirir")
	assert_eq(c.sim.state, GameSim.State.LEVEL_UP)
	assert_true(c.level_up.visible)
	var n_cards := c.sim.pending_choices().size()
	assert_between(n_cards, 1, 3)
	var level_before := c.sim.level
	c._on_choice(0)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "seçimden sonra oyun sürer")
	assert_eq(c.sim.level, level_before)
	assert_false(c.level_up.visible)

	# 2) evrim kur: aktif 5 + eşleşen pasif => evrim kartı seçilebilir
	c.sim.debug_grant(&"seken_mermi", 5)
	c.sim.debug_grant(&"barut_kesesi", 1)
	c.sim.debug_add_xp(c.sim.xp_to_next)
	_tick(c)
	assert_eq(c.screen, PauseLogic.Screen.LEVEL_UP)
	var evo := _card_index(c.sim, Choice.KIND_EVOLUTION)
	assert_gte(evo, 0, "evrim kartı sunulur")
	assert_eq(evo, c.sim.pending_choices().size() - 1, "evrim kartı en altta")
	c._on_choice(evo)
	assert_true(&"zincirleme_patlama" in c.sim.evolved_log, "evrim kuruldu")
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)

	# 3) 20. dakikaya atla, güçlü donanım + ölümsüzlük (ölçüm), Lord'u öldür
	for g in STRONG_BUILD:
		c.sim.debug_grant(g[0], g[1])
	c.sim.debug_grant(&"kiyamet_mermisi")
	c.sim.debug_grant(&"mermi_firtinasi")
	c.sim.debug_set_time(1190.0)
	var guard := 0
	while c.screen != PauseLogic.Screen.RESULT and guard < 60 * 400:
		guard += 1
		SimKit.godmode(c.sim)  # choose() max_hp'yi yeniden kurar; her adım yenilenir
		if c.screen == PauseLogic.Screen.LEVEL_UP:
			c._on_choice(0)
			continue
		_tick(c, Bots.move(&"kite", c.sim))
	assert_eq(
		c.screen, PauseLogic.Screen.RESULT, "Lord ölümü sonuç ekranına götürür (guard %d)" % guard
	)
	assert_eq(c.sim.state, GameSim.State.WON)
	assert_true(c.sim.lord_killed, "kazanma Lord ölümünden")
	assert_gte(c.sim.time, 1200.0)
	assert_eq(spawned.count(&"kale_lordu"), 1, "Lord tam bir kez doğdu")
	assert_eq(warned.count(&"kale_lordu"), 1, "Lord uyarısı bir kez")
	assert_eq(c.sim.check_invariants(), PackedStringArray())

	# 4) sonuç ekranı
	assert_true(c.result_screen.visible)
	assert_eq(c.result_screen.title_label.text, "KAZANDIN")
	assert_eq(c.result_screen.sub_label.text, WON_SUB, "kazanma alt başlığı")
	assert_true(c.result_screen.won)
	assert_gte(float(c.result_screen.stats["time"]), 1200.0)
	assert_gte(int(c.result_screen.stats["level"]), 3)
	assert_gt(int(c.result_screen.stats["kills"]), 0)
	assert_true(
		&"zincirleme_patlama" in c.result_screen.stats["evolutions"],
		"kurulan kombo sonuç verisinde"
	)
	assert_gte(c.result_screen.combo_box.get_child_count(), 1, "kombo paneli dolu")
	assert_false(c.hud.visible, "sonuç ekranında HUD gizli")
	assert_false(c.joystick.visible, "joystick kapalı")

	# 5) tekrar oyna: her oyun sıfırdan başlar
	c.result_screen.replay_requested.emit()
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	assert_eq(c.sim.state, GameSim.State.RUNNING)
	assert_eq(c.sim.level, 1)
	assert_eq(c.sim.time, 0.0)
	assert_eq(c.sim.evolved_log.size(), 0)
	assert_eq(c.sim.kills, 0)


func test_death_path_to_game_over_screen() -> void:
	seed(65)
	var c := _controller()
	c.start_run()
	for i in 120:
		_tick(c)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	# ölüm ile bekleyen seviye atlama aynı adımda: ölüm kazanır, seçim iptal
	c.sim.debug_add_xp(c.sim.xp_to_next)
	c.sim.hp = 0.0
	_tick(c)
	assert_eq(c.sim.state, GameSim.State.LOST)
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	assert_eq(c.result_screen.title_label.text, "OYUN BİTTİ")
	assert_eq(c.result_screen.sub_label.text, LOST_SUB)
	assert_false(c.result_screen.won)
	assert_eq(c.sim.pending_choices().size(), 0, "bekleyen seçim iptal")
	c.go_menu()
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	assert_null(c.sim)


func test_natural_death_by_idling_ends_the_run() -> void:
	# Gerçek kural: hareketsiz oyuncu 20 dk'ya ulaşamaz (ölümsüzlük yok), süre/seviye/öldürme raporlanır.
	var sim := SimKit.make(66, {"data_kind": "real"})
	var ended: Array = []
	sim.bus.run_ended.connect(func(w: bool, st: Dictionary) -> void: ended.append([w, st]))
	var rng := Bots.make_rng(66)
	Bots.play(sim, Bots.IDLE, 60 * 600, rng, 0)
	assert_eq(sim.state, GameSim.State.LOST, "hareketsiz oyuncu ölür")
	assert_lt(sim.time, 400.0, "ölüm erken: oyun anlamlı tehdit içerir")
	assert_eq(ended.size(), 1)
	assert_false(ended[0][0])
	for k in ["time", "level", "kills", "evolutions"]:
		assert_true((ended[0][1] as Dictionary).has(k), "run_ended.%s" % k)
