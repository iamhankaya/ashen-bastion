extends GutTest
## Kabul (v2.0.2 K, W/Z): Zyfen rüzgar setinin sayaç tabanlı iş bütçesi (zaman ölçülmez). Senaryo en kötü durum: 300 piyade
## sürekli tamamlanır, bölgeler/kesikler/dalgalar birlikte çalışır. Tavan test/fixtures/perf_budget_wind_v202.json
## (ölçülen x 1,25, ölçüm koşulları dosyada). Gunslinger için v2.0.1 tavanı (tools/perf_budget.json) bu dosyada DEĞİŞMEZ ve
## Gunslinger'ın iş sayıları Zyfen sistemi yüzünden artmaz (p2).

const BUDGET := "res://test/fixtures/perf_budget_wind_v202.json"
const STEPS := 480
const ENEMIES := 300
const KIT := {
	"hava_bicaklari": 3,
	"girdap": 3,
	"hortum": 3,
	"hava_cebi": 3,
	"nefes_dalgasi": 3,
	"delen_ruzgar": 2,
	"bolunen_kesik": 3,
	"furtina_gozu": 2,
}


func _run(character: StringName, kit: Dictionary) -> Dictionary:
	var sim := SimKit.make(
		161, {"start_time": 900.0, "log_events": false, "data_kind": "real", "character": character}
	)
	for k in kit:
		sim.debug_grant(StringName(k), int(kit[k]))
	SimKit.godmode(sim)  # beceriler verildikten SONRA
	sim.xp_to_next = 1000000000
	var peak := 0
	for _i in STEPS:
		var need := ENEMIES - sim.enemies.count
		if need > 0:
			sim.debug_fill(&"curumus_piyade", need, 450.0)
		sim.step(Vector2.ZERO)
		peak = maxi(peak, sim.zones.count)
	var avg := {}
	for k in GameSim.WORK_KEYS:
		avg[String(k)] = float(sim.work[k]) / float(STEPS)
	return {"sim": sim, "avg": avg, "peak": peak}


func test_w1_budget_file_covers_every_work_key() -> void:
	if V202Slice.require(self, "W"):
		return
	var b: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUDGET))
	assert_true(b is Dictionary)
	for k in GameSim.WORK_KEYS:
		assert_true((b as Dictionary).has(String(k)), String(k))


func test_w2_zyfen_full_wind_kit_300_enemy_stress_stays_under_budget() -> void:
	if V202Slice.require(self, "W"):
		return
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGET))
	var r := _run(&"zyfen", KIT)
	var sim: GameSim = r["sim"]
	for k in GameSim.WORK_KEYS:
		assert_lte(
			float(r["avg"][String(k)]), float(budget[String(k)]), "%s adım başı ortalama" % k
		)
	assert_eq(sim.state, GameSim.State.RUNNING, "koşu sürdü")
	assert_gt(sim.kills, 50, "kontrol: kalabalık gerçekten eritildi")
	assert_gt(int(r["peak"]), 0, "kontrol: bölgeler doğdu")
	assert_lte(int(r["peak"]), ZonePool.CAP)
	assert_eq(Array(sim.check_invariants()), [])


func test_z1_work_counters_are_deterministic() -> void:
	if V202Slice.require(self, "Z"):
		return
	var a := _run(&"zyfen", KIT)
	var b := _run(&"zyfen", KIT)
	for k in GameSim.WORK_KEYS:
		assert_eq(a["avg"][String(k)], b["avg"][String(k)], "%s iki koşuda aynı" % k)


func test_z2_gunslinger_work_is_not_increased_by_the_wind_system() -> void:
	if V202Slice.require(self, "Z"):
		return
	var g := _run(&"gunslinger", {})
	var legacy: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://tools/perf_budget.json")
	)
	assert_true(legacy is Dictionary)
	for k in [
		"hash_inserts",
		"hash_queries",
		"cells_scanned",
		"collision_tests",
		"enemy_updates",
		"proj_updates"
	]:
		if (legacy as Dictionary).has(k):
			assert_lte(float(g["avg"][k]), float(legacy[k]), "Gunslinger %s v2.0.1 tavanında" % k)
	assert_eq(g["peak"], 0, "Gunslinger'da bölge yok")
