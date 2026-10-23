extends GutTest
## PauseLogic: arka plan/odak kaybı kararı, geri tuşu, LEVEL_UP'ta sim donuk, girdi kilidi, adım biriktirici.

const S := PauseLogic.Screen
const B := PauseLogic.Back


func test_app_paused_and_focus_out_pause_only_while_playing() -> void:
	for what in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		assert_true(PauseLogic.should_auto_pause(what, S.PLAYING))
		for sc in [S.MENU, S.LEVEL_UP, S.PAUSED, S.CONFIRM, S.RESULT]:
			assert_false(PauseLogic.should_auto_pause(what, sc), "ekran %d" % sc)


func test_other_notifications_do_not_pause() -> void:
	assert_false(PauseLogic.should_auto_pause(Node.NOTIFICATION_APPLICATION_RESUMED, S.PLAYING))
	assert_false(PauseLogic.should_auto_pause(Node.NOTIFICATION_APPLICATION_FOCUS_IN, S.PLAYING))


func test_back_button_actions() -> void:
	assert_eq(PauseLogic.back_action(S.PLAYING), B.PAUSE)
	assert_eq(PauseLogic.back_action(S.PAUSED), B.RESUME)
	assert_eq(PauseLogic.back_action(S.CONFIRM), B.CANCEL_CONFIRM)
	assert_eq(PauseLogic.back_action(S.RESULT), B.TO_MENU)
	assert_eq(PauseLogic.back_action(S.MENU), B.QUIT)
	assert_eq(PauseLogic.back_action(S.LEVEL_UP), B.NONE)


func test_sim_steps_only_when_playing_and_running() -> void:
	assert_true(PauseLogic.sim_should_step(S.PLAYING, GameSim.State.RUNNING))
	assert_false(PauseLogic.sim_should_step(S.PLAYING, GameSim.State.LEVEL_UP), "LEVEL_UP donuk")
	assert_false(PauseLogic.sim_should_step(S.PLAYING, GameSim.State.WON))
	assert_false(PauseLogic.sim_should_step(S.PLAYING, GameSim.State.LOST))
	for sc in [S.MENU, S.LEVEL_UP, S.PAUSED, S.CONFIRM, S.RESULT]:
		assert_false(PauseLogic.sim_should_step(sc, GameSim.State.RUNNING))


func test_level_up_state_freezes_a_real_sim() -> void:
	var sim := GameSim.new(7, &"gunslinger", {"end_mode": "timer", "end_time": 480.0})
	sim.debug_add_xp(sim.xp_to_next)
	sim.step(Vector2.ZERO)
	assert_eq(sim.state, GameSim.State.LEVEL_UP)
	assert_false(PauseLogic.sim_should_step(S.PLAYING, sim.state))
	var t := sim.time
	sim.step(Vector2.RIGHT)  # sim kendisi de donuk: no-op
	assert_eq(sim.time, t)
	assert_eq(PauseLogic.screen_after_step(S.PLAYING, sim.state), S.LEVEL_UP)


func test_screen_after_step() -> void:
	assert_eq(PauseLogic.screen_after_step(S.PLAYING, GameSim.State.RUNNING), S.PLAYING)
	assert_eq(PauseLogic.screen_after_step(S.PLAYING, GameSim.State.LEVEL_UP), S.LEVEL_UP)
	assert_eq(PauseLogic.screen_after_step(S.PLAYING, GameSim.State.WON), S.RESULT)
	assert_eq(PauseLogic.screen_after_step(S.PLAYING, GameSim.State.LOST), S.RESULT)
	assert_eq(PauseLogic.screen_after_step(S.PAUSED, GameSim.State.LOST), S.PAUSED)


func test_input_lock_after_resume_and_level_up_only() -> void:
	assert_true(PauseLogic.needs_input_lock(S.PAUSED, S.PLAYING))
	assert_true(PauseLogic.needs_input_lock(S.LEVEL_UP, S.PLAYING))
	assert_false(PauseLogic.needs_input_lock(S.MENU, S.PLAYING))
	assert_false(PauseLogic.needs_input_lock(S.RESULT, S.PLAYING))
	assert_false(PauseLogic.needs_input_lock(S.PLAYING, S.PAUSED))


func test_steps_for_caps_at_three() -> void:
	var st := GameSim.STEP
	assert_eq(PauseLogic.steps_for(st * 0.5, st), 0)
	assert_eq(PauseLogic.steps_for(st * 1.5, st), 1)
	assert_eq(PauseLogic.steps_for(st * 2.5, st), 2)
	assert_eq(PauseLogic.steps_for(st * 10.0, st), 3)
	assert_eq(PauseLogic.steps_for(1.0, st), PauseLogic.MAX_STEPS_PER_FRAME)


func test_leftover_drops_excess_for_slow_motion() -> void:
	var st := GameSim.STEP
	assert_almost_eq(PauseLogic.leftover(st * 2.5, 2, st), st * 0.5, 1e-6)
	assert_lt(PauseLogic.leftover(st * 10.0, 3, st), st, "fazlası atılır (yavaş çekim)")
	assert_eq(PauseLogic.leftover(0.0, 0, st), 0.0)


func test_scores_screen_back_returns_to_menu() -> void:
	assert_eq(PauseLogic.back_action(S.SCORES), B.TO_MENU)
	assert_eq(PauseLogic.back_action(S.RESULT), B.TO_MENU, "sonuç davranışı değişmedi")
	assert_eq(S.SCORES, 6, "enum sonuna eklendi; mevcut değerler kaymaz")
	assert_eq(S.RESULT, 5)


func test_scores_screen_never_steps_the_sim_or_auto_pauses() -> void:
	assert_false(PauseLogic.sim_should_step(S.SCORES, GameSim.State.RUNNING))
	for what in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		assert_false(PauseLogic.should_auto_pause(what, S.SCORES))
	assert_eq(PauseLogic.screen_after_step(S.SCORES, GameSim.State.LOST), S.SCORES)
	assert_false(PauseLogic.needs_input_lock(S.SCORES, S.PLAYING))


func test_result_delay_is_1_3_for_death_and_1_8_for_a_win() -> void:
	assert_almost_eq(PauseLogic.result_delay(false), 1.3, 1e-9)
	assert_almost_eq(PauseLogic.result_delay(true), 1.8, 1e-9)
	assert_eq(PauseLogic.LEVEL_UP_PREROLL, 0.18)


func test_motion_tokens_match_design_5_3() -> void:
	var want := {
		"RECOIL_KICK": 40,
		"RECOIL_BACK": 110,
		"MUZZLE_FLASH": 80,
		"HIT_FLASH": 90,
		"HIT_TINT": 200,
		"HIT_KNOCK": 50,
		"HIT_SPRING": 220,
		"TURN": 70,
		"LEVELUP_PREROLL": 180,
		"LEVELUP_RING": 450,
		"DEATH_FREEZE": 120,
		"DEATH_FALL": 600,
		"DEATH_TOTAL": 1300,
		"WIN_TOTAL": 1800,
		"ENEMY_FLASH": 125,
		"LORD_TELEGRAPH": 600,
		"LORD_SLAM": 120,
		"LORD_ENRAGE": 900,
		"BOMB_FUSE": 800,
		"PICKUP_FLY": 120,
		"PICKUP_TOAST": 700,
		"SCORE_EASE": 180,
		"SCORE_POP_UP": 80,
		"SCORE_POP_DOWN": 160,
		"RESULT_COUNT": 900,
		"RESULT_ROW_STAGGER": 120,
		"RECORD_STAMP": 280,
		"RESULT_BUTTONS": 1300,
		"RESULT_STAMP_AT": 1250,
	}
	var consts: Dictionary = Motion.new().get_script().get_script_constant_map()
	for k in want.keys():
		assert_eq(consts.get(k), want[k], "Motion.%s" % k)
	assert_eq(
		[
			consts["ENEMY_DEATH_FAST"],
			consts["ENEMY_DEATH_PIYADE"],
			consts["ENEMY_DEATH_GHOST"],
			consts["ENEMY_DEATH_ELITE"]
		],
		[220, 420, 700, 900]
	)
	assert_eq(Motion.sec(1300), 1.3)
	assert_eq(
		Motion.LEVELUP_PREROLL, int(PauseLogic.LEVEL_UP_PREROLL * 1000.0), "PauseLogic ile tutarlı"
	)
