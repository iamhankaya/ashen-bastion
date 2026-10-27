extends GutTest
## v2.1 U2 (S dilimi): çarpanlar, Hızlı ölçeği, XP birikimli kesir, Sonsuz doğuş eğrisi / Lord tekrarı / enrage, hash kapsamı.
## Birim seviyesi: sim doğrudan kurulur; zaman `sim.time` ile ayarlanır, V21Sim.step doğrudan çağrılabilir (18000 adım koşmaz).

const LORD := &"kale_lordu"
const PIYADE := &"curumus_piyade"


func _sim(mode: StringName, diff: StringName, extra: Dictionary = {}) -> GameSim:
	var o := {"run_profile": V21Kit.profile(mode, diff), "pickups": false}
	o.merge(extra, true)
	return _tough(GameSim.new(5, &"gunslinger", o))


func _tough(s: GameSim) -> GameSim:
	s.max_hp = 1.0e9
	s.hp = 1.0e9
	return s


func _legacy() -> GameSim:
	return _tough(GameSim.new(5, &"gunslinger", {"pickups": false}))


func _base_hp(type_id: StringName) -> float:
	return GameData.load_default().get_enemy(type_id).hp


func _hp(s: GameSim, id: int) -> float:
	return s.enemies.hp[EnemyPool.index_of(id)]


func _lords(s: GameSim) -> int:
	var n := 0
	for id in s.alive_ids():
		if s.enemies.def_of(EnemyPool.index_of(id)).ai == &"lord":
			n += 1
	return n


func _kill(s: GameSim, id: int) -> void:
	s.damage_enemy(id, 1.0e9, &"explosion")


func _rows(rows: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"end_time": 1200, "rows": rows}
	d.merge(extra, true)
	return d


# --- legacy / profil yok: sıfır ek iş --------------------------------------------------------------


func test_s1_legacy_profile_and_no_profile_have_the_same_state_hash() -> void:
	var a := _legacy()
	var b := _tough(
		GameSim.new(5, &"gunslinger", {"pickups": false, "run_profile": RunProfile.legacy()})
	)
	assert_null(a.v21)
	assert_null(b.v21, "legacy profilde sim ek durum kurmaz")
	for i in 300:
		a.step(Vector2(1, 0))
		b.step(Vector2(1, 0))
	assert_eq(a.state_hash(), b.state_hash())


func test_s2_a_non_legacy_profile_changes_the_run() -> void:
	var a := _legacy()
	var b := _sim(&"normal", &"easy")
	a.debug_set_time(60.0)
	b.debug_set_time(60.0)
	for i in 300:
		a.step(Vector2.ZERO)
		b.step(Vector2.ZERO)
	assert_ne(a.state_hash(), b.state_hash())


# --- düşman HP / hız / Lord HP ---------------------------------------------------------------------


func test_s3_enemy_hp_uses_difficulty_multiplier_and_curve_t() -> void:
	var s := _sim(&"normal", &"easy")
	var id := s.spawn_enemy(PIYADE, Vector2(900, 0))
	assert_almost_eq(_hp(s, id), _base_hp(PIYADE) * 0.7, 0.001)
	var q := _sim(&"quick", &"hard")
	q.debug_set_time(120.0)
	var iq := q.spawn_enemy(PIYADE, Vector2(900, 0))
	var want := _base_hp(PIYADE) * Difficulty.enemy_hp_mult(240.0)
	assert_almost_eq(_hp(q, iq), want, 0.01, "Hızlı: eğri t / 0,5 okur")


func test_s4_enemy_speed_follows_curve_t_not_hp_multiplier() -> void:
	var q := _sim(&"quick", &"easy")
	q.debug_set_time(600.0)
	var id := q.spawn_enemy(PIYADE, Vector2(900, 0))
	var def := q.data.get_enemy(PIYADE)
	var want := def.speed * Difficulty.enemy_speed_mult(1200.0)
	assert_almost_eq(q.enemies.speed[EnemyPool.index_of(id)], want, 0.01)


func test_s5_lord_hp_is_base_times_lord_hp_times_mode_multiplier_only() -> void:
	var n := _sim(&"normal", &"normal")
	assert_almost_eq(_hp(n, n.spawn_enemy(LORD, Vector2(900, 0))), 45000.0 * 0.85, 0.5)
	var q := _sim(&"quick", &"easy")
	q.debug_set_time(300.0)  # zaman eğrisi Lord'a uygulanmaz
	assert_almost_eq(_hp(q, q.spawn_enemy(LORD, Vector2(900, 0))), 45000.0 * 0.7 * 0.5, 0.5)
	var l := _legacy()
	assert_almost_eq(_hp(l, l.spawn_enemy(LORD, Vector2(900, 0))), 45000.0, 0.5)


func test_s6_extra_hp_multiplier_composes_with_profile_multiplier() -> void:
	var n := _sim(&"normal", &"normal")
	assert_almost_eq(_hp(n, n.spawn_enemy(LORD, Vector2(900, 0), 1.5)), 45000.0 * 0.85 * 1.5, 0.5)


# --- temas hasarı ---------------------------------------------------------------------------------


func _contact(s: GameSim, type_id: StringName) -> float:
	var id := s.spawn_enemy(type_id, s.player_pos)
	s.grid.insert(id, s.player_pos)
	return s.damage.contact_tick(s, 1.0)


func test_s7_contact_damage_applies_difficulty_multiplier_to_every_enemy() -> void:
	var def := GameData.load_default().get_enemy(PIYADE)
	var e := _sim(&"normal", &"easy")
	assert_almost_eq(_contact(e, PIYADE), def.dmg * 0.40, 0.001)


func test_s8_lord_contact_gets_profile_multiplier_but_not_the_time_curve() -> void:
	var e := _sim(&"normal", &"easy")
	e.debug_set_time(600.0)
	assert_almost_eq(
		_contact(e, LORD), 40.0 * 0.40, 0.001, "Lord scales_with_time=false: yalnız profil çarpanı"
	)


func test_s9_contact_curve_reads_curve_t() -> void:
	var q := _sim(&"quick", &"hard")
	q.debug_set_time(300.0)
	var def := GameData.load_default().get_enemy(PIYADE)
	assert_almost_eq(_contact(q, PIYADE), def.dmg * Difficulty.enemy_dmg_mult(600.0), 0.001)


func test_s10_enrage_scales_contact_damage_after_threshold() -> void:
	var def := GameData.load_default().get_enemy(PIYADE)
	var e := _sim(&"endless", &"hard")
	e.debug_set_time(1499.0)
	var before := _contact(e, PIYADE)
	assert_almost_eq(
		before, def.dmg * Difficulty.enemy_dmg_mult(1499.0), 0.001, "eşik öncesi enrage yok"
	)
	var f := _sim(&"endless", &"hard")
	f.debug_set_time(2100.0)  # 600 sn sonra: 1 + 0,35 · 10 = 4,5
	assert_almost_eq(_contact(f, PIYADE), def.dmg * Difficulty.enemy_dmg_mult(2100.0) * 4.5, 0.01)


func test_s11_enrage_also_hits_the_lord() -> void:
	var f := _sim(&"endless", &"hard")
	f.debug_set_time(2100.0)
	assert_almost_eq(_contact(f, LORD), 40.0 * 4.5, 0.01)


# --- XP birikimli kesir ----------------------------------------------------------------------------


func _kill_infantry(s: GameSim, n: int) -> int:
	for i in n:
		_kill(s, s.spawn_enemy(PIYADE, Vector2(900 + i, 0)))
	return s.gems.total_value()


func test_s12_xp_carry_loses_nothing_for_quick() -> void:
	assert_eq(_kill_infantry(_sim(&"quick", &"hard"), 4), 6, "4 × 1,5")
	assert_eq(_kill_infantry(_sim(&"quick", &"hard"), 1), 1, "tek piyade: 1,5 → 1, kalan 0,5")


func test_s13_xp_carry_loses_nothing_for_easy() -> void:
	assert_eq(_kill_infantry(_sim(&"normal", &"easy"), 8), 10, "8 × 1,25")


func test_s14_xp_carry_composes_mode_and_difficulty() -> void:
	assert_eq(_kill_infantry(_sim(&"quick", &"easy"), 8), 15, "8 × 1,5 × 1,25")


func test_s15_every_kill_still_drops_a_gem_of_at_least_the_base_value() -> void:
	var s := _sim(&"quick", &"hard")
	for i in 6:
		var before := s.gems.count
		_kill(s, s.spawn_enemy(PIYADE, Vector2(900 + i, 0)))
		assert_eq(s.gems.count, before + 1)
		assert_gte(s.gems.value[s.gems.count - 1], 1)


func test_s16_legacy_xp_is_untouched() -> void:
	assert_eq(_kill_infantry(_legacy(), 4), 4)


# --- WaveScaler / Hızlı / PickupDirector ---------------------------------------------------------


func test_s17_quick_uses_scaled_waves_and_end_time_600() -> void:
	var q := _sim(&"quick", &"hard")
	assert_eq(q.end_time, 600.0)
	assert_eq(q.spawn_director.waves["end_time"], 600.0)
	var l := _legacy()
	assert_same(l.spawn_director.waves, l.data.waves, "legacy: ölçekleme kopyası yok")


func test_s18_quick_lord_arrives_at_600() -> void:
	var q := _sim(&"quick", &"hard", {"start_time": 598.0})
	for i in 60:
		q.step(Vector2.ZERO)
	assert_eq(_lords(q), 0, "599 sn: Lord yok")
	for i in 90:
		q.step(Vector2.ZERO)
	assert_eq(_lords(q), 1, "600 sn'den sonra Lord var")


func test_s19_pickup_interval_is_scaled_by_time_scale() -> void:
	var l := GameSim.new(5, &"gunslinger", {})
	var q := GameSim.new(5, &"gunslinger", {"run_profile": V21Kit.profile(&"quick", &"hard")})
	var base: Vector2 = l.pickup_director.get("_interval")
	assert_gt(base.x, 0.0)
	assert_eq(q.pickup_director.get("_interval"), base * 0.5)


# --- doğuş yoğunluğu ve rate_mult ------------------------------------------------------------------


func _spawn_steps(s: GameSim, waves: Dictionary, steps: int) -> int:
	s.spawn_director = SpawnDirector.new(waves)
	for i in steps:
		s.time += GameSim.STEP
		s.spawn_director.step(s)
	return s.enemies.count


func test_s20_rate_row_scales_with_density() -> void:
	var w := _rows(
		[{"kind": "rate", "type": "curumus_piyade", "from": 0, "to": 1200, "rate": [60, 60]}]
	)
	# Kayan nokta birikimi bir doğuşu iki yana kaydırabilir: ±1 payı.
	assert_between(_spawn_steps(_legacy(), w, 10), 9, 10)
	assert_between(_spawn_steps(_sim(&"normal", &"easy"), w, 10), 6, 7, "0,70")


func test_s21_rate_mult_scales_only_rate_rows() -> void:
	var cfg := V21Kit.mutated(V21Kit.cfg(), "modes.normal.rate_mult", 2.0)
	var s := _tough(
		GameSim.new(
			5,
			&"gunslinger",
			{"pickups": false, "run_profile": RunProfile.make(&"normal", &"hard", cfg)}
		)
	)
	var w := _rows(
		[{"kind": "rate", "type": "curumus_piyade", "from": 0, "to": 1200, "rate": [60, 60]}]
	)
	assert_between(_spawn_steps(s, w, 10), 19, 20)


func test_s22_group_and_burst_counts_scale_and_never_drop_below_one() -> void:
	var g := _rows(
		[
			{
				"kind": "group",
				"type": "curumus_piyade",
				"from": 0,
				"to": 1200,
				"group": [10, 10],
				"every": [1000, 1000]
			}
		]
	)
	assert_eq(_spawn_steps(_sim(&"normal", &"easy"), g, 1), 7)
	var b := _rows(
		[{"kind": "burst", "type": "curumus_piyade", "at": 0, "count": 10, "ring": true}]
	)
	assert_eq(_spawn_steps(_sim(&"normal", &"easy"), b, 1), 7)
	var cfg := V21Kit.mutated(V21Kit.cfg(), "difficulties.easy.spawn_density", 0.1)
	var tiny := _tough(
		GameSim.new(
			5,
			&"gunslinger",
			{"pickups": false, "run_profile": RunProfile.make(&"normal", &"easy", cfg)}
		)
	)
	var one := _rows(
		[{"kind": "burst", "type": "curumus_piyade", "at": 0, "count": 2, "ring": true}]
	)
	assert_eq(_spawn_steps(tiny, one, 1), 1, "roundi(0,2) = 0 → maxi(1, …)")


func test_s23_alive_cap_follows_curve_t() -> void:
	var w := _rows(
		[{"kind": "rate", "type": "curumus_piyade", "from": 0, "to": 1200, "rate": [6000, 6000]}]
	)
	var l := _legacy()
	l.time = 100.0
	assert_eq(_spawn_steps(l, w, 1), 70, "40 + 0,3·100")
	var q := _sim(&"quick", &"hard")
	q.time = 100.0
	assert_eq(_spawn_steps(q, w, 1), 100, "Hızlı: 40 + 0,3·200")


# --- Sonsuz: doğuş eğrisi ---------------------------------------------------------------------------


func test_s24_endless_rate_and_group_rows_keep_running_past_to() -> void:
	var rate := _rows(
		[{"kind": "rate", "type": "curumus_piyade", "from": 0, "to": 100, "rate": [60, 60]}]
	)
	var e := _sim(&"endless", &"hard")
	e.time = 200.0
	assert_between(_spawn_steps(e, rate, 10), 9, 10)
	var l := _sim(&"normal", &"hard")
	l.time = 200.0
	assert_eq(_spawn_steps(l, rate, 10), 0, "Lord modu: to sonrası durur")
	var grp := _rows(
		[
			{
				"kind": "group",
				"type": "curumus_piyade",
				"from": 0,
				"to": 100,
				"group": [2, 2],
				"every": [1000, 1000]
			}
		]
	)
	var g := _sim(&"endless", &"hard")
	g.time = 200.0
	assert_eq(_spawn_steps(g, grp, 1), 2)


func test_s25_endless_has_no_after_lord_halving() -> void:
	var w := _rows(
		[{"kind": "rate", "type": "curumus_piyade", "from": 0, "to": 100, "rate": [60, 60]}],
		{"after_lord": {"piyade_rate_mult": 0.5, "karga_stop": true}}
	)
	var e := _sim(&"endless", &"hard")
	e.time = 1300.0
	assert_between(_spawn_steps(e, w, 10), 9, 10)
	var l := _sim(&"normal", &"hard")
	l.time = 1300.0
	assert_between(_spawn_steps(l, w, 10), 4, 5, "Lord modu: after_lord yarı hız")


func test_s26_endless_burst_fires_once() -> void:
	var w := _rows(
		[{"kind": "burst", "type": "curumus_piyade", "at": 100, "count": 5, "ring": true}]
	)
	var e := _sim(&"endless", &"hard")
	e.time = 200.0
	assert_eq(_spawn_steps(e, w, 20), 5)


func test_s27_endless_first_lord_spawns_from_the_wave_row() -> void:
	var e := _sim(&"endless", &"hard", {"start_time": 1198.0})
	for i in 240:
		e.step(Vector2.ZERO)
	assert_eq(_lords(e), 1)
	assert_eq(e.v21.repeat_n, 0)
	assert_eq(e.v21.next_lord_t, -1.0)


# --- Sonsuz: Lord ölümü ----------------------------------------------------------------------------


func _slay_lord(s: GameSim) -> void:
	_kill(s, s.spawn_enemy(LORD, Vector2(900, 0)))


func test_s28_endless_lord_death_sets_milestone_not_state() -> void:
	var e := _sim(&"endless", &"hard")
	var got := {"ms": 0, "slain": []}
	e.bus.milestone_reached.connect(func() -> void: got["ms"] += 1)
	e.bus.lord_slain.connect(func(n: int) -> void: got["slain"].append(n))
	_slay_lord(e)
	assert_true(e.milestone_won)
	assert_eq(e.lords_killed, 1)
	assert_false(e.lord_killed, "Sonsuz'da lord_killed set edilmez")
	e.step(Vector2.ZERO)
	assert_eq(e.state, GameSim.State.RUNNING, "Sonsuz sürer")
	_slay_lord(e)
	assert_eq(e.lords_killed, 2)
	assert_eq(got["ms"], 1, "milestone_reached yalnız ilk")
	assert_eq(got["slain"], [1, 2])


func test_s29_every_endless_lord_gives_the_lord_bonus() -> void:
	var e := _sim(&"endless", &"hard")
	var s0 := e.score.total()
	_slay_lord(e)
	var one := e.score.total() - s0
	_slay_lord(e)
	var two := e.score.total() - s0 - one
	assert_gt(one, 0)
	assert_eq(two, one, "her Lord için aynı bonus")


func test_s30_lord_mode_death_still_wins_and_leaves_endless_fields_alone() -> void:
	var n := _sim(&"normal", &"hard")
	_slay_lord(n)
	assert_true(n.lord_killed)
	assert_false(n.milestone_won)
	n.step(Vector2.ZERO)
	assert_eq(n.state, GameSim.State.WON)


func test_s31_run_end_result_reports_milestone_and_lord_count() -> void:
	var e := _sim(&"endless", &"hard")
	var got := []
	e.bus.run_ended.connect(func(w: bool, st: Dictionary) -> void: got.append([w, st]))
	_slay_lord(e)
	e.hp = 0.0
	e.step(Vector2.ZERO)
	assert_eq(e.state, GameSim.State.LOST)
	assert_eq(got.size(), 1)
	assert_false(got[0][0], "sim kaybetti")
	assert_true(got[0][1]["milestone_won"])
	assert_eq(got[0][1]["lords_killed"], 1)
	assert_true(V21Runs.run_won(e))


func test_s32_simultaneous_lord_and_player_death_counts_the_milestone() -> void:
	var e := _sim(&"endless", &"hard")
	e.hp = 0.0
	_slay_lord(e)  # _kill hp kontrolünden önce işlenir
	e.step(Vector2.ZERO)
	assert_true(e.milestone_won)
	assert_eq(e.state, GameSim.State.LOST)


# --- Sonsuz: Lord tekrarı (ölümden lord_repeat_sec sonra) ------------------------------------------


func _after_death(t_death: float) -> GameSim:
	var e := _sim(&"endless", &"hard")
	e.time = t_death
	_slay_lord(e)
	return e


func test_s33_repeat_is_scheduled_300_seconds_after_the_death() -> void:
	var e := _after_death(1500.0)
	assert_eq(e.v21.next_lord_t, 1800.0)


func test_s34_repeat_warns_5_seconds_early_then_spawns_exactly_at_the_time() -> void:
	var e := _after_death(1500.0)
	var warns := []
	e.bus.boss_warning.connect(func(k: StringName) -> void: warns.append(k))
	e.time = 1794.9
	V21Sim.step(e)
	assert_eq(warns.size(), 0)
	e.time = 1795.0
	V21Sim.step(e)
	V21Sim.step(e)
	assert_eq(warns, [LORD], "tek uyarı")
	e.time = 1799.9
	V21Sim.step(e)
	assert_eq(_lords(e), 0)
	e.time = 1800.0
	V21Sim.step(e)
	assert_eq(_lords(e), 1)
	assert_eq(e.v21.repeat_n, 1)
	assert_eq(e.v21.next_lord_t, -1.0)


func test_s35_a_lord_that_never_dies_never_repeats() -> void:
	var e := _sim(&"endless", &"hard")
	e.spawn_enemy(LORD, Vector2(900, 0))
	e.time = 9000.0
	for i in 5:
		V21Sim.step(e)
	assert_eq(_lords(e), 1)


func test_s36_repeat_hp_steps_up_by_the_repeat_multiplier_and_caps() -> void:
	var e := _after_death(1500.0)
	e.time = 1800.0
	V21Sim.step(e)
	var ids := e.alive_ids()
	var lord_hp := 0.0
	for id in ids:
		if e.enemies.def_of(EnemyPool.index_of(id)).ai == &"lord":
			lord_hp = _hp(e, id)
	assert_almost_eq(lord_hp, 45000.0 * 1.5, 1.0, "1. tekrar × 1,5 (Zor: lord_hp 1)")
	var c := _after_death(1500.0)
	c.v21.repeat_n = 9
	c.time = 1800.0
	V21Sim.step(c)
	for id in c.alive_ids():
		if c.enemies.def_of(EnemyPool.index_of(id)).ai == &"lord":
			assert_almost_eq(_hp(c, id), 45000.0 * 8.0, 1.0, "lord_hp_cap_mult 8")


func test_s37_failed_spawn_retries_every_step_without_restarting_the_timer() -> void:
	var e := _after_death(1500.0)
	e.spawn_director.make_room_enabled = false
	e.debug_fill(PIYADE, EnemyPool.CAP, 300.0)
	assert_eq(e.enemies.count, EnemyPool.CAP)
	e.time = 1801.0
	V21Sim.step(e)
	V21Sim.step(e)
	assert_eq(_lords(e), 0)
	assert_eq(e.v21.next_lord_t, 1800.0, "süre sayacı yeniden başlamaz")
	assert_eq(e.v21.repeat_n, 0)
	e.enemies.kill(e.alive_ids()[0])
	V21Sim.step(e)
	assert_eq(_lords(e), 1)
	assert_eq(e.v21.repeat_n, 1)


func test_s38_full_pool_makes_room_for_the_repeat_when_allowed() -> void:
	var e := _after_death(1500.0)
	e.debug_fill(PIYADE, EnemyPool.CAP, 300.0)
	e.time = 1800.0
	V21Sim.step(e)
	assert_eq(_lords(e), 1)


func test_s39_repeat_without_profile_parameters_does_not_schedule() -> void:
	var e := _tough(GameSim.new(5, &"gunslinger", {"end_mode": "endless", "pickups": false}))
	_slay_lord(e)
	assert_true(e.milestone_won)
	assert_eq(e.v21.next_lord_t, -1.0, "lord_repeat_sec yoksa tekrar yok")


# --- hash kapsamı ----------------------------------------------------------------------------------


func test_s40_endless_state_enters_the_hash_only_in_endless() -> void:
	var e := _sim(&"endless", &"hard")
	var h0 := e.state_hash()
	e.v21.repeat_n = 3
	assert_ne(e.state_hash(), h0, "Sonsuz: tekrar durumu hash'te")
	var n := _sim(&"normal", &"easy")
	var h1 := n.state_hash()
	n.lords_killed = 4
	n.milestone_won = true
	n.v21.repeat_n = 3
	assert_eq(n.state_hash(), h1, "Lord modunda Sonsuz alanları hash'e girmez")
	var l := _legacy()
	var h2 := l.state_hash()
	l.lords_killed = 4
	assert_eq(l.state_hash(), h2)


func test_s41_xp_carry_enters_the_hash_for_non_legacy_profiles_only() -> void:
	var q := _sim(&"quick", &"hard")
	var h := q.state_hash()
	q.v21.xp_carry = 0.5
	assert_ne(q.state_hash(), h)


func test_s42_endless_run_is_deterministic() -> void:
	var a := _sim(&"endless", &"normal", {"start_time": 1190.0})
	var b := _sim(&"endless", &"normal", {"start_time": 1190.0})
	for i in 900:
		a.step(Vector2(0.5, 0.5))
		b.step(Vector2(0.5, 0.5))
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.check_invariants(), PackedStringArray())


# --- K-C10b ----------------------------------------------------------------------------------------


func test_s43_reference_fixture_exists_for_the_golden_cases() -> void:
	var rec: Dictionary = V21RefKit.load_fixture().get("late", {})
	assert_eq(
		rec.size(),
		V21RefKit.LATE_CASES.size(),
		"ref.json commit'li; karşılaştırma test_contract_*_matches_the_reference_* içinde"
	)
