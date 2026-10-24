extends GutTest
## U2: Zyfen'in geniş delen kesiği sayaç tabanlı iş bütçesini aşmaz (zaman ölçülmez; sayaçlar deterministik).
## Bütçe tools/perf_budget_zyfen.json: ölçülen adım başı ortalamanın +%25'i (ölçüm gürültüsü payı değil, kod değişimi payı;
## sayaçlar deterministik olduğundan gürültü yoktur). Senaryo: 300 piyade, 240 px yarıçap, 240 adım, durağan oyuncu.
## v2.0.1 tavanı (tools/perf_budget.json) değişmez; Zyfen için ayrı dosya.

const PATH := "res://tools/perf_budget_zyfen.json"
const ENEMIES := 300
const STEPS := 240


func _run(character: StringName) -> GameSim:
	var sim := SimKit.make(
		161, {"start_time": 900.0, "log_events": false, "data_kind": "real", "character": character}
	)
	SimKit.godmode(sim)
	assert_eq(sim.debug_fill(&"curumus_piyade", ENEMIES, 240.0), ENEMIES)
	for i in STEPS:
		sim.step(Vector2.ZERO)
	return sim


func test_budget_file_has_the_work_keys() -> void:
	var budget: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_true(budget is Dictionary)
	for k in GameSim.WORK_KEYS:
		assert_true((budget as Dictionary).has(String(k)), String(k))


func test_zyfen_300_enemy_stress_stays_under_its_budget() -> void:
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var sim := _run(&"zyfen")
	for k in budget:
		var avg := float(sim.work[StringName(k)]) / float(STEPS)
		assert_lte(avg, float(budget[k]), "%s adım başı ortalama" % k)
	assert_eq(sim.check_invariants().size(), 0)


func test_zyfen_collision_work_is_close_to_gunslinger_in_the_same_stress() -> void:
	var g := _run(&"gunslinger")
	var z := _run(&"zyfen")
	var ratio := float(z.work[&"collision_tests"]) / maxf(float(g.work[&"collision_tests"]), 1.0)
	assert_lt(ratio, 2.0, "geniş kesik çarpışma işini ikiye katlamaz: %.2f" % ratio)
