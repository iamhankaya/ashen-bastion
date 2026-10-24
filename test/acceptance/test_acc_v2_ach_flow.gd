extends GutTest
## Kabul (v2.0 B5/B6 akış + dayanıklılık): gerçek GameController ile koşu sonu → kayıt → sonuç özeti, duraklama/yeniden başlatma/menü
## flush, kayıt yazılamazken oyunun sürmesi, boş başarım tanımı. `v2_opts` ile geçici kayıt/veri (add_child'dan ÖNCE).
## Sinyal yolu gerçektir: olaylar controller'ın sim.bus'una verilir. Dilim B bitmeden pending.

const NORMAL := ExpectedTablesV2.NORMAL_ENEMY

var _store_path: String = ""
var _character_id: String = ""
var _ach_path: String = ""
var _ctrl: GameController = null


class CountingStore:
	extends AchievementStore
	var saves: int = 0

	func save() -> bool:
		saves += 1
		return super.save()


func before_each() -> void:
	var st := get_node("/root/Settings")
	_store_path = st.store_path
	_character_id = st.character_id
	st.store_path = AchKit.tmp_path("settings")
	st.character_id = ""
	_ach_path = AchKit.tmp_path("flow")


func after_each() -> void:
	_free_controller()
	var st := get_node("/root/Settings")
	st.store_path = _store_path
	st.character_id = _character_id
	AchKit.cleanup()


func after_all() -> void:
	SimKit.remove_tmp()


## Denetleyici AchKit.cleanup()'tan ÖNCE serbest bırakılır: _exit_tree -> release -> flush dosyayı yeniden yazardı (USER_LEAK).
func _free_controller() -> void:
	if _ctrl != null and is_instance_valid(_ctrl):
		if _ctrl.get_parent() != null:
			_ctrl.get_parent().remove_child(_ctrl)
		_ctrl.free()
	_ctrl = null


func _gate() -> bool:
	return V2Slice.require(self, "B")


func _controller(extra: Dictionary = {}) -> GameController:
	var c := GameController.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	var o := {"data": AchKit.data(), "achievements_path": _ach_path, "clock": AchKit.clock()}
	o.merge(extra, true)
	c.v2_opts = o
	add_child(c)
	_ctrl = c
	c.highscores = Highscores.new(AchKit.tmp_path("hs"))
	return c


func _end_run(c: GameController) -> void:
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)


func _reload() -> AchievementStore:
	var st := AchievementStore.new(_ach_path)
	st.load_file()
	return st


func test_b5_run_end_finishes_tracker_before_result_and_flushes_file() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	c.sim.bus.enemy_killed.emit(NORMAL, Vector2.ZERO)
	assert_false(
		FileAccess.file_exists(_ach_path), "olay yolu diske yazmaz (kare içinde yazma yok)"
	)
	_end_run(c)
	assert_ne(c.screen, PauseLogic.Screen.RESULT, "finish sonuç ekranından ÖNCE (gecikme sürüyor)")
	assert_true(FileAccess.file_exists(_ach_path), "run_ended sonunda flush")
	var st := _reload()
	assert_true(st.is_unlocked(&"ilk_kan"))
	assert_eq(int(st.totals["runs"]), 1, "finish koşu sayısını işledi")
	c.flush_delay()
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	assert_true(
		AchKit.any_text_contains(c.result_screen, UiKit.upper_tr("Yeni başarım · 1")),
		"özet: YENİ BAŞARIM · 1 (N == run_unlocked().size())"
	)


func test_b5_result_chip_absent_when_nothing_unlocked() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	_end_run(c)
	c.flush_delay()
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	assert_false(
		AchKit.any_text_contains(c.result_screen, UiKit.upper_tr("Yeni başarım")),
		"açılış yok: v1.1 düzeni"
	)


func test_b5_result_summary_lists_first_two_names_plus_remaining() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	var bus := c.sim.bus
	bus.enemy_killed.emit(NORMAL, Vector2.ZERO)  # İlk Kan
	bus.level_up.emit(10)  # Onuncu Basamak
	for i in 5:
		bus.pickup_collected.emit(&"kizil_iksir", Vector2.ZERO)  # Eklenti Avcısı
	_end_run(c)
	c.flush_delay()
	var tx := UiKit.upper_tr("Yeni başarım · 3")
	assert_true(AchKit.any_text_contains(c.result_screen, tx), "N = 3")
	assert_true(AchKit.any_text_contains(c.result_screen, UiKit.upper_tr("İlk Kan")), "ilk isim")
	assert_true(
		AchKit.any_text_contains(c.result_screen, UiKit.upper_tr("Onuncu Basamak")), "ikinci isim"
	)
	assert_true(AchKit.any_text_contains(c.result_screen, "+1"), "kalan sayısı")


func test_b5_pause_flushes_unsaved_unlocks() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	c.sim.bus.enemy_killed.emit(NORMAL, Vector2.ZERO)
	assert_false(FileAccess.file_exists(_ach_path))
	c.pause_game()
	assert_true(FileAccess.file_exists(_ach_path), "duraklatma yazar")
	assert_true(_reload().is_unlocked(&"ilk_kan"))


func test_b5_restart_flushes_previous_tracker_without_loss() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	c.sim.bus.enemy_killed.emit(NORMAL, Vector2.ZERO)
	var old_sim := c.sim
	c.start_run()  # YENİDEN BAŞLAT / Tekrar Oyna
	assert_true(_reload().is_unlocked(&"ilk_kan"), "önceki koşunun açılışı kaybolmaz")
	old_sim.bus.enemy_killed.emit(NORMAL, Vector2.ZERO)
	assert_eq(_stored_kills(c), 1, "eski sim'in olayları artık sayılmaz (tracker ayrıldı)")
	c.sim.bus.enemy_killed.emit(NORMAL, Vector2.ZERO)
	assert_eq(_stored_kills(c), 2, "yeni tracker kendi olaylarını sayar")


func _stored_kills(c: GameController) -> int:
	return int((c.v2.achievements.store as AchievementStore).totals["kills"])


func test_b5_mid_run_go_menu_flushes_previous_tracker() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	c.sim.bus.enemy_killed.emit(NORMAL, Vector2.ZERO)
	c.go_menu()
	assert_true(_reload().is_unlocked(&"ilk_kan"), "koşu ortası menüye dönüş yazar")
	assert_eq(c.screen, PauseLogic.Screen.MENU)


func test_b5_double_run_ended_counts_once() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	_end_run(c)
	c._on_run_ended(false, c._run_stats)  # aynı koşuda ikinci bildirim
	var st := _reload()
	assert_eq(int(st.totals["runs"]), 1, "çift finish tek sayım")


func test_b5_save_count_is_bounded_per_run() -> void:
	if _gate():
		return
	var c := _controller()
	var cs := CountingStore.new(_ach_path)
	c.v2.achievements.store = cs
	c.start_run()
	c.sim.bus.enemy_killed.emit(NORMAL, Vector2.ZERO)
	for i in 300:
		c._update_views(1.0 / 60.0)
	assert_eq(cs.saves, 0, "kare içinde kayıt yok")
	c.pause_game()
	c.resume_game()
	var after_pause := cs.saves
	assert_lte(after_pause, 1)
	_end_run(c)
	c.flush_delay()
	assert_lte(cs.saves, 2, "koşu başına en çok 1 + duraklama sayısı")


func test_b5_unwritable_store_does_not_stop_the_game() -> void:
	if _gate():
		return
	var parent := AchKit.tmp_path("blocked")
	AchKit.write_text(parent, "dosya")
	var c := _controller({"achievements_path": parent + "/alt.json"})
	c.start_run()
	c.sim.bus.enemy_killed.emit(NORMAL, Vector2.ZERO)
	c.pause_game()
	c.resume_game()
	for i in 10:
		c.sim.step(Vector2.ZERO)
	assert_eq(c.sim.state, GameSim.State.RUNNING, "kayıt yazılamaz: oyun sürer")
	_end_run(c)
	c.flush_delay()
	assert_eq(c.screen, PauseLogic.Screen.RESULT)


func test_b5_many_unlocks_in_one_frame_are_all_recorded_despite_toast_overflow() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_run()
	var bus := c.sim.bus
	bus.enemy_killed.emit(NORMAL, Vector2.ZERO)  # ilk_kan
	bus.enemy_killed.emit(&"elit_piyade", Vector2.ZERO)  # piyade_avcisi
	bus.level_up.emit(10)  # seviye_10
	bus.evolution_gained.emit(&"x")  # ilk_evrim
	bus.streak_changed.emit(5, 1.0)  # seri_ustasi
	for i in 5:
		bus.pickup_collected.emit(&"kizil_iksir", Vector2.ZERO)  # eklenti_avcisi
	c.pause_game()
	var st := _reload()
	for id in [
		"ilk_kan", "piyade_avcisi", "seviye_10", "ilk_evrim", "seri_ustasi", "eklenti_avcisi"
	]:
		assert_true(st.is_unlocked(StringName(id)), "%s kayıtta (bildirim taşsa bile)" % id)
	assert_eq(c.sim.state, GameSim.State.RUNNING, "bildirim sim'i durdurmaz")
	c.sim.step(Vector2.ZERO)


func test_b5_empty_achievement_definitions_do_not_build_a_tracker_or_crash() -> void:
	if _gate():
		return
	var dir := SimKit.copy_data(SimKit.REAL_DIR, "noach")
	SimKit.write_json(dir.path_join("achievements.json"), [])
	var empty := GameData.load_dir(dir)
	assert_eq(empty.achievements.size(), 0, "ön koşul")
	var c := _controller({"data": empty})
	c.start_run()
	c.sim.bus.enemy_killed.emit(NORMAL, Vector2.ZERO)
	_end_run(c)
	c.flush_delay()
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	assert_false(AchKit.any_text_contains(c.result_screen, UiKit.upper_tr("Yeni başarım")))


func test_b5_stress_run_counts_nothing_and_writes_nothing() -> void:
	if _gate():
		return
	var c := _controller()
	c.start_stress()
	c.pause_game()
	assert_false(FileAccess.file_exists(_ach_path), "stres koşusu kayıt yazmaz")
	c.go_menu()
	assert_false(FileAccess.file_exists(_ach_path))


func test_b5_menu_shows_unlocked_counter_from_store() -> void:
	if _gate():
		return
	var pre := AchievementStore.new(_ach_path)
	pre.unlock(&"ilk_kan", 1700000000)
	pre.unlock(&"bes_dakika", 1700000000)
	assert_true(pre.save())
	var c := _controller()
	c.go_menu()
	assert_true(AchKit.any_text_contains(c.menu, "2/22"), "menü sayacı kayıttan: 2/22")


func test_b5_run_end_when_tracker_unaware_character_chars5_flow() -> void:
	if _gate():
		return
	# K-tur ek senaryosunun B yarısı: aynı kayıtla iki ardışık koşu, iki karakter; 300 sn koşu stats'ı ile.
	var c := _controller()
	var st := get_node("/root/Settings")
	st.character_id = "gunslinger"
	c.start_run()
	c.sim.debug_set_time(300.0)
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c.flush_delay()
	st.character_id = "barutcu"
	c.start_run()
	assert_eq(c.sim.character.id, &"barutcu")
	c.sim.debug_set_time(300.0)
	c.sim.hp = 0.0
	c.sim.step(Vector2.ZERO)
	c.flush_delay()
	var loaded := _reload()
	assert_eq(loaded.chars5.size(), 2, "iki karakter 300 sn")
	assert_true(loaded.is_unlocked(&"cifte_yol"))
