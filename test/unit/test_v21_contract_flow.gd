extends GutTest
## v2.1 C sözleşmesi: PauseLogic.Screen.RUN, controller bağlantı noktaları (K-C8), satır bütçesi ve eski/yeni sim eşdeğerliği.
## Controller C sonrası değişmez: UI fazları yalnız kendi ekran dosyalarını doldurur.

const DIR := "user://hs_v21_flow"
const CONTROLLER := "res://scripts/ctrl/game_controller.gd"
const CEILING := 960


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()


func after_each() -> void:
	V21Kit.clear_fake_settings()


func after_all() -> void:
	_clean()
	DirAccess.remove_absolute(DIR)


func _clean() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, f])


func _controller() -> GameController:
	var c := GameController.new()
	c.v2_opts = {"achievements_path": "user://yok_klasor_v2_izolasyon/a.json"}
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


# --- PauseLogic ------------------------------------------------------------------------------


func test_contract_run_screen_is_appended_and_goes_back_to_the_menu() -> void:
	assert_eq(PauseLogic.Screen.ACHIEVEMENTS, 8, "mevcut değerler değişmez")
	assert_eq(PauseLogic.Screen.RUN, 9, "yeni ekran sona eklenir")
	assert_eq(PauseLogic.back_action(PauseLogic.Screen.RUN), PauseLogic.Back.TO_MENU)
	assert_eq(PauseLogic.back_action(PauseLogic.Screen.SCORES), PauseLogic.Back.TO_MENU)
	assert_eq(PauseLogic.back_action(PauseLogic.Screen.MENU), PauseLogic.Back.QUIT)


func test_contract_hud_is_hidden_on_menu_result_scores_and_run_screens() -> void:
	for sc in [
		PauseLogic.Screen.MENU,
		PauseLogic.Screen.RESULT,
		PauseLogic.Screen.SCORES,
		PauseLogic.Screen.RUN
	]:
		assert_false(PauseLogic.hud_allowed(sc), str(sc))
	for sc in [PauseLogic.Screen.PLAYING, PauseLogic.Screen.PAUSED, PauseLogic.Screen.LEVEL_UP]:
		assert_true(PauseLogic.hud_allowed(sc), str(sc))


func test_contract_run_screen_never_steps_the_sim_or_auto_pauses() -> void:
	assert_false(PauseLogic.sim_should_step(PauseLogic.Screen.RUN, GameSim.State.RUNNING))
	assert_false(
		PauseLogic.should_auto_pause(Node.NOTIFICATION_APPLICATION_PAUSED, PauseLogic.Screen.RUN)
	)
	assert_eq(
		PauseLogic.screen_after_step(PauseLogic.Screen.RUN, GameSim.State.LOST),
		PauseLogic.Screen.RUN
	)


# --- Controller ------------------------------------------------------------------------------


func test_contract_controller_uses_v21_runs_at_every_touchpoint() -> void:
	var text := FileAccess.get_file_as_string(CONTROLLER)
	for call in [
		"V21Runs.run_opts()",
		"V21Runs.run_won(",
		"V21Runs.score_fields(",
		"V21Runs.scores_key(",
		"V21Runs.set_selection(",
		"highscores.list_for(",
	]:
		assert_true(text.contains(call), call)
	assert_false(text.contains("RUN_OPTS)"), "RUN_OPTS doğrudan sim'e verilmez")
	assert_false(text.contains("highscores.entries"), "controller eski görünümü kullanmaz")


func test_contract_controller_never_submits_scores_without_mode_and_diff() -> void:
	# Eski çağıranlar için submit mode/diff'siz çağrıyı normal:normal'a yazar; controller bunu SESSİZCE yanlış listeye yapmasın.
	var text := FileAccess.get_file_as_string(CONTROLLER)
	assert_false(text.contains(".submit({"), "controller yalnız V21Runs.score_fields ile gönderir")
	var f := V21Runs.score_fields({"score": 5, "mode": "quick", "diff": "hard"}, false)
	assert_true(RunProfiles.MODES.has(f["mode"]) and RunProfiles.DIFFS.has(f["diff"]))
	V21Kit.use_fake_settings()
	var g := V21Runs.score_fields({"score": 5}, false)
	assert_true(
		RunProfiles.MODES.has(g["mode"]) and RunProfiles.DIFFS.has(g["diff"]),
		"stats'ta yoksa seçimden"
	)


func test_contract_controller_stays_within_the_line_ceiling() -> void:
	var lines := FileAccess.get_file_as_string(CONTROLLER).split("\n").size() - 1
	assert_lte(lines, CEILING, "game_controller.gd satır sayısı (tavan %d)" % CEILING)


func test_contract_start_run_builds_the_sim_from_the_selection() -> void:
	var fake := V21Kit.use_fake_settings()
	fake.run_mode = "quick"
	fake.run_diff = "easy"
	var c := _controller()
	assert_eq(c.sim.run_profile.mode, &"quick")
	assert_eq(c.sim.run_profile.diff, &"easy")
	assert_eq(c.sim.end_time, 600.0)


func test_contract_run_screen_opens_from_the_menu_only_and_goes_back() -> void:
	var c := _controller()
	c.open_run_screen()
	assert_eq(c.screen, PauseLogic.Screen.PLAYING, "oyundayken açılmaz")
	c.go_menu()
	c.open_run_screen()
	assert_eq(c.screen, PauseLogic.Screen.RUN)
	assert_false(c.menu.visible)
	c._on_back()
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	assert_true(c.menu.visible)


func test_contract_run_screen_node_visibility_follows_the_screen() -> void:
	var c := _controller()
	c.run_screen = Control.new()
	c.add_child(c.run_screen)
	c.go_menu()
	assert_false(c.run_screen.visible)
	c.open_run_screen()
	assert_true(c.run_screen.visible)
	c.go_menu()
	assert_false(c.run_screen.visible)


func test_contract_play_with_sets_the_selection_and_starts_that_run() -> void:
	var fake := V21Kit.use_fake_settings()
	var c := _controller()
	c.go_menu()
	c.play_with(&"quick", &"easy")
	assert_eq(c.screen, PauseLogic.Screen.PLAYING)
	assert_eq(c.sim.run_profile.mode, &"quick")
	assert_eq(fake.run_mode, "quick")
	assert_eq(fake.run_diff, "easy")


func test_contract_score_is_written_to_the_pair_of_the_finished_run() -> void:
	V21Kit.use_fake_settings()
	var c := _controller()
	c.go_menu()
	c.play_with(&"quick", &"easy")
	c.sim.score.on_kill(&"elit_karga", c.sim.step_count)
	_die(c)
	assert_eq(c.highscores.list_for(&"quick", &"easy").size(), 1, "koşunun kendi listesi")
	assert_eq(c.highscores.entries.size(), 0, "normal:normal'a yazılmaz")


func test_contract_default_run_scores_into_normal_normal() -> void:
	V21Kit.use_fake_settings()
	var c := _controller()
	c.sim.score.on_kill(&"elit_karga", c.sim.step_count)
	_die(c)
	assert_eq(c.highscores.entries.size(), 1)
	assert_eq(c.highscores.list_for(&"normal", &"normal").size(), 1)


func test_contract_scores_open_from_menu_and_result_with_a_pair() -> void:
	V21Kit.use_fake_settings()
	var c := _controller()
	c.sim.score.on_kill(&"elit_karga", c.sim.step_count)
	_die(c)
	c.flush_delay()
	assert_eq(c.screen, PauseLogic.Screen.RESULT)
	c.open_scores(&"quick", &"easy")
	assert_eq(c.screen, PauseLogic.Screen.SCORES)
	assert_false(c.hud.visible, "sim bağlıyken de HUD skor ekranında gizli")
	c._on_back()
	assert_eq(c.screen, PauseLogic.Screen.MENU)
	c.open_scores()
	assert_eq(c.screen, PauseLogic.Screen.SCORES, "çiftsiz: geçerli seçim")


func test_contract_endless_milestone_counts_as_a_win_at_run_end() -> void:
	var fake := V21Kit.use_fake_settings()
	fake.run_mode = "endless"
	var c := _controller()
	c.sim.milestone_won = true
	c.sim.score.on_kill(&"elit_karga", c.sim.step_count)
	_die(c)
	assert_true(c._run_won, "sim LOST ama kilometre taşı kazanıldı")
	assert_true(
		c.highscores.list_for(&"endless", &"normal")[0]["won"], "skor kaydı aynı kazanma değeri"
	)


# --- eski/yeni eşdeğerlik (K-C10 a) ------------------------------------------------------------


func test_contract_legacy_profile_gives_the_same_state_hash_as_no_profile() -> void:
	for seed_value in [11, 23]:
		var plain := GameSim.new(seed_value, &"gunslinger")
		var legacy := GameSim.new(seed_value, &"gunslinger", {"run_profile": RunProfile.legacy()})
		var zor := GameSim.new(
			seed_value, &"gunslinger", {"run_profile": V21Kit.profile(&"normal", &"hard")}
		)
		for i in 600:
			var mv := GoldenKit.move_at(i)
			plain.step(mv)
			legacy.step(mv)
			zor.step(mv)
		assert_eq(legacy.state_hash(), plain.state_hash(), "tohum %d: legacy" % seed_value)
		assert_eq(zor.state_hash(), plain.state_hash(), "tohum %d: Normal/Zor" % seed_value)
		assert_eq(legacy.rng_combat.state, plain.rng_combat.state)
