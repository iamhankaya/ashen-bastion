extends GutTest
## Doğrulama (T20261023-64): kalabalıkta performans, anti-hedef "kalabalıkta takılan oyun". Gate'te duvar saati iddiası YOK:
## deterministik iş sayaçları (GameSim.work) tools/perf_budget.json tavanlarının altında kalmalı; ms/adım yalnız bilgi
## olarak yazdırılır (rapora girer). Senaryolar dev stres sahnesinden farklı: GERÇEK geç oyun yükü — tam donanım (6 aktif +
## 6 pasif + evrimler), karışık düşman türleri, elit ve Lord, 376 eşzamanlı düşman (doğuş yöneticisinin üst sınırı).

const BUDGET_PATH := "res://tools/perf_budget.json"
const STEPS := 600
const CROWD := 376  # EnemyPool.CAP - SpawnDirector.BOSS_RESERVE
const FULL_BUILD: Array = [
	[&"seken_mermi", 5],
	[&"barut_kesesi", 5],
	[&"son_mermi_patlar", 5],
	[&"hizli_doldurma", 5],
	[&"doldurma_sacilmasi", 5],
	[&"fazladan_mermi", 5],
	[&"yelpaze_atis", 5],
	[&"keskin_nisan", 5],
	[&"cift_tabanca", 5],
	[&"agir_kursun", 5],
	[&"hizli_parmak", 5],
	[&"zincirleme_patlama", 1],
	[&"kiyamet_mermisi", 1],
	[&"mermi_firtinasi", 1],
]
const KINDS: Array[StringName] = [
	&"curumus_piyade", &"curumus_piyade", &"les_kargasi", &"sovalye_hayaleti"
]


func _budget() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BUDGET_PATH))


## CROWD düşmanı sürekli koruyarak STEPS adım oynar. Döner: {sim, min_before, ms_avg, ms_max, max_proj}.
func _crowd_run(seed_value: int, build: Array, with_bosses: bool) -> Dictionary:
	var sim := SimKit.make(
		seed_value, {"data_kind": "real", "start_time": 1100.0, "log_events": false}
	)
	for g in build:
		sim.debug_grant(g[0], g[1])
	if with_bosses:
		for t in [&"elit_piyade", &"elit_sovalye", &"elit_karga", &"kale_lordu"]:
			SimKit.add_enemy(sim, t, sim.player_pos + Vector2(700, 0))
	var rng := Bots.make_rng(seed_value)
	var min_before := 1 << 20
	var max_proj := 0
	var total_ms := 0.0
	var max_ms := 0.0
	var done := 0
	var k := 0
	while done < STEPS:
		SimKit.godmode(sim)
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			continue
		var guard := 0
		while sim.enemies.count < CROWD and guard < 400:
			var ang := rng.randf() * TAU
			sim.spawn_enemy(
				KINDS[k % KINDS.size()],
				sim.player_pos + Vector2.from_angle(ang) * (500.0 + rng.randf() * 700.0)
			)
			k += 1
			guard += 1
		min_before = mini(min_before, sim.enemies.count)
		var t0 := Time.get_ticks_usec()
		sim.step(Bots.move(&"kite", sim))
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		total_ms += ms
		max_ms = maxf(max_ms, ms)
		max_proj = maxi(max_proj, sim.projectiles.count)
		done += 1
		if done % 60 == 0:
			assert_eq(sim.check_invariants(), PackedStringArray(), "adım %d değişmezler" % done)
	return {
		"sim": sim,
		"min_before": min_before,
		"ms_avg": total_ms / STEPS,
		"ms_max": max_ms,
		"max_proj": max_proj,
	}


func _assert_under_budget(sim: GameSim, steps: int, label: String) -> void:
	var b := _budget()
	for key in GameSim.WORK_KEYS:
		var avg := float(sim.work[key]) / float(steps)
		if b.has(String(key)):
			assert_lte(avg, float(b[String(key)]), "%s: %s adım başına %.1f" % [label, key, avg])


func test_full_build_late_game_crowd_of_376_stays_under_work_budget() -> void:
	var r := _crowd_run(701, FULL_BUILD, false)
	var sim: GameSim = r["sim"]
	assert_gte(r["min_before"], CROWD - 1, "her adımda 300+ (376) düşman vardı")
	assert_gt(sim.kills, 200, "tam donanım kalabalığı gerçekten eritir")
	_assert_under_budget(sim, STEPS, "tam donanım")
	(
		gut
		. p(
			(
				"BİLGİ tam-donanım-376: %.2f ms/adım ort, %.1f ms en kötü, en çok %d mermi, kills=%d, work=%s"
				% [r["ms_avg"], r["ms_max"], r["max_proj"], sim.kills, str(sim.work)]
			)
		)
	)


func test_unarmed_crowd_of_376_with_elites_and_lord_stays_under_work_budget() -> void:
	# En kötü yük: kalabalık ölmez (başlangıç silahı), elit/Lord büyük yarıçap yolunu (_big_ids) çalıştırır.
	var r := _crowd_run(702, [], true)
	var sim: GameSim = r["sim"]
	assert_gte(r["min_before"], 300, "kalabalık korunur")
	_assert_under_budget(sim, STEPS, "elit+Lord kalabalığı")
	gut.p(
		(
			"BİLGİ başlangıç-donanım+elit+Lord-376: %.2f ms/adım ort, %.1f ms en kötü, work=%s"
			% [r["ms_avg"], r["ms_max"], str(sim.work)]
		)
	)


func test_hard_caps_hold_with_every_pool_full_at_once() -> void:
	var sim := SimKit.make(703, {"data_kind": "real", "start_time": 1100.0, "log_events": false})
	for g in FULL_BUILD:
		sim.debug_grant(g[0], g[1])
	SimKit.godmode(sim)
	assert_eq(sim.debug_fill(&"curumus_piyade", EnemyPool.CAP, 900.0), EnemyPool.CAP)
	assert_eq(sim.debug_spawn(&"curumus_piyade", Vector2(10, 10)), -1, "dolu havuz reddeder")
	assert_gt(sim.spawn_dropped, 0)
	var rng := Bots.make_rng(703)
	for i in 120:
		for k in 40:
			var d := Vector2.from_angle(rng.randf() * TAU)
			sim.spawn_projectile(sim.player_pos + d * 60.0, d * 300.0, 0.5, {"life": 3.0})
		for k in 10:
			sim.gems.drop(sim.player_pos + Vector2.from_angle(rng.randf() * TAU) * 800.0, 1)
		SimKit.godmode(sim)
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
		sim.step(Vector2.ZERO)
		assert_lte(sim.enemies.count, EnemyPool.CAP)
		assert_lte(sim.projectiles.count, ProjectilePool.CAP)
		assert_lte(sim.gems.count, GemPool.CAP)
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_work_counters_are_deterministic_for_the_crowd_scenario() -> void:
	var a := _crowd_run(704, FULL_BUILD, false)
	var b := _crowd_run(704, FULL_BUILD, false)
	for key in GameSim.WORK_KEYS:
		assert_eq(a["sim"].work[key], b["sim"].work[key], "sayaç %s tekrarlanabilir" % key)
	assert_eq(a["sim"].state_hash(), b["sim"].state_hash())
