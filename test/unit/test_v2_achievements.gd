extends GutTest
## V2Achievements (B3/B4 bağlama): depo/tracker yaşam döngüsü, bildirim, sonuç özeti, flush noktaları, ekran açılışı.
## Gerçek GameController; kayıt yolu ve saat v2_opts ile enjekte edilir (gerçek user:// dosyalarına dokunulmaz).

const PATH := "user://test_ach_v2flow.json"
const HS_PATH := "user://test_ach_v2flow_hs.json"
const T0 := 1761270000

var _chars_before: String = ""
var _now: int = T0


func before_each() -> void:
	_chars_before = get_node("/root/Settings").character_id
	get_node("/root/Settings").character_id = ""
	_now = T0
	_clean()


func after_each() -> void:
	get_node("/root/Settings").character_id = _chars_before
	_clean()


func _clean() -> void:
	for p in [PATH, HS_PATH]:
		for suffix in ["", ".tmp", ".bad"]:
			if FileAccess.file_exists(p + suffix):
				DirAccess.remove_absolute(p + suffix)


func _ctrl(extra: Dictionary = {}) -> GameController:
	var gc := GameController.new()
	gc.v2_opts = {"achievements_path": PATH, "clock": func() -> int: return _now}
	gc.v2_opts.merge(extra, true)
	add_child_autofree(gc)
	gc.highscores = Highscores.new(HS_PATH)  # koşu sonu skor kaydı gerçek dosyaya yazmasın
	return gc


func _kill(gc: GameController, n: int = 1) -> void:
	for _i in n:
		gc.sim.bus.enemy_killed.emit(&"curumus_piyade", Vector2.ZERO)


func _saved() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))


func test_build_world_creates_store_toast_and_screen() -> void:
	var gc := _ctrl()
	var a := gc.v2.achievements
	assert_not_null(a.store)
	assert_eq(a.store.path, PATH)
	assert_not_null(a.toast)
	assert_eq(a.toast.get_parent(), gc.hud.toast_host)
	assert_not_null(a.screen)
	assert_false(a.screen.visible)
	assert_eq(a.toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_menu_counter_reflects_store() -> void:
	var s := AchievementStore.new(PATH)
	s.unlock(&"ilk_kan", T0)
	s.unlock(&"gelecek_basarim", T0)
	assert_true(s.save())
	var gc := _ctrl()
	assert_eq(
		(gc.menu.achievements_button.get_node("Sub") as Label).text,
		"1/22",
		"bilinmeyen kimlik sayılmaz"
	)


func test_bind_creates_tracker_with_sim_character() -> void:
	var gc := _ctrl()
	assert_null(gc.v2.achievements.tracker)
	gc.start_run()
	var t := gc.v2.achievements.tracker
	assert_not_null(t)
	assert_eq(t.char_id, gc.sim.character.id)
	gc.go_menu()
	assert_null(gc.v2.achievements.tracker, "menüye dönüşte tracker bırakılır")


func test_no_tracker_when_definitions_missing() -> void:
	var gc := _ctrl({"data": GameData.new()})
	gc.start_run()
	assert_null(gc.v2.achievements.tracker)
	gc.pause_game()  # çökmez
	assert_eq(gc.screen, PauseLogic.Screen.PAUSED)


func test_unlock_shows_toast_without_stopping_sim() -> void:
	var gc := _ctrl()
	gc.start_run()
	var a := gc.v2.achievements
	_kill(gc)
	gc._update_views(0.016)
	assert_true(a.toast.visible)
	assert_eq(a.queue.current(), &"ilk_kan")
	assert_eq(a.toast.name_label.text, "İLK KAN")
	var t0 := gc.sim.time
	gc.sim.step(Vector2.ZERO)
	assert_gt(gc.sim.time, t0, "sim durmaz")


func test_toast_freezes_while_view_dt_is_zero_and_expires() -> void:
	var gc := _ctrl()
	gc.start_run()
	var a := gc.v2.achievements
	_kill(gc)
	gc._update_views(0.016)
	var ph := a.queue.phase()
	gc.v2.update_views(0.0)
	gc.v2.update_views(0.0)
	assert_eq(a.queue.phase(), ph, "view_dt=0 iken kuyruk donar")
	gc.v2.update_views(3.0)
	assert_false(a.toast.visible)
	assert_eq(a.queue.current(), &"")


func test_queue_overflow_still_records_unlocks() -> void:
	var gc := _ctrl()
	gc.start_run()
	var a := gc.v2.achievements
	gc.sim.bus.level_up.emit(20)  # seviye_10 + seviye_20
	_kill(gc)  # ilk_kan
	gc.sim.bus.evolution_gained.emit(&"x")  # ilk_evrim
	gc.sim.bus.score_changed.emit(100000, 1, 5)  # skor_100k
	gc.sim.bus.streak_changed.emit(5, 1.0)  # seri_ustasi
	gc.sim.bus.reload_started.emit(1.0)
	assert_gt(a.queue.overflow, 0, "kuyruk taştı")
	for id in [&"seviye_10", &"seviye_20", &"ilk_kan", &"ilk_evrim", &"skor_100k", &"seri_ustasi"]:
		assert_true(a.store.is_unlocked(id), "%s kayıtta" % id)


func test_run_ended_orders_finish_then_summary_then_flush() -> void:
	var gc := _ctrl()
	gc.start_run()
	_kill(gc)
	gc.sim.bus.evolution_gained.emit(&"x")
	var a := gc.v2.achievements
	assert_false(FileAccess.file_exists(PATH), "kare içinde yazma yok")
	gc._on_run_ended(false, {"score": 10, "time": 12.0, "level": 2, "kills": 1, "evolutions": []})
	assert_true(gc.result_screen.has_new_achievements())
	assert_eq(gc.result_screen.chip_title.text, "YENİ BAŞARIM · 2")
	assert_eq(gc.result_screen.chip_names.text, "İlk Kan, İlk Evrim")
	var d := _saved()
	assert_eq(int(d["unlocked"]["ilk_kan"]), T0)
	assert_eq(int(d["totals"]["runs"]), 1, "finish toplamları dosyada")
	assert_eq(a.tracker.run_unlocked().size(), 2, "N = run_unlocked sayısı")
	assert_false(a.queue.current() != &"", "sonuç gelince kuyruk atılır")


func test_result_without_new_achievements_keeps_v11_layout() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc._on_run_ended(false, {"score": 0, "time": 3.0, "level": 1, "kills": 0, "evolutions": []})
	assert_false(gc.result_screen.has_new_achievements())
	assert_false(gc.result_screen.achievement_chip.visible)


func test_stale_summary_is_cleared_on_next_run() -> void:
	var gc := _ctrl()
	gc.start_run()
	_kill(gc)
	gc._on_run_ended(false, {"score": 0, "time": 3.0, "level": 1, "kills": 1, "evolutions": []})
	assert_true(gc.result_screen.has_new_achievements())
	gc.start_run()
	gc._on_run_ended(false, {"score": 0, "time": 3.0, "level": 1, "kills": 0, "evolutions": []})
	assert_false(gc.result_screen.has_new_achievements(), "ikinci koşuda yeni açılış yok")


func test_pause_game_flushes_unlocks() -> void:
	var gc := _ctrl()
	gc.start_run()
	_kill(gc)
	assert_false(FileAccess.file_exists(PATH))
	gc.pause_game()
	assert_true(_saved()["unlocked"].has("ilk_kan"))


func test_restart_flushes_previous_tracker() -> void:
	var gc := _ctrl()
	gc.start_run()
	_kill(gc)
	gc.start_run()  # YENİDEN BAŞLAT
	assert_true(_saved()["unlocked"].has("ilk_kan"), "açılış kaybolmaz")


func test_go_menu_mid_run_flushes() -> void:
	var gc := _ctrl()
	gc.start_run()
	_kill(gc)
	gc.go_menu()
	assert_true(_saved()["unlocked"].has("ilk_kan"))


func test_double_finish_counts_once() -> void:
	var gc := _ctrl()
	gc.start_run()
	var stats := {"score": 0, "time": 3.0, "level": 1, "kills": 0, "evolutions": []}
	gc._on_run_ended(false, stats)
	gc._on_run_ended(false, stats)
	assert_eq(int(_saved()["totals"]["runs"]), 1)


func test_save_failure_keeps_game_running_and_dirty() -> void:
	var gc := _ctrl({"achievements_path": "user://yok_klasor_ach/x.json"})
	gc.start_run()
	_kill(gc)
	gc.pause_game()
	assert_true(gc.v2.achievements.store.dirty)
	assert_eq(gc.screen, PauseLogic.Screen.PAUSED)


func test_open_achievements_shows_screen_and_back_returns() -> void:
	var s := AchievementStore.new(PATH)
	s.unlock(&"ilk_kan", T0)
	s.save()
	var gc := _ctrl()
	gc.open_achievements()
	assert_eq(gc.screen, PauseLogic.Screen.ACHIEVEMENTS)
	var scr := gc.v2.achievements.screen
	assert_true(scr.visible)
	assert_eq(scr.row_count(), 22)
	assert_false(gc.menu.visible)
	scr.back_button.pressed.emit()
	assert_eq(gc.screen, PauseLogic.Screen.MENU)
	assert_false(scr.visible)
	assert_true(gc.menu.visible)


func test_open_achievements_outside_menu_is_noop() -> void:
	var gc := _ctrl()
	gc.start_run()
	gc.open_achievements()
	assert_eq(gc.screen, PauseLogic.Screen.PLAYING)


func test_safe_area_forwarded_to_screen() -> void:
	var gc := _ctrl()
	gc.v2.apply_safe_areas(Vector4(0, 100, 0, 150))
	gc.open_achievements()
	var scr := gc.v2.achievements.screen
	assert_gte(scr.title_label.position.y, 196.0)
	assert_lte(scr.back_button.position.y + scr.back_button.size.y, 2400.0 - 72.0 - 150.0)


func test_release_flushes_and_is_safe() -> void:
	var gc := _ctrl()
	gc.start_run()
	_kill(gc)
	gc.v2.release()
	assert_true(_saved()["unlocked"].has("ilk_kan"))
	gc.v2.update_views(0.1)  # release sonrası no-op


func test_build_world_publishes_store_in_shared_refs() -> void:
	var refs := {}
	var a := V2Achievements.new({"achievements_path": PATH, "data": GameData.load_default()})
	a.build_world(refs)
	assert_same(refs.get("store", null), a.store)
	a.release()


func test_characters_slice_reads_the_same_store_through_refs() -> void:
	var gc := _ctrl()
	assert_same(gc.v2.characters._store(), gc.v2.achievements.store)
