extends GutTest
## D3-4 akış: ölüm 1,3 / kazanma 1,8 / seviye ön vurgusu 0,18 sn gecikmesi, atlama kuralları, tek kayıt, rekor bilgisi.

const DIR := "user://hs_ctrl_test"

var _restore: Callable


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_restore = V21Kit.pin_selection("normal", "normal")  # skor listesi normal:normal; kullanıcı ayarından bağımsız


func after_each() -> void:
	_restore.call()


func after_all() -> void:
	_clean()
	DirAccess.remove_absolute(DIR)


func _clean() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, f])


func _controller() -> GameController:
	var c := GameController.new()
	c.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}  # v2.0 izolasyon: yazılamaz yol, gerçek dosya oluşmaz
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.highscores = Highscores.new(DIR + "/hs.json")
	add_child_autofree(c)
	c.start_run()
	return c


func _die(c: GameController) -> void:
	for i in 30:
		c.sim.step(Vector2.ZERO)
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c._after_step()


func test_death_waits_1_3_seconds_staying_in_playing() -> void:
	var c := _controller()
	_die(c)
	assert_eq(c.sim.state, GameSim.State.LOST)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "gecikme boyunca PLAYING")
	assert_true(c._delay.active)
	assert_eq(c._delay.target, PauseLogic.Screen.RESULT)
	assert_almost_eq(c._delay.left, 1.3, 1e-6)
	c._v11_process(1.2)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	c._v11_process(0.11)
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	assert_true(c.result_screen.visible)
	assert_false(c._delay.active)


func test_win_waits_1_8_seconds() -> void:
	var c := _controller()
	var id := c.sim.debug_spawn(&"kale_lordu", Vector2(600, 0))
	c.sim.damage_enemy(id, 1.0e9, &"explosion")
	c.sim.step(Vector2.ZERO)
	c._after_step()
	assert_eq(c.sim.state, GameSim.State.WON)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	assert_almost_eq(c._delay.left, 1.8, 1e-6)
	c._v11_process(1.7)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	c._v11_process(0.2)
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	assert_eq(c.result_screen.title_label.text, "KAZANDIN")


func test_pause_request_during_delay_skips_to_result_once_without_pausing() -> void:
	var c := _controller()
	_die(c)
	c.pause_game()  # geri tuşu ve arka plan da buraya düşer
	assert_eq(c.screen, PauseLogic.Screen.RESULT, "oyun duraklatılmaz, sonuç hemen")
	c.pause_game()
	assert_eq(c.screen, PauseLogic.Screen.RESULT, "ikinci istek no-op")
	c._v11_process(5.0)
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	assert_eq(c.highscores.entries.size(), 1, "skor tek kez")


func test_touch_during_delay_skips_and_is_not_forwarded_to_the_gate() -> void:
	var c := _controller()
	_die(c)
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.index = 0
	ev.position = Vector2(300, 1800)
	c._unhandled_input(ev)
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	assert_false(c.gate.is_active(), "dokunma yürüme girdisi olmadı")


func test_back_key_during_delay_skips() -> void:
	var c := _controller()
	_die(c)
	c._on_back()
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	c._on_back()
	assert_eq(c.screen, PauseLogic.Screen.MENU, "sonuçta geri = ana menü")


func test_background_notification_during_delay_skips() -> void:
	var c := _controller()
	_die(c)
	c._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(c.screen, PauseLogic.Screen.RESULT)


func test_score_saved_once_on_run_end_before_result_screen() -> void:
	var c := _controller()
	var s := c.sim
	s.score.on_kill(&"elit_karga", s.step_count)
	_die(c)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "ekran henüz açılmadı")
	assert_eq(c.highscores.entries.size(), 1, "skor sonuç ekranından önce yazıldı")
	assert_true(FileAccess.file_exists(DIR + "/hs.json"))
	var e := c.highscores.entries[0]
	assert_eq(e["score"], s.score.total())
	assert_false(e["won"])
	assert_gt(e["unix"], 1_700_000_000)
	assert_eq(e["time"], floori(s.time))
	c.flush_delay()
	assert_eq(c.result_screen.record_kind, &"record")
	c._bind(null)
	assert_eq(c.highscores.entries.size(), 1)


func test_replay_does_not_write_a_second_time_and_new_run_can_save() -> void:
	var c := _controller()
	_die(c)
	c.flush_delay()
	var first := c.highscores.entries.size()
	c.result_screen.replay_requested.emit()
	assert_eq(c.highscores.entries.size(), first, "tekrar oyna yazmaz")
	_die(c)
	assert_eq(c.highscores.entries.size(), first + 1, "yeni koşu kendi kaydını yazar")


func test_zero_score_run_is_not_recorded() -> void:
	var c := _controller()
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c._after_step()
	assert_eq(c.sim.state, GameSim.State.LOST)
	assert_eq(c.highscores.entries.size(), 0, "tek adımda survival 0, öldürme yok: score 0")
	c.flush_delay()
	assert_eq(c.result_screen.record_kind, &"none")


func test_level_up_preroll_is_0_18_seconds() -> void:
	var c := _controller()
	c.sim.debug_add_xp(c.sim.xp_to_next)
	c.sim.step(Vector2.ZERO)
	c._after_step()
	assert_eq(c.sim.state, GameSim.State.LEVEL_UP)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	assert_true(c._delay.active)
	assert_almost_eq(c._delay.left, 0.18, 1e-6)
	c._v11_process(0.1)
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	c._v11_process(0.1)
	assert_eq(c.screen, PauseLogic.Screen.LEVEL_UP)
	assert_true(c.level_up.visible)


func test_scores_screen_flow_from_menu_and_back() -> void:
	var c := _controller()
	c.go_menu()
	assert_true(c.menu.visible)
	c.menu.scores_requested.emit()
	assert_eq(c.screen, PauseLogic.Screen.SCORES)
	assert_true(c.scores_screen.visible)
	assert_false(c.menu.visible)
	assert_false(c.hud.visible)
	c._on_back()
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	assert_false(c.scores_screen.visible)
	c.open_scores()
	c.scores_screen.back_requested.emit()
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	c.open_scores()
	V21Kit.use_fake_settings()  # play_with seçimi kaydeder: gerçek user://settings.cfg'ye yazılmasın
	c.scores_screen.play_with_requested.emit(&"normal", &"normal")
	V21Kit.clear_fake_settings()
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	assert_false(c.scores_screen.visible)


func test_open_scores_only_from_menu() -> void:
	var c := _controller()
	c.open_scores()
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
