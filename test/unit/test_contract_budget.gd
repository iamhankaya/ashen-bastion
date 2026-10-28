extends GutTest
## Sözleşme (S3): game_controller.gd satır bütçesi. v2 mantığı V2Flow + 3 dilim sınıfında yaşar; controller yalnız
## tek satırlık delegasyon taşır. Satır tavanları artık araçta: tools/ci/check_line_budget.py (tek tip 800) +
## tools/ci/line_budget_exceptions.txt (azalan geçiş kaydı); bu testler aynı kaynaktan okur.

const CONTROLLER := "res://scripts/ctrl/game_controller.gd"
const BUDGET_EXCEPTIONS := "res://tools/ci/line_budget_exceptions.txt"
const BUDGET_DEFAULT := 800  # tools/ci/check_line_budget.py --max ile aynı; tavanın tek kaynağı araç + istisna dosyası
const GAME_DATA := "res://scripts/sim/game_data.gd"
const GAME_SIM := "res://scripts/sim/game_sim.gd"


func _lines(path: String) -> int:
	return FileAccess.get_file_as_string(path).split("\n").size() - 1


func test_controller_stays_under_the_ceiling() -> void:
	assert_lte(_lines(CONTROLLER), _ceiling(CONTROLLER), "game_controller.gd satır sayısı")


func test_controller_after_contract_phase_within_s3_budget() -> void:
	assert_lte(_lines(CONTROLLER), _ceiling(CONTROLLER), "sözleşme fazı bütçesi")


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
	assert_lte(_lines(GAME_DATA), _ceiling(GAME_DATA))
	assert_lt(_lines(GAME_DATA), 1000)


func test_game_sim_stays_within_the_v202_budget() -> void:
	assert_lte(_lines(GAME_SIM), _ceiling(GAME_SIM), "game_sim.gd satır sayısı")


func _ceiling(path: String) -> int:
	var rel := path.trim_prefix("res://")
	for raw in FileAccess.get_file_as_string(BUDGET_EXCEPTIONS).split("\n"):
		var parts := raw.split("#")[0].split("|")
		if parts.size() == 2 and parts[0].strip_edges() == rel:
			return int(parts[1].strip_edges())
	return BUDGET_DEFAULT
