extends GutTest
## Kabul: doğurma çizelgesi davranışı: halka konumu, geri taşıma, start_time semantiği, boss/lord zamanları, spawn kaybı.
## Boss/lord (waves satır 4-6, U2-4) slice 2'de; test/fixtures/data_valid'in çizelgesi (elit_piyade 300. sn,
## kale_lordu 1200. sn, 480. sn halka) bu kuralların içerik bağımsız kanıtıdır.

const HALF_DIAGONAL_PLUS_80 := 1395.9  # sqrt(540^2 + 1200^2) + 80 (1080x2400 referans)


func _slice2() -> bool:
	if Slice.current() < 2:
		pending("boss/lord (Uygulama-2) kapsamında")
		return false
	return true


func _fx(seed_value: int, opts: Dictionary = {}) -> GameSim:
	var o := opts.duplicate()
	o["data_kind"] = "fixture_waves"
	return SimKit.make(seed_value, o)


func test_natural_spawns_appear_on_the_ring_outside_the_camera() -> void:
	var sim := SimKit.make(101, {"data_kind": "real", "start_time": 900.0})
	SimKit.godmode(sim)
	SimKit.run(sim, 1200)
	var spawns := SimKit.events(sim, SimEvents.SPAWN)
	assert_gt(spawns.size(), 30, "yoğun doğuş bekleniyor")
	var quadrants := [0, 0, 0, 0]
	for e in spawns:
		var p: Vector2 = e["pos"]
		assert_between(
			p.length(),
			HALF_DIAGONAL_PLUS_80 - 40.0,
			HALF_DIAGONAL_PLUS_80 + 40.0,
			"doğma halkası ~1400 px"
		)
		quadrants[(0 if p.x >= 0.0 else 1) + (0 if p.y >= 0.0 else 2)] += 1
	for q in 4:
		assert_gt(quadrants[q], spawns.size() / 20, "açı düzgün dağılmalı (çeyrek %d)" % q)


func test_far_enemy_is_carried_back_in_movement_direction() -> void:
	var sim := SimKit.make(102)
	SimKit.godmode(sim)
	var id := SimKit.add_enemy(sim, &"curumus_piyade", Vector2(-3000, 0))
	assert_ne(id, -1)
	var before := sim.enemies.count
	SimKit.run(sim, 90, Vector2.RIGHT)
	assert_eq(sim.enemies.count, before, "uzaktaki düşman ölmez/çoğalmaz, taşınır")
	for eid in sim.alive_ids():
		var d := SimKit.enemy_pos(sim, eid) - sim.player_pos
		assert_lte(d.length(), 1900.0 + 120.0, "oyuncudan >1900 px uzak düşman kalmamalı")
		assert_gt(d.x, 0.0, "geri taşıma hareket yönündeki halkaya")


func test_spawn_dropped_counter_stays_zero_in_a_normal_run() -> void:
	var sim := SimKit.make(103, {"data_kind": "real"})
	SimKit.godmode(sim)
	SimKit.run(sim, 1200)
	assert_gt(SimKit.count_events(sim, SimEvents.SPAWN), 10, "doğuşlar var")
	assert_eq(sim.spawn_dropped, 0)
	assert_eq(SimKit.count_events(sim, SimEvents.SPAWN_DROPPED), 0)


func test_boss_warns_5s_before_and_spawns_on_time() -> void:
	if not _slice2():
		return
	var sim := _fx(104, {"start_time": 290.0})
	SimKit.godmode(sim)
	var warned: Array = []
	var spawned: Array = []
	sim.bus.boss_warning.connect(func(k: StringName) -> void: warned.append(k))
	sim.bus.boss_spawned.connect(func(t: StringName) -> void: spawned.append(t))
	SimKit.run(sim, 660)
	var w := SimKit.events(sim, SimEvents.BOSS_WARNING)
	var b := SimKit.events(sim, SimEvents.BOSS_SPAWN)
	assert_eq(w.size(), 1, "uyarı bir kez")
	assert_eq(b.size(), 1, "boss bir kez")
	assert_eq(warned.size(), 1)
	assert_eq(spawned, [&"elit_piyade"])
	if w.is_empty() or b.is_empty():
		return
	assert_between(int(w[0]["step"]), 298, 302, "uyarı 295. sn (başlangıçtan 5 sn sonra)")
	assert_between(int(b[0]["step"]), 598, 602, "boss 300. sn")
	assert_eq(b[0]["type"], &"elit_piyade")
	assert_between(int(b[0]["step"]) - int(w[0]["step"]), 298, 302, "uyarı olaydan 5 sn önce")


func test_boss_is_not_scaled_when_definition_says_so() -> void:
	if not _slice2():
		return
	var sim := _fx(105, {"start_time": 299.9})
	SimKit.godmode(sim)
	SimKit.run(sim, 12)
	var b := SimKit.events(sim, SimEvents.SPAWN)
	var id := -1
	for e in b:
		if e["type"] == &"elit_piyade":
			id = int(e["id"])
	assert_ne(id, -1, "300. sn'de elit_piyade doğmalı")
	var def := sim.data.get_enemy(&"elit_piyade")
	if id != -1 and def != null and not def.scales_with_time:
		assert_almost_eq(
			SimKit.enemy_hp(sim, id), def.hp, 0.5, "scales_with_time:false => çarpansız hp"
		)


func test_start_time_skips_past_boss_events() -> void:
	if not _slice2():
		return
	var sim := _fx(106, {"start_time": 301.0})
	SimKit.godmode(sim)
	SimKit.run(sim, 600)
	assert_eq(SimKit.count_events(sim, SimEvents.BOSS_WARNING), 0, "atlanan aralıkta uyarı yok")
	assert_eq(SimKit.count_events(sim, SimEvents.BOSS_SPAWN), 0, "atlanan boss tetiklenmez")


func test_start_time_equal_to_event_triggers_on_next_step() -> void:
	if not _slice2():
		return
	var sim := _fx(107, {"start_time": 300.0})
	SimKit.godmode(sim)
	SimKit.run(sim, 3)
	assert_eq(
		SimKit.count_events(sim, SimEvents.BOSS_SPAWN), 1, "at == t sonraki adımda tetiklenir"
	)
	assert_eq(SimKit.count_events(sim, SimEvents.BOSS_WARNING), 0, "uyarı (295) atlandı")


func test_debug_set_time_is_forward_only_and_skips_events() -> void:
	if not _slice2():
		return
	var sim := _fx(108, {"start_time": 100.0})
	SimKit.godmode(sim)
	sim.debug_set_time(50.0)
	assert_almost_eq(sim.time, 100.0, 0.0001, "geriye atlama yok sayılır")
	sim.debug_set_time(350.0)
	assert_almost_eq(sim.time, 350.0, 0.0001)
	SimKit.run(sim, 60)
	assert_eq(SimKit.count_events(sim, SimEvents.BOSS_SPAWN), 0, "atlanan boss (300) tetiklenmez")
	assert_eq(sim.xp, 0, "zaman atlaması XP/seviye vermez")
	assert_eq(sim.level, 1)


func test_debug_set_time_rescales_difficulty() -> void:
	var sim := SimKit.make(109, {"data_kind": "real"})
	SimKit.godmode(sim)
	sim.debug_set_time(900.0)
	SimKit.run(sim, 240)
	var def := sim.data.get_enemy(&"curumus_piyade")
	var checked := 0
	for e in SimKit.events(sim, SimEvents.SPAWN):
		if e["type"] == &"curumus_piyade":
			var hp := SimKit.enemy_hp(sim, int(e["id"]))
			if hp > 0.0 and def != null:
				checked += 1
				assert_gt(hp, def.hp * 3.0, "15. dk'da piyade hp çarpanı ~3,4")
	assert_gt(checked, 0)


func test_burst_ring_spawns_fifty_around_the_player() -> void:
	if not _slice2():
		return
	var sim := _fx(110, {"start_time": 479.0})
	SimKit.godmode(sim)
	var before := SimKit.count_events(sim, SimEvents.SPAWN)
	SimKit.run(sim, 120)
	var ring := 0
	for e in SimKit.events(sim, SimEvents.SPAWN):
		if int(e["step"]) > 55 and int(e["step"]) <= 75:
			ring += 1
	assert_gte(ring, 45, "480. sn halka dalgası ~50 piyade tek seferde")
	assert_gte(SimKit.count_events(sim, SimEvents.SPAWN), before + 50)


func test_full_pool_drops_boss_spawn_without_retry_or_queue() -> void:
	if not _slice2():
		return
	var sim := _fx(111, {"start_time": 299.9})
	SimKit.godmode(sim)
	assert_eq(sim.debug_fill(&"curumus_piyade", 400, 1000.0), 400, "havuz 400'e dolar")
	SimKit.run(sim, 12)
	assert_gte(sim.spawn_dropped, 1, "havuz doluyken boss doğuşu kaybolur")
	assert_gte(SimKit.count_events(sim, SimEvents.SPAWN_DROPPED), 1)
	assert_eq(SimKit.count_events(sim, SimEvents.BOSS_SPAWN), 0)
	assert_lte(sim.enemies.count, EnemyPool.CAP)
	var dropped := sim.spawn_dropped
	SimKit.run(sim, 60)
	assert_eq(sim.spawn_dropped, dropped, "kaybolan doğuş yeniden denenmez")
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_lord_spawns_at_end_time_with_warning_and_summons() -> void:
	if not _slice2():
		return
	var sim := _fx(112, {"start_time": 1194.0})
	SimKit.godmode(sim)
	SimKit.run(sim, 1500)
	var spawn := SimKit.events(sim, SimEvents.BOSS_SPAWN)
	var warn := SimKit.events(sim, SimEvents.BOSS_WARNING)
	assert_eq(spawn.size(), 1)
	assert_eq(warn.size(), 1)
	if spawn.is_empty():
		return
	assert_eq(spawn[0]["type"], &"kale_lordu")
	assert_between(int(spawn[0]["step"]), 358, 362, "Lord 1200. sn'de")
	var lord_step := int(spawn[0]["step"])
	var per_step := {}
	for e in SimKit.events(sim, SimEvents.SPAWN):
		if e["type"] == &"curumus_piyade" and int(e["step"]) > lord_step:
			per_step[int(e["step"])] = int(per_step.get(int(e["step"]), 0)) + 1
	var batches := 0
	var skip_until := 0
	var steps_sorted: Array = per_step.keys()
	steps_sorted.sort()
	for st in steps_sorted:
		if int(st) < skip_until:
			continue
		var n: int = (
			int(per_step.get(st, 0))
			+ int(per_step.get(int(st) + 1, 0))
			+ int(per_step.get(int(st) + 2, 0))
		)
		if n >= 12:
			batches += 1
			skip_until = int(st) + 60
	assert_gte(batches, 2, "Lord her 8 sn'de 12 piyade çağırır (en az iki toplu çağırma)")
