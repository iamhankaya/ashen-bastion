extends GutTest
## Kabul: oyun sonu koşulları ve sonuç ekranı verisi. Plan "Oyun sonu öncelikleri".
## Ölüm (LOST) ve timer-WON slice 1; Kale Lordu (end_mode "lord") slice 2.
##
## VARSAYIM (sözleşme anahtar adlarını yazmıyor): bus.run_ended(won, stats) sözlüğü
##   "time" (sn), "level", "kills", "evolutions" (evrim kimlikleri dizisi = sim.evolved_log) anahtarlarını taşır.
## Tasarım §5.5/UI §6.5: sonuç ekranı = süre, seviye, öldürme sayısı, kurulan kombolar.


func _doom(sim: GameSim, n: int = 6) -> void:
	for i in n:
		assert_ne(SimKit.add_enemy(sim, &"sovalye_hayaleti", Vector2(20 + i * 4, 10 - i * 3)), -1)


func _record_end(sim: GameSim) -> Array:
	var got: Array = []
	sim.bus.run_ended.connect(
		func(w: bool, st: Dictionary) -> void: got.append([w, st.duplicate()])
	)
	return got


func test_death_ends_the_run_as_lost_and_freezes_everything() -> void:
	var sim := SimKit.make(121)
	var ended := _record_end(sim)
	_doom(sim)
	var steps := SimKit.run(sim, 120)
	assert_eq(sim.state, GameSim.State.LOST, "hp <= 0 => LOST")
	assert_lte(sim.hp, 0.0)
	assert_lt(steps, 120, "ölünce koşu durmalı")
	assert_between(steps, 30, 45, "6 temas: ilk tick 72, ikinci tick (~0,6 sn) ölümcül")
	assert_eq(SimKit.count_events(sim, SimEvents.RUN_END), 1)
	assert_eq(SimKit.last_event(sim, SimEvents.RUN_END).get("won", true), false)
	assert_eq(ended.size(), 1, "run_ended bir kez")
	if not ended.is_empty():
		assert_eq(ended[0][0], false)
	var h := sim.state_hash()
	var n := sim.step_count
	for i in 40:
		sim.step(Vector2.RIGHT)
	assert_eq(sim.step_count, n, "LOST sonrası step no-op")
	assert_eq(sim.state_hash(), h)
	assert_false(sim.choose(0), "LOST sonrası choose false")
	assert_eq(SimKit.count_events(sim, SimEvents.RUN_END), 1, "run_end tekrarlanmaz")


func test_result_stats_carry_time_level_kills_and_combos() -> void:
	var sim := SimKit.make(122)
	var ended := _record_end(sim)
	for i in 3:
		SimKit.add_enemy(sim, &"curumus_piyade", Vector2(250 + i * 30, (i - 1) * 40))
	SimKit.run_until(sim, func() -> bool: return sim.kills >= 3, 300)
	assert_gte(sim.kills, 3, "önce birkaç düşman öldür")
	sim.debug_grant(&"seken_mermi", 1)
	_doom(sim)
	SimKit.run(sim, 120)
	assert_eq(sim.state, GameSim.State.LOST)
	assert_eq(ended.size(), 1)
	if ended.is_empty():
		return
	var st: Dictionary = ended[0][1]
	for k in ["time", "level", "kills", "evolutions"]:
		assert_true(st.has(k), "sonuç verisinde '%s' olmalı" % k)
	assert_almost_eq(float(st.get("time", -1.0)), sim.time, 0.0001, "süre")
	assert_eq(int(st.get("level", -1)), sim.level, "seviye")
	assert_eq(int(st.get("kills", -1)), sim.kills, "öldürme")
	assert_gte(int(st.get("kills", -1)), 3)
	assert_eq(st.get("evolutions", null), sim.evolved_log, "kurulan kombolar (evrim listesi)")


func test_result_stats_list_the_evolutions_built() -> void:
	var sim := SimKit.make(123, {"data_kind": "fixture"})
	var ended := _record_end(sim)
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"barut_kesesi", 1)
	assert_true(SimKit.level_up_with(sim, 12))
	assert_true(sim.choose(SimKit.card_index(sim, &"zincirleme_patlama")))
	for i in 6:
		SimKit.add_enemy(sim, &"curumus_piyade", Vector2(20 + i * 4, 10 - i * 3))
	sim.max_hp = 1.0
	sim.hp = 1.0
	SimKit.run(sim, 60)
	assert_eq(sim.state, GameSim.State.LOST)
	assert_eq(ended.size(), 1)
	if not ended.is_empty():
		assert_eq(ended[0][1].get("evolutions", []), [&"zincirleme_patlama"] as Array[StringName])


func test_timer_mode_wins_at_end_time() -> void:
	var sim := SimKit.make(124, {"end_mode": "timer", "end_time": 3.0})
	SimKit.godmode(sim)
	var ended := _record_end(sim)
	var steps := SimKit.run(sim, 400)
	assert_eq(sim.state, GameSim.State.WON, "time >= end_time => WON")
	assert_between(steps, 180, 182, "3,0 sn = 180 adım")
	assert_gte(sim.time, 3.0 - 0.0001)
	assert_eq(SimKit.last_event(sim, SimEvents.RUN_END).get("won", false), true)
	assert_eq(ended.size(), 1)
	if not ended.is_empty():
		assert_eq(ended[0][0], true)
		assert_almost_eq(float(ended[0][1].get("time", -1.0)), sim.time, 0.0001)
	var n := sim.step_count
	sim.step(Vector2.RIGHT)
	assert_eq(sim.step_count, n, "WON sonrası step no-op")
	assert_false(sim.choose(0))


func test_timer_mode_death_on_the_same_step_is_lost() -> void:
	var sim := SimKit.make(125, {"end_mode": "timer", "end_time": 5.0, "start_time": 4.99})
	_doom(sim)
	sim.hp = 1.0
	SimKit.run(sim, 5)
	assert_eq(sim.state, GameSim.State.LOST, "timer: süre dolması ile hp<=0 aynı adımda => LOST")
	assert_eq(SimKit.last_event(sim, SimEvents.RUN_END).get("won", true), false)


func test_death_cancels_a_pending_level_up() -> void:
	var sim := SimKit.make(126)
	_doom(sim)
	sim.hp = 1.0
	sim.debug_add_xp(1000)
	SimKit.run(sim, 5)
	assert_eq(sim.state, GameSim.State.LOST, "ölüm seviye atlamayı iptal eder")
	assert_eq(sim.pending_levels, 0)
	assert_eq(sim.pending_choices().size(), 0)
	assert_false(sim.choose(0))


func test_win_cancels_a_pending_level_up() -> void:
	var sim := SimKit.make(127, {"end_mode": "timer", "end_time": 1.0, "start_time": 0.99})
	SimKit.godmode(sim)
	sim.debug_add_xp(1000)
	SimKit.run(sim, 5)
	assert_eq(sim.state, GameSim.State.WON)
	assert_eq(sim.pending_levels, 0)
	assert_eq(sim.pending_choices().size(), 0)
	assert_false(sim.choose(0))


func test_default_mode_does_not_end_the_run_by_time_alone() -> void:
	var sim := SimKit.make(128, {"start_time": 1190.0})
	SimKit.godmode(sim)
	SimKit.run(sim, 1500)  # 1215 sn'ye geçilir
	assert_gt(sim.time, 1200.0, "20. dk geçildi")
	assert_ne(sim.state, GameSim.State.WON, "lord modunda süre dolması kazandırmaz (Lord ölmeli)")


func test_killing_the_lord_wins_in_lord_mode() -> void:
	if Slice.current() < 2:
		pending("Kale Lordu slice 2 içeriği")
		return
	var sim := SimKit.make(129, {"data_kind": "real", "start_time": 1199.9})
	SimKit.godmode(sim)
	var ended := _record_end(sim)
	SimKit.run_until(
		sim, func() -> bool: return SimKit.count_events(sim, SimEvents.BOSS_SPAWN) > 0, 30
	)
	var lord := -1
	for e in SimKit.events(sim, SimEvents.SPAWN):
		if e["type"] == &"kale_lordu":
			lord = int(e["id"])
	assert_ne(lord, -1, "20. dk'da Kale Lordu doğar")
	if lord == -1:
		return
	assert_eq(sim.state, GameSim.State.RUNNING, "Lord yaşarken oyun sürer")
	sim.enemies.hp[EnemyPool.index_of(lord)] = 1.0
	sim.enemies.pos[EnemyPool.index_of(lord)] = Vector2(60, 0)
	SimKit.run(sim, 300)
	assert_eq(sim.state, GameSim.State.WON, "Lord ölümü => WON")
	assert_eq(ended.size(), 1)
	if not ended.is_empty():
		assert_eq(ended[0][0], true)


func test_lord_death_and_player_death_on_the_same_step_is_a_win() -> void:
	if Slice.current() < 2:
		pending("Kale Lordu slice 2 içeriği")
		return
	var sim := SimKit.make(130, {"data_kind": "real", "start_time": 1199.9})
	SimKit.godmode(sim)
	SimKit.run_until(
		sim, func() -> bool: return SimKit.count_events(sim, SimEvents.BOSS_SPAWN) > 0, 30
	)
	var lord := -1
	for e in SimKit.events(sim, SimEvents.SPAWN):
		if e["type"] == &"kale_lordu":
			lord = int(e["id"])
	assert_ne(lord, -1)
	if lord == -1:
		return
	# Lord'u oyuncunun üstüne al, canını 1'e indir; oyuncunun da canı 1: aynı adımda ikisi de ölür.
	sim.enemies.pos[EnemyPool.index_of(lord)] = Vector2(40, 0)
	sim.enemies.hp[EnemyPool.index_of(lord)] = 1.0
	sim.max_hp = 100.0
	sim.hp = 1.0
	SimKit.run(sim, 6)
	if sim.state == GameSim.State.LOST:
		var kills := SimKit.events(sim, SimEvents.KILL)
		var lord_died_same_step := false
		for k in kills:
			if k["type"] == &"kale_lordu" and int(k["step"]) == sim.step_count:
				lord_died_same_step = true
		if not lord_died_same_step:
			pending(
				"aynı adım koşulu oluşmadı (Lord oyuncudan sonra öldü); öncelik kuralı sınanamadı"
			)
			return
	assert_eq(sim.state, GameSim.State.WON, "Lord ölümü hp<=0'dan önce işlenir => WON")
