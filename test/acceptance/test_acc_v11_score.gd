extends GutTest
## Kabul (v1.1 D3): deterministik skor ve SERİ - puan tablosu, çarpan basamakları, pencere, hasarla bozulma,
## evrim/hayatta kalma/Lord, run_ended dökümü, monotonluk, sessiz kaldırma, determinizm (S1-S12).
## Dilim D3 bitmeden pending. Sayılar ExpectedTablesV11'den.

const SLICE := "D3"
const PIYADE := &"curumus_piyade"
const KILL_ALL := 1.0e9


func _sim(seed_value: int = 1, extra: Dictionary = {}) -> GameSim:
	var o := {"data_kind": "quiet"}
	o.merge(extra, true)
	var sim := SimKit.make(seed_value, o)
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	return sim


## Oyuncudan uzakta bir düşman doğurup mermiyle (doğrudan hasar) öldürür; bu öldürmenin `kill` kaynaklı SCORE olayının
## kazancını döndürür (Lord'da ek `lord` bonus olayı sayılmaz; olay yoksa 0, doğmadıysa -1).
func _kill(sim: GameSim, type_id: StringName = PIYADE, slot: int = 0) -> int:
	var n_before := SimKit.count_events(sim, SimEvents.SCORE)
	var id := SimKit.add_enemy(
		sim, type_id, Vector2(2500.0 + 40.0 * (slot % 50), 40.0 * (slot / 50))
	)
	if id < 0:
		return -1
	sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
	sim.damage_enemy(id, KILL_ALL, &"bullet")
	var ev := SimKit.events(sim, SimEvents.SCORE)
	for k in range(n_before, ev.size()):
		if ev[k]["source"] == &"kill":
			return int(ev[k]["gain"])
	return 0


func _expected_mult(streak_count: int) -> int:
	var m := 1
	for t in ExpectedTablesV11.TIERS:
		if streak_count >= t.x:
			m = t.y
	return m


func _capture_end(sim: GameSim) -> Array:
	var got: Array = []
	sim.bus.run_ended.connect(func(won: bool, st: Dictionary) -> void: got.append([won, st]))
	return got


func test_s1_first_kill_of_each_of_the_seven_types_scores_the_table_value() -> void:
	if V11Slice.require(self, SLICE):
		return
	for type_id in ExpectedTablesV11.KILL_POINTS:
		var sim := _sim(1)
		var gain := _kill(sim, type_id)
		var want: int = ExpectedTablesV11.KILL_POINTS[type_id]
		assert_eq(gain, want, "%s: SCORE olayı kazancı" % type_id)
		assert_eq(sim.score.kills_part, want, "%s: kills bileşeni" % type_id)
		assert_eq(sim.score.streak_part, 0, "%s: ilk öldürme çarpansız" % type_id)
		assert_eq(sim.score.streak_count, 1)
		var ev := SimKit.events(sim, SimEvents.SCORE)
		assert_gte(ev.size(), 1, "%s: SCORE olayı" % type_id)
		if not ev.is_empty():
			assert_eq(ev[0].get("source"), &"kill", "%s: ilk olay öldürme" % type_id)
			assert_eq(ev[0].get("mult"), 1)


func test_s2_streak_multipliers_apply_from_the_10th_25th_50th_and_100th_kill() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(2)
	var bad := PackedStringArray()
	var base_sum := 0
	var gain_sum := 0
	for n in range(1, 121):
		var gain := _kill(sim, PIYADE, n)
		var want := 10 * _expected_mult(n)
		base_sum += 10
		gain_sum += gain
		if gain != want:
			bad.append("%d. öldürme: %d (beklenen %d)" % [n, gain, want])
	assert_eq(bad.size(), 0, "çarpan basamakları: %s" % str(bad.slice(0, 5)))
	assert_eq(sim.score.kills_part, base_sum, "kills = taban toplam")
	assert_eq(sim.score.streak_part, gain_sum - base_sum, "streak = taban x (çarpan-1) toplamı")
	assert_eq(sim.score.mult, 5)
	assert_eq(sim.score.best_mult, 5)
	assert_eq(_kill(sim, PIYADE, 121), 50, "9. öldürme x1, 10.: x2 sınırları yukarıda; 121.: x5")


func test_s2_ninth_kill_is_still_x1_and_tenth_is_x2() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(3)
	var gains: Array[int] = []
	for n in 11:
		gains.append(_kill(sim, PIYADE, n))
	assert_eq(gains, [10, 10, 10, 10, 10, 10, 10, 10, 10, 20, 20] as Array[int])


func test_s3_streak_survives_180_steps_gap_and_resets_at_181() -> void:
	if V11Slice.require(self, SLICE):
		return
	var a := _sim(4)
	for n in 10:
		_kill(a, PIYADE, n)
	assert_eq(a.score.mult, 2)
	var last := a.score.last_kill_step
	SimKit.run(a, 180)
	assert_eq(a.score.mult, 2, "180 adım ara: seri sürer")
	assert_eq(a.step_count - last, 180)
	assert_eq(_kill(a, PIYADE, 10), 20, "11. öldürme hâlâ x2")
	var b := _sim(4)
	var resets: Array = []
	b.bus.streak_changed.connect(func(m: int, left: float) -> void: resets.append([m, left]))
	for n in 10:
		_kill(b, PIYADE, n)
	resets.clear()
	SimKit.run(b, 181)
	assert_eq(b.score.mult, 1, "181 adım: çarpan 1")
	assert_eq(b.score.streak_count, 0)
	assert_true(resets.has([1, 0.0]), "streak_changed(1, 0) yayınlandı: %s" % str(resets))
	var rs := SimKit.events(b, SimEvents.STREAK_RESET)
	assert_eq(rs.size(), 1)
	if not rs.is_empty():
		assert_eq(rs[0]["reason"], &"window")
	assert_eq(_kill(b, PIYADE, 10), 10, "pencere dolunca yeni seri x1 başlar")
	assert_eq(b.score.best_mult, 2, "best_mult sıfırlamadan sonra da korunur")


func test_s3_streak_left_counts_down_from_three_seconds() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(5)
	_kill(sim)
	assert_almost_eq(sim.score.streak_left(sim.step_count), 3.0, 0.02)
	SimKit.run(sim, 90)
	assert_almost_eq(sim.score.streak_left(sim.step_count), 1.5, 0.03)
	SimKit.run(sim, 200)
	assert_eq(sim.score.streak_left(sim.step_count), 0.0)


func test_s4_contact_damage_breaks_streak_after_same_step_bullet_kills() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(6)
	for n in 25:
		_kill(sim, PIYADE, n)
	assert_eq(sim.score.mult, 3, "seri x3")
	var victim := SimKit.add_enemy(sim, PIYADE, Vector2(600, 0))
	sim.enemies.hp[EnemyPool.index_of(victim)] = 10.0
	sim.enemies.speed[EnemyPool.index_of(victim)] = 0.0
	var toucher := SimKit.add_enemy(sim, PIYADE, Vector2(40, 0))
	sim.enemies.hp[EnemyPool.index_of(toucher)] = 1.0e9
	sim.enemies.speed[EnemyPool.index_of(toucher)] = 0.0
	sim.spawn_projectile(Vector2(600, 0), Vector2(900, 0), 1.0e6)
	var hp0 := sim.hp
	var t := sim.step_count + 1
	sim.step(Vector2.ZERO)
	assert_lt(sim.hp, hp0, "aynı adımda temas hasarı")
	var kill_ev := {}
	for e in SimKit.events(sim, SimEvents.SCORE):
		if int(e["step"]) == t:
			kill_ev = e
	assert_eq(kill_ev.get("gain"), 30, "hasarla aynı adımdaki mermi öldürmesi x3 ile puanlanır")
	assert_eq(sim.score.mult, 1, "hasar seriyi ondan sonra bozar")
	assert_eq(sim.score.streak_count, 0)
	var rs := SimKit.events(sim, SimEvents.STREAK_RESET)
	assert_eq(rs.size(), 1)
	if not rs.is_empty():
		assert_eq(rs[0]["reason"], &"damage")
		assert_eq(int(rs[0]["step"]), t)
	assert_eq(_kill(sim, PIYADE, 30), 10, "sonraki adımın ilk öldürmesi seriyi 1'den başlatır")
	assert_eq(sim.score.streak_count, 1)


func _evolution_card(sim: GameSim) -> int:
	var cards := sim.pending_choices()
	for i in cards.size():
		if cards[i].kind == Choice.KIND_EVOLUTION:
			return i
	return -1


func test_s5_debug_grant_of_an_evolution_adds_no_points() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(7)
	sim.debug_grant(&"zincirleme_patlama")
	assert_eq(sim.score.evolution_part, 0, "debug_grant puan vermez")
	assert_eq(SimKit.count_events(sim, SimEvents.SCORE), 0)


func test_s5_each_chosen_evolution_adds_2000() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(17)
	sim.debug_grant(&"seken_mermi", 5)
	sim.debug_grant(&"barut_kesesi", 1)
	sim.debug_grant(&"son_mermi_patlar", 5)
	sim.debug_grant(&"hizli_doldurma", 1)
	assert_true(SimKit.level_up_with(sim, 12))
	var idx := _evolution_card(sim)
	assert_gte(idx, 0, "evrim kartı var")
	assert_true(sim.choose(idx))
	assert_eq(sim.score.evolution_part, 2000, "ilk evrim +2000")
	var ev := SimKit.last_event(sim, SimEvents.SCORE)
	assert_eq(ev.get("source"), &"evolution")
	assert_eq(ev.get("gain"), 2000)
	assert_true(SimKit.level_up_with(sim, XpCurve.need(sim.level)))
	var idx2 := _evolution_card(sim)
	assert_gte(idx2, 0, "ikinci evrim kartı")
	assert_true(sim.choose(idx2))
	assert_eq(sim.score.evolution_part, 4000, "iki evrim +4000")
	assert_eq(sim.evolved_log.size(), 2)


func test_s5_choosing_a_non_evolution_card_adds_no_points() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(18)
	assert_true(SimKit.level_up_with(sim, 12))
	assert_true(sim.choose(0))
	assert_eq(sim.score.evolution_part, 0)


func test_s6_survival_is_5_points_per_second_from_run_start() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(8)
	SimKit.run(sim, 600)
	assert_between(sim.score.survival_part, 49, 51, "600 adım = 10 sn = 50 puan")
	var late := _sim(8, {"start_time": 600.0})
	SimKit.run(late, 120)
	assert_between(late.score.survival_part, 9, 11, "start_time bedava puan vermez (2 sn = 10)")
	assert_eq(SimKit.count_events(sim, SimEvents.SCORE), 0, "hayatta kalma sızması olay yayınlamaz")


func test_s7_lord_kill_adds_25000_bonus_on_top_of_its_10000_kill_points() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(9)
	var got := _capture_end(sim)
	var gain := _kill(sim, &"kale_lordu")
	assert_eq(gain, 10000, "Lord'un kendi öldürme puanı")
	sim.step(Vector2.ZERO)
	assert_eq(sim.state, GameSim.State.WON)
	assert_eq(sim.score.lord_part, 25000)
	assert_eq(got.size(), 1)
	if got.is_empty():
		return
	var st: Dictionary = got[0][1]
	assert_true(got[0][0])
	assert_eq(st["score_parts"]["lord"], 25000)
	assert_eq(st["score_parts"]["kills"], 10000)
	assert_eq(st["score"], sim.score.total())
	var lord_ev := SimKit.events(sim, SimEvents.SCORE).filter(
		func(e: Dictionary) -> bool: return e["source"] == &"lord"
	)
	assert_eq(lord_ev.size(), 1)
	if not lord_ev.is_empty():
		assert_eq(lord_ev[0]["gain"], 25000)


func test_s7_lost_run_has_no_lord_bonus() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(10)
	var got := _capture_end(sim)
	_kill(sim)
	sim.hp = 0.0
	sim.step(Vector2.ZERO)
	assert_eq(sim.state, GameSim.State.LOST)
	assert_eq(got.size(), 1)
	if not got.is_empty():
		assert_false(got[0][0])
		assert_eq(got[0][1]["score_parts"]["lord"], 0)
		assert_eq(got[0][1]["best_mult"], 1)


func test_s7_timer_end_mode_lord_kill_does_not_grant_bonus() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(11, {"end_mode": "timer"})
	_kill(sim, &"kale_lordu")
	sim.step(Vector2.ZERO)
	assert_eq(sim.score.lord_part, 0, "Lord bonusu yalnız lord bitiş kipinde")


func test_s8_components_sum_to_total_and_match_run_ended_over_a_bot_run() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := SimKit.make(12, {"data_kind": "real", "pickups": false})
	SimKit.godmode(sim)
	var got := _capture_end(sim)
	var rng := Bots.make_rng(12)
	Bots.play(sim, Bots.KITE, 150 * 60, rng)
	sim.hp = 0.0
	sim.step(Vector2.ZERO)
	assert_eq(got.size(), 1)
	if got.is_empty():
		return
	var st: Dictionary = got[0][1]
	var p: Dictionary = st["score_parts"]
	assert_eq(p["kills"] + p["streak"] + p["evolution"] + p["survival"] + p["lord"], st["score"])
	assert_eq(st["score"], sim.score.total())
	var kill_evs := SimKit.events(sim, SimEvents.KILL)
	var score_evs := SimKit.events(sim, SimEvents.SCORE).filter(
		func(e: Dictionary) -> bool: return e["source"] == &"kill"
	)
	assert_eq(score_evs.size(), kill_evs.size(), "her öldürmeye bir SCORE olayı")
	var base := 0
	var streak := 0
	for i in mini(kill_evs.size(), score_evs.size()):
		var b: int = ExpectedTablesV11.KILL_POINTS[kill_evs[i]["enemy_type"]]
		base += b
		streak += int(score_evs[i]["gain"]) - b
	assert_eq(p["kills"], base, "kills = taban toplamı")
	assert_eq(p["streak"], streak, "streak = Σ taban x (çarpan-1)")
	assert_gt(kill_evs.size(), 20, "yeterli öldürme (test kapsamı)")


func test_s9_score_never_decreases_and_display_cap_helpers_clamp() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := SimKit.make(13, {"data_kind": "real", "pickups": false})
	SimKit.godmode(sim)
	var rng := Bots.make_rng(13)
	var last := 0
	var drops := 0
	for i in 20:
		Bots.play(sim, Bots.GREEDY, 120, rng)
		var t := sim.score.total()
		if t < last:
			drops += 1
		last = t
	assert_eq(drops, 0, "skor geriye gitmez")
	assert_gt(last, 0)
	var cap := ExpectedTablesV11.DISPLAY_CAP
	assert_eq(ScoreBlock.format_score(cap + 12345), UiKit.format_thousands(cap), "HUD tavan kırpma")
	assert_eq(ScoreBlock.format_score(cap), UiKit.format_thousands(cap))
	assert_eq(ScoreBlock.format_score(0), UiKit.format_thousands(0))


func test_s10_silent_make_room_removal_gives_no_points_and_keeps_streak() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := SimKit.make(14, {"data_kind": "real", "pickups": false, "start_time": 1199.0})
	SimKit.godmode(sim)
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	sim.debug_fill(PIYADE, EnemyPool.CAP, 900.0)
	for i in EnemyPool.CAP:
		if sim.enemies.alive[i] == 1:
			sim.enemies.speed[i] = 0.0
	assert_gte(sim.enemies.count, EnemyPool.CAP - 5, "havuz (neredeyse) dolu")
	var ok := SimKit.run_until(
		sim, func() -> bool: return SimKit.count_events(sim, SimEvents.BOSS_SPAWN) > 0, 240
	)
	assert_true(ok, "Lord doğdu")
	assert_eq(sim.kills, 0, "sessiz kaldırma öldürme sayılmaz")
	assert_eq(sim.score.kills_part, 0, "sessiz kaldırma puan vermez")
	assert_eq(sim.score.streak_count, 0, "seri etkilenmez")
	assert_eq(SimKit.count_events(sim, SimEvents.SCORE), 0)


func test_s11_same_seed_same_score_and_score_events() -> void:
	if V11Slice.require(self, SLICE):
		return
	var totals: Array[int] = []
	var logs: Array = []
	for r in 2:
		var sim := SimKit.make(15, {"data_kind": "real", "pickups": false})
		SimKit.godmode(sim)
		var rng := Bots.make_rng(15)
		Bots.play(sim, Bots.KITE, 90 * 60, rng)
		totals.append(sim.score.total())
		logs.append(SimKit.events(sim, SimEvents.SCORE))
	assert_eq(totals[0], totals[1], "aynı tohum aynı skor")
	assert_eq(logs[0], logs[1], "aynı score olayları")
	assert_gt(totals[0], 0)


func test_s12_score_changed_signal_gain_equals_the_multiplied_gain() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(16)
	var sig: Array = []
	sim.bus.score_changed.connect(
		func(score: int, mult: int, gain: int) -> void: sig.append([score, mult, gain])
	)
	for n in 12:
		_kill(sim, PIYADE, n)
	var ev := SimKit.events(sim, SimEvents.SCORE)
	assert_eq(sig.size(), 12, "her kazançta bir sinyal")
	assert_eq(ev.size(), 12)
	for i in mini(sig.size(), ev.size()):
		assert_eq(sig[i][2], ev[i]["gain"], "gain %d" % i)
		assert_eq(sig[i][1], ev[i]["mult"], "mult %d" % i)
		assert_eq(sig[i][0], ev[i]["total"], "total %d" % i)
		assert_eq(
			sig[i][2], 10 * _expected_mult(i + 1), "gain = taban x çarpan (%d. öldürme)" % (i + 1)
		)
	if sig.size() == 12:
		assert_eq(sig[11][0], sim.score.total(), "son sinyal toplamı")
