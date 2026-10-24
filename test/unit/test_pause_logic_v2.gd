extends GutTest
## PauseLogic v2.0: yeni ekranlar enum SONUNA eklendi (mevcut değerler değişmedi); geri tuşu ikisi için ana menü.

const S := PauseLogic.Screen
const B := PauseLogic.Back


func test_existing_screen_values_unchanged_and_new_ones_appended() -> void:
	assert_eq(S.MENU, 0)
	assert_eq(S.PLAYING, 1)
	assert_eq(S.LEVEL_UP, 2)
	assert_eq(S.PAUSED, 3)
	assert_eq(S.CONFIRM, 4)
	assert_eq(S.RESULT, 5)
	assert_eq(S.SCORES, 6)
	assert_eq(S.CHARACTERS, 7)
	assert_eq(S.ACHIEVEMENTS, 8)


func test_back_goes_to_menu_from_new_screens() -> void:
	assert_eq(PauseLogic.back_action(S.CHARACTERS), B.TO_MENU)
	assert_eq(PauseLogic.back_action(S.ACHIEVEMENTS), B.TO_MENU)
	assert_eq(PauseLogic.back_action(S.SCORES), B.TO_MENU, "v1.1 davranışı değişmedi")
	assert_eq(PauseLogic.back_action(S.MENU), B.QUIT)


func test_new_screens_never_auto_pause_or_step_the_sim() -> void:
	for sc in [S.CHARACTERS, S.ACHIEVEMENTS]:
		for what in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
			assert_false(PauseLogic.should_auto_pause(what, sc), "ekran %d" % sc)
		assert_false(PauseLogic.sim_should_step(sc, GameSim.State.RUNNING), "ekran %d" % sc)
		assert_eq(PauseLogic.screen_after_step(sc, GameSim.State.LOST), sc, "ekran %d" % sc)
		assert_false(PauseLogic.needs_input_lock(sc, S.PLAYING), "ekran %d" % sc)
