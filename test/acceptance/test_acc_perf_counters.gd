extends GutTest
## Kabul (gate adım 8): deterministik iş sayacı kontrolü. Stres senaryosu: 400 düşman + 500 mermi, sabit tohum, 600 adım.
## `work` sayaçlarının adım başına ortalaması tools/perf_budget.json tavanlarının altında olmalı. Zaman (ms) yalnız bilgidir.
##
## VARSAYIM (plan dosya biçimini yazmıyor): perf_budget.json düz bir sözlüktür: { "<work anahtarı>": <adım başına tavan> }.
## Dosyayı U1-1 üretir; yoksa bu test KIRMIZI kalır (bütçe tanımsız = kontrol edilemiyor).

const BUDGET_PATH := "res://tools/perf_budget.json"
const STEPS := 600
const ENEMIES := 400
const PROJECTILES := 500
const REQUIRED_KEYS: Array[StringName] = [
	&"hash_inserts",
	&"hash_queries",
	&"cells_scanned",
	&"collision_tests",
	&"enemy_updates",
	&"proj_updates"
]


func _stress(seed_value: int) -> Dictionary:
	var sim := SimKit.make(seed_value, {"start_time": 900.0, "log_events": false})
	SimKit.godmode(sim)
	assert_eq(
		sim.debug_fill(&"curumus_piyade", ENEMIES, 600.0), ENEMIES, "400 düşman halkaya yerleşmeli"
	)
	var rng := Bots.make_rng(seed_value)
	var t0 := Time.get_ticks_usec()
	for i in STEPS:
		# Mermi sayısını ~500'de tut (ömürleri dolanların yerine yenisi).
		var missing := PROJECTILES - sim.projectiles.count
		for k in missing:
			var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(100.0, 650.0)
			var v := Vector2.from_angle(rng.randf() * TAU) * 120.0
			if sim.spawn_projectile(p, v, 1.0, {"life": 2.0}) < 0:
				break
		sim.step(Vector2.ZERO)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var avg := {}
	for k in GameSim.WORK_KEYS:
		avg[k] = float(sim.work[k]) / float(STEPS)
	return {"avg": avg, "ms": ms, "sim": sim}


func test_budget_file_exists_and_lists_every_counter() -> void:
	assert_true(FileAccess.file_exists(BUDGET_PATH), "tools/perf_budget.json yok (U1-1 yazar)")
	if not FileAccess.file_exists(BUDGET_PATH):
		return
	var budget: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUDGET_PATH))
	assert_true(budget is Dictionary, "bütçe düz sözlük olmalı")
	if not budget is Dictionary:
		return
	for k in REQUIRED_KEYS:
		assert_true(budget.has(String(k)), "bütçede '%s' tavanı olmalı" % k)
		if budget.has(String(k)):
			assert_gt(float(budget[String(k)]), 0.0, "%s tavanı pozitif" % k)


func test_stress_scene_stays_under_work_budget() -> void:
	var budget: Variant = null
	if FileAccess.file_exists(BUDGET_PATH):
		budget = JSON.parse_string(FileAccess.get_file_as_string(BUDGET_PATH))
	assert_true(budget is Dictionary, "tools/perf_budget.json okunamadı (U1-1 yazar)")
	var r := _stress(161)
	var avg: Dictionary = r["avg"]
	var sim: GameSim = r["sim"]
	gut.p("stres %d adım: %.1f ms (yalnız bilgi). iş/adım: %s" % [STEPS, float(r["ms"]), avg])
	assert_eq(sim.step_count, STEPS)
	assert_eq(sim.check_invariants(), PackedStringArray())
	for k in REQUIRED_KEYS:
		assert_gt(float(avg[k]), 0.0, "%s sayacı çalışmıyor (hep 0)" % k)
	if budget is Dictionary:
		for k in REQUIRED_KEYS:
			if budget.has(String(k)):
				assert_lte(
					float(avg[k]), float(budget[String(k)]), "%s adım başına tavanı aşıyor" % k
				)


func test_work_counters_are_deterministic_and_cumulative() -> void:
	var a := _stress(162)
	var b := _stress(162)
	var sa: GameSim = a["sim"]
	var sb: GameSim = b["sim"]
	for k in GameSim.WORK_KEYS:
		assert_eq(sa.work[k], sb.work[k], "%s: aynı tohum aynı sayaç" % k)
	assert_eq(sa.state_hash(), sb.state_hash())
	var sim := SimKit.make(163, {"start_time": 900.0, "log_events": false})
	SimKit.godmode(sim)
	sim.debug_fill(&"curumus_piyade", 100, 600.0)
	SimKit.run(sim, 30)
	var mid: Dictionary = sim.work.duplicate()
	SimKit.run(sim, 30)
	for k in GameSim.WORK_KEYS:
		assert_gte(int(sim.work[k]), int(mid[k]), "%s kümülatif (azalmaz)" % k)
