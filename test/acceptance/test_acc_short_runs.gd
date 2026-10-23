extends GutTest
## Kabul: kısa koşular. 120 sn x 3 bot politikası, start_time sıçramalı 30 sn koşular ve baştan sona tam oyun akışı
## (timer modu demo). Her 60 adımda check_invariants() boş olmalı.

const STEPS_120S := 7200
const SEED := 151


func _xp_total(sim: GameSim) -> int:
	return XpCurve.cumulative(sim.level) + sim.xp


func _collected(sim: GameSim) -> int:
	var t := 0
	for e in SimKit.events(sim, SimEvents.GEM_COLLECTED):
		t += int(e["value"])
	return t


func _check_consistency(sim: GameSim, label: String) -> void:
	assert_eq(
		sim.kills, SimKit.count_events(sim, SimEvents.KILL), "%s: kills = kill olayları" % label
	)
	assert_eq(_xp_total(sim), _collected(sim), "%s: toplam XP = toplanan taşlar" % label)
	assert_eq(
		sim.level,
		1 + SimKit.count_events(sim, SimEvents.LEVEL_UP),
		"%s: level = 1 + level_up olayları" % label
	)
	assert_between(sim.xp, 0, maxi(sim.xp_to_next, 1), "%s: xp aralığı" % label)
	assert_true(sim.time >= 0.0 and is_finite(sim.time))
	assert_almost_eq(
		sim.time, float(sim.step_count) * GameSim.STEP, 0.01, "%s: süre = adım x STEP" % label
	)


func test_120_seconds_with_each_policy_keeps_invariants() -> void:
	for policy in Bots.POLICIES:
		var sim := SimKit.make(SEED, {"data_kind": "real"})
		var rng := Bots.make_rng(SEED)
		var r := Bots.play(sim, policy, STEPS_120S, rng, 60)
		assert_eq(r["violations"], PackedStringArray(), "%s: değişmezler" % policy)
		assert_true(
			sim.state in [GameSim.State.RUNNING, GameSim.State.LEVEL_UP, GameSim.State.LOST],
			"%s: 120 sn'de WON olmaz (end_time 1200)" % policy
		)
		assert_gt(int(r["steps"]), 0)
		assert_gt(
			SimKit.count_events(sim, SimEvents.SPAWN), 40, "%s: 120 sn'de doğuşlar olmalı" % policy
		)
		_check_consistency(sim, String(policy))
		if sim.state == GameSim.State.LOST:
			assert_lte(sim.hp, 0.0)
			assert_eq(SimKit.count_events(sim, SimEvents.RUN_END), 1)
		else:
			assert_gt(sim.hp, 0.0)
			assert_eq(SimKit.count_events(sim, SimEvents.RUN_END), 0)


func test_greedy_bot_actually_plays_kills_levels_up_and_chooses() -> void:
	var sim := SimKit.make(SEED, {"data_kind": "real"})
	var rng := Bots.make_rng(SEED)
	var r := Bots.play(sim, Bots.GREEDY, STEPS_120S, rng, 60)
	assert_gte(sim.kills, 10, "taş toplayıcı bot 120 sn'de düşman öldürür")
	assert_gte(sim.level, 2, "en az bir seviye atlanır")
	assert_gte(int(r["choices_made"]), 1, "en az bir beceri seçilir")
	assert_gt(
		sim.loadout.actives().size() + sim.loadout.passives().size(), 1, "seçimler yuvaya işler"
	)
	assert_eq(SimKit.count_events(sim, SimEvents.CHOICE_MADE), int(r["choices_made"]))


func test_jump_to_late_game_and_play_30_seconds() -> void:
	for start in [300.0, 600.0, 900.0, 1140.0]:
		var sim := SimKit.make(SEED, {"data_kind": "real", "start_time": start})
		var rng := Bots.make_rng(SEED)
		var r := Bots.play(sim, Bots.KITE, 1800, rng, 60)
		assert_eq(r["violations"], PackedStringArray(), "t0=%d: değişmezler" % start)
		assert_gte(sim.time, start, "t0=%d: süre geriye gitmez" % start)
		assert_gt(
			SimKit.count_events(sim, SimEvents.SPAWN), 20, "t0=%d: 30 sn'de doğuşlar olmalı" % start
		)
		assert_lte(sim.enemies.count, EnemyPool.CAP)


func test_full_demo_run_from_start_to_result() -> void:
	# başla -> (seviye atla / beceri seç) -> sonuç: timer modu, 90 sn, ölümsüz kite botu.
	var sim := SimKit.make(SEED, {"data_kind": "real", "end_mode": "timer", "end_time": 90.0})
	SimKit.godmode(sim)
	var ended: Array = []
	sim.bus.run_ended.connect(func(w: bool, st: Dictionary) -> void: ended.append([w, st]))
	var rng := Bots.make_rng(SEED)
	var r := Bots.play(sim, Bots.GREEDY, 6000, rng, 60)
	assert_eq(sim.state, GameSim.State.WON, "süre dolunca WON")
	assert_gte(sim.time, 90.0 - 0.01)
	assert_lt(sim.time, 91.0)
	assert_eq(r["violations"], PackedStringArray())
	assert_eq(SimKit.count_events(sim, SimEvents.RUN_END), 1)
	assert_eq(ended.size(), 1)
	assert_gte(sim.level, 3, "90 sn'de birkaç seviye atlanır")
	# Her seviye atlamanın bir seçimi var (WON adımındaki seviye atlama iptal edilir; ondan önceki hepsi seçilmiş olmalı).
	var end_step := int(SimKit.last_event(sim, SimEvents.RUN_END).get("step", 1 << 30))
	var resolved := 0
	for e in SimKit.events(sim, SimEvents.LEVEL_UP):
		if int(e["step"]) < end_step:
			resolved += 1
	assert_eq(
		SimKit.count_events(sim, SimEvents.CHOICE_MADE),
		resolved,
		"her seviye atlama için bir seçim"
	)
	for c in SimKit.events(sim, SimEvents.CHOICES):
		assert_between((c["ids"] as Array).size(), 1, 3)
	_check_consistency(sim, "demo")


func test_full_run_builds_an_evolution_and_reports_it() -> void:
	if Slice.current() < 2:
		pending("evrimler slice 2 içeriği")
		return
	var sim := SimKit.make(SEED, {"data_kind": "real", "end_mode": "timer", "end_time": 60.0})
	SimKit.godmode(sim)
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"barut_kesesi", 1)
	var ended: Array = []
	sim.bus.run_ended.connect(func(w: bool, st: Dictionary) -> void: ended.append([w, st]))
	var rng := Bots.make_rng(SEED)
	Bots.play(sim, Bots.GREEDY, 5000, rng, 60)
	assert_eq(sim.state, GameSim.State.WON)
	assert_true(&"zincirleme_patlama" in sim.evolved_log, "bot evrim kartını seçer")
	assert_eq(ended.size(), 1)
	if not ended.is_empty():
		assert_true(
			&"zincirleme_patlama" in ended[0][1].get("evolutions", []), "sonuç ekranı kombo listesi"
		)
