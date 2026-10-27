extends GutTest
## Sözleşme (S3): game_controller.gd satır bütçesi. v2 mantığı V2Flow + 3 dilim sınıfında yaşar; controller yalnız
## tek satırlık delegasyon taşır (taban 912, gdlint tavanı 1000, bu test tavanı 960; S3 sonu ≤ 946).

const CONTROLLER := "res://scripts/ctrl/game_controller.gd"
const CEILING := 960
const S3_CEILING := 960  # v2.1 C fazı: 946 + 7 (V21Runs delegasyonu, KOSU ekranı, open_scores parametreleri); kalan pay 7
const GAME_DATA := "res://scripts/sim/game_data.gd"
const GAME_SIM := "res://scripts/sim/game_sim.gd"


func _lines(path: String) -> int:
	return FileAccess.get_file_as_string(path).split("\n").size() - 1


func test_controller_stays_under_the_ceiling() -> void:
	assert_lte(_lines(CONTROLLER), CEILING, "game_controller.gd satır sayısı (tavan %d)" % CEILING)


func test_controller_after_contract_phase_within_s3_budget() -> void:
	assert_lte(_lines(CONTROLLER), S3_CEILING, "sözleşme fazı bütçesi (912 + 34)")


func test_controller_has_no_v2_decision_logic() -> void:
	var text := FileAccess.get_file_as_string(CONTROLLER)
	assert_false(text.contains("AchievementTracker"), "tracker controller'da yaşamaz")
	assert_false(text.contains("AchievementStore"), "depo controller'da yaşamaz")
	assert_false(text.contains("CharacterRoster"), "karakter çözümleme V2Flow'da")
	assert_false(
		text.contains("const CHARACTER "), "CHARACTER sabiti kalktı (V2Flow.selected_character)"
	)


func test_controller_delegations_are_single_calls() -> void:
	var text := FileAccess.get_file_as_string(CONTROLLER)
	for call in [
		"v2 = V2Flow.new(v2_opts)",
		"v2.build_world(refs)",
		"v2.bind(",
		"v2.update_views(",
		"v2.on_run_ended(won, stats)",
		"v2.flush()",
		"v2.on_screen(next)",
		"v2.on_pause()",
		"v2.open_characters()",
		"v2.open_achievements()",
		"v2.selected_character()",
		"v2.release()",
	]:
		assert_true(text.contains(call), call)


func test_game_data_growth_is_bounded() -> void:
	# v1.1 sonu 897 satır; v2.0 ek <= 40 (doğrulayıcılar data_v2.gd'de), gdlint tavanı 1000.
	assert_lte(_lines(GAME_DATA), 897 + 40 + 4 + 4)  # v2.0.2: +4 (937 → 941; doğrulayıcılar data_v202_*.gd'de); v2.0.3: +4 (hata kodları + portrait_video anahtarı, 945)
	assert_lt(_lines(GAME_DATA), 1000)


func test_game_sim_stays_within_the_v202_budget() -> void:
	# v2.0.2 S1: game_sim.gd tavanı 990 (rüzgar sistemi WindSystem/WindUtil'de yaşar; sim yalnız delegasyon taşır).
	assert_lte(_lines(GAME_SIM), 990, "game_sim.gd satır sayısı (tavan 990)")
