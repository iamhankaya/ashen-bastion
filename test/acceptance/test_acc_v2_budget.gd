extends GutTest
## Kabul (v2.0 bütçe/performans): iş sayaçları v1.1 tavanlarını aşmaz (bildirim/vitrin/tracker sayaçlara girmez), kayıt yazma sıklığı,
## controller satır tavanı, perf_budget.json değişmezliği. Zaman ölçülmez (yalnız deterministik sayaç).

const BUDGET_PATH := "res://tools/perf_budget.json"
const CEILINGS := {
	"hash_inserts": 500,
	"hash_queries": 640,
	"cells_scanned": 2650,
	"collision_tests": 470,
	"enemy_updates": 500,
	"proj_updates": 630,
	"explosions": 1,
}
const ENEMIES := 400
const STEPS := 240
const BUDGET_EXCEPTIONS := "res://tools/ci/line_budget_exceptions.txt"
const BUDGET_DEFAULT := 800  # tools/ci/check_line_budget.py --max ile aynı; tavanın tek kaynağı araç + istisna dosyası


func after_each() -> void:
	AchKit.cleanup()


func _stress(seed_value: int, tracker: AchievementTracker) -> GameSim:
	var sim := SimKit.make(seed_value, {"start_time": 900.0, "log_events": false})
	SimKit.godmode(sim)
	assert_eq(sim.debug_fill(&"curumus_piyade", ENEMIES, 600.0), ENEMIES)
	if tracker != null:
		tracker.attach(sim.bus)
	for i in STEPS:
		sim.step(Vector2.ZERO)
		if tracker != null:
			tracker.poll(sim)
	return sim


func test_budget_file_is_unchanged_by_v2() -> void:
	var budget: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUDGET_PATH))
	assert_true(budget is Dictionary)
	if budget is Dictionary:
		assert_eq(budget.size(), CEILINGS.size(), "yeni sayaç anahtarı eklenmez")
		for k in CEILINGS:
			assert_eq(int(budget.get(k, -1)), CEILINGS[k], "%s tavanı v1.1 değeri" % k)


func test_work_counters_unchanged_by_v2() -> void:
	assert_eq(GameSim.WORK_KEYS.size(), CEILINGS.size(), "WORK_KEYS büyümez")
	for k in CEILINGS:
		assert_true(GameSim.WORK_KEYS.has(StringName(k)), k)


func test_stress_stays_under_v11_ceilings_without_tracker() -> void:
	var sim := _stress(161, null)
	for k in CEILINGS:
		var avg := float(sim.work[StringName(k)]) / float(STEPS)
		assert_lte(avg, float(CEILINGS[k]), "%s adım başına tavan" % k)


func test_tracker_attached_does_not_change_work_counters() -> void:
	if V2Slice.require(self, "B"):
		return
	var st := AchKit.store()
	var tr := AchievementTracker.new(AchKit.legacy_data(), st, &"gunslinger", AchKit.clock())
	var with_t := _stress(162, tr)
	var without := _stress(162, null)
	for k in GameSim.WORK_KEYS:
		assert_eq(with_t.work[k], without.work[k], "%s: tracker sayaca girmez" % k)
	assert_eq(with_t.state_hash(), without.state_hash())
	tr.detach()


func test_game_controller_line_budget() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ctrl/game_controller.gd")
	var lines := src.count("\n")
	assert_lte(
		lines, _ceiling("res://scripts/ctrl/game_controller.gd"), "game_controller.gd satır tavanı"
	)


func test_save_file_is_small_even_with_everything_unlocked() -> void:
	if V2Slice.require(self, "B"):
		return
	var p := AchKit.tmp_path("size")
	var st := AchievementStore.new(p)
	for r in ExpectedTablesV2.ACHIEVEMENTS:
		st.unlock(StringName(r[0]), 1700000000)
	assert_true(st.save())
	assert_lt(FileAccess.get_file_as_bytes(p).size(), 4096)


func test_v2_data_loading_adds_no_scene_cost_to_sim_construction() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet"})
	assert_eq(sim.state, GameSim.State.RUNNING)
	assert_eq(sim.check_invariants(), PackedStringArray())


func _ceiling(path: String) -> int:
	var rel := path.trim_prefix("res://")
	for raw in FileAccess.get_file_as_string(BUDGET_EXCEPTIONS).split("\n"):
		var parts := raw.split("#")[0].split("|")
		if parts.size() == 2 and parts[0].strip_edges() == rel:
			return int(parts[1].strip_edges())
	return BUDGET_DEFAULT
