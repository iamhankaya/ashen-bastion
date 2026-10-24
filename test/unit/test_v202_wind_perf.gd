extends GutTest
## U3 perf bütçesi (sayaç tabanlı, süre değil): Tufan + Hortum + Girdap birlikte, sürekli 300 canlı düşman, 600 adım.
## Bütçe = ölçülen adım başına ortalama x 1,25 (+%25 pay: aynı koşuda sayaçlar deterministiktir ama U1/U2/D balans
## sayıları değişince oynar; pay bunun içindir, ölçüm gürültüsü için değil). Süre (ms) yalnız bilgidir.

const STEPS := 600
const ENEMIES := 300
const GRANTS := {"tufan": 1, "hortum": 5, "girdap": 5, "furtina_gozu": 5}
## Ölçüm (U3, tohum 161): hash_queries 7.03, cells_scanned 631.2, collision_tests 4.13, enemy_updates 296.8,
## hash_inserts 301.5, proj_updates 0.25. Karşılaştırma: rüzgârsız Zyfen aynı sahnede hash_queries 1.1, cells_scanned 81.
const BUDGET := {
	&"hash_queries": 9.0,
	&"cells_scanned": 790.0,
	&"collision_tests": 6.0,
	&"enemy_updates": 372.0,
	&"hash_inserts": 378.0,
	&"proj_updates": 1.0,
}


func test_tufan_hortum_girdap_with_300_enemies_stays_under_counter_budget() -> void:
	var r := WindKit.stress(161, GRANTS, STEPS, ENEMIES)
	var sim: GameSim = r["sim"]
	var avg: Dictionary = r["avg"]
	gut.p(
		"rüzgar stresi %d adım: %.1f ms (yalnız bilgi). iş/adım: %s" % [STEPS, float(r["ms"]), avg]
	)
	assert_eq(sim.step_count, STEPS, "sim erken bitmedi")
	assert_gte(int(r["zone_steps"]), int(STEPS * 0.9), "senaryo gerçekten bölge içeriyor")
	assert_gte(int(r["zone_max"]), 4, "Tufan (3) + Hortum (en az 1) birlikte")
	assert_eq(r["violations"], PackedStringArray(), "bölge/düşman değişmezleri")
	assert_eq(sim.check_invariants(), PackedStringArray())
	for k in BUDGET:
		assert_gt(float(avg[k]), 0.0, "%s sayacı çalışmıyor (hep 0)" % k)
		assert_lte(float(avg[k]), float(BUDGET[k]), "%s adım başına tavanı aşıyor" % k)


func test_work_counters_are_deterministic_for_the_wind_stress() -> void:
	var a := WindKit.stress(162, GRANTS, 240, ENEMIES)
	var b := WindKit.stress(162, GRANTS, 240, ENEMIES)
	for k in GameSim.WORK_KEYS:
		assert_eq(a["sim"].work[k], b["sim"].work[k], "%s: aynı tohum aynı sayaç" % k)
	assert_eq(a["sim"].state_hash(), b["sim"].state_hash())


func test_no_zone_is_ever_lost_in_the_wind_stress() -> void:
	var r := WindKit.stress(163, GRANTS, 900, ENEMIES)
	assert_eq(r["sim"].fx.zone_dropped, 0, "Tufan/Hortum rezervle kaybolmaz")
