extends GutTest
## D3-1: skor kancaları GameSim/DamageSystem içinde (öldürme, temas hasarı, Lord, evrim, run_ended).


func _sim(opts: Dictionary = {}, seed_value: int = 1) -> GameSim:
	return SimKit.make(seed_value, opts)


func _kill(s: GameSim, type_id: StringName, pos: Vector2 = Vector2(600, 0)) -> void:
	var id := s.debug_spawn(type_id, pos)
	s.damage_enemy(id, 1.0e9, &"explosion")


func test_kill_scores_the_table_value_and_logs_events() -> void:
	var s := _sim()
	var changed: Array = []
	s.bus.score_changed.connect(func(t: int, m: int, g: int) -> void: changed.append([t, m, g]))
	_kill(s, &"elit_piyade")
	assert_eq(s.score.kills_part, 400)
	assert_eq(changed, [[400, 1, 400]])
	var ev := SimKit.events(s, SimEvents.SCORE)
	assert_eq(ev.size(), 1)
	assert_eq(
		[ev[0]["gain"], ev[0]["total"], ev[0]["mult"], ev[0]["source"]], [400, 400, 1, &"kill"]
	)


func test_silent_make_room_removal_gives_no_points_or_streak() -> void:
	var s := _sim()
	var id := s.debug_spawn(&"curumus_piyade", Vector2(600, 0))
	s.enemies.kill(id)  # SpawnDirector._make_room'un yaptığı gibi: DamageSystem dışı
	assert_eq(s.score.total(), 0)
	assert_eq(s.score.streak_count, 0)


func test_contact_damage_breaks_streak_before_player_damaged_signal() -> void:
	var s := _sim()
	for i in 25:
		s.score.on_kill(&"curumus_piyade", s.step_count)
	assert_eq(s.score.mult, 3)
	s.debug_spawn(&"curumus_piyade", s.player_pos + Vector2(5, 0))
	s.grid.clear()
	for i in EnemyPool.CAP:
		if s.enemies.alive[i] == 1:
			s.grid.insert(EnemyPool.make_id(s.enemies.gen[i], i), s.enemies.pos[i])
	var seen_mult: Array = []
	var keeper := s.score  # lambda sim'i yakalamasın (referans döngüsü sızıntısı)
	s.bus.player_damaged.connect(func(_a: float, _h: float) -> void: seen_mult.append(keeper.mult))
	assert_gt(s.damage.contact_tick(s, 1.0 / 60.0), 0.0)
	assert_eq(seen_mult, [1], "player_damaged yayınlandığında seri zaten bozulmuş")
	assert_eq(s.score.streak_count, 0)
	var ev := SimKit.events(s, SimEvents.STREAK_RESET)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0]["reason"], &"damage")


func test_window_expiry_logs_streak_reset_with_reason_window() -> void:
	var s := _sim()
	for i in 12:
		s.score.on_kill(&"curumus_piyade", 0)
	SimKit.run(s, 190)
	assert_eq(s.score.mult, 1)
	var ev := SimKit.events(s, SimEvents.STREAK_RESET)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0]["reason"], &"window")


func test_same_step_kill_then_damage_uses_old_multiplier_and_next_kill_restarts() -> void:
	var s := _sim()
	for i in 24:
		s.score.on_kill(&"curumus_piyade", 0)
	assert_eq(s.score.mult, 2)
	# Aynı adım: önce mermi öldürmesi (25. -> x3), sonra temas hasarı seriyi bozar.
	assert_eq(s.score.on_kill(&"curumus_piyade", 10), 30)
	s.score.break_streak(10)
	assert_eq(s.score.on_kill(&"curumus_piyade", 11), 10, "sonraki adımın ilk öldürmesi x1")
	assert_eq(s.score.streak_count, 1)


func test_lord_kill_awards_kill_points_plus_bonus_and_wins() -> void:
	var s := _sim({"end_mode": "lord"})
	var got: Array = []
	s.bus.run_ended.connect(func(w: bool, st: Dictionary) -> void: got.append([w, st]))
	_kill(s, &"kale_lordu")
	assert_eq(s.score.kills_part, 10000)
	assert_eq(s.score.lord_part, 25000)
	SimKit.run(s, 2)
	assert_eq(s.state, GameSim.State.WON)
	var st: Dictionary = got[0][1]
	assert_eq(st["score_parts"]["lord"], 25000)
	var p: Dictionary = st["score_parts"]
	assert_eq(st["score"], p["kills"] + p["streak"] + p["evolution"] + p["survival"] + p["lord"])
	assert_eq(st["score"], s.score.total())


func test_lord_not_killed_gives_no_lord_part() -> void:
	var s := _sim({"end_mode": "timer", "end_time": 1.0})
	var got: Array = []
	s.bus.run_ended.connect(func(w: bool, st: Dictionary) -> void: got.append(st))
	_kill(s, &"kale_lordu")
	assert_eq(s.score.lord_part, 0, "zamanlayıcı modunda Lord bonusu yok")
	s.hp = 0.0
	SimKit.run(s, 2)
	assert_eq(s.state, GameSim.State.LOST)
	assert_eq(got[0]["score_parts"]["lord"], 0)


func test_debug_grant_gives_no_evolution_points() -> void:
	var s := _sim()
	s.debug_grant(&"seken_mermi", 5)
	s.debug_grant(&"barut_kesesi", 1)
	assert_eq(s.score.evolution_part, 0)


func test_choosing_an_evolution_adds_2000() -> void:
	var s := _sim()
	s.debug_grant(&"seken_mermi", 5)
	s.debug_grant(&"barut_kesesi", 1)
	assert_true(SimKit.level_up_with(s, 12))
	var idx := SimKit.card_index(s, &"zincirleme_patlama")
	assert_gte(idx, 0)
	var seen: Array = []
	s.bus.score_changed.connect(func(_t: int, _m: int, g: int) -> void: seen.append(g))
	assert_true(s.choose(idx))
	assert_eq(s.score.evolution_part, 2000)
	assert_eq(seen, [2000])
	assert_eq(SimKit.last_event(s, SimEvents.SCORE)["source"], &"evolution")


func test_survival_accumulates_from_run_start_not_start_time() -> void:
	var s := _sim({"start_time": 600.0})
	SimKit.run(s, 60)
	assert_eq(s.score.survival_part, 5, "start_time bedava puan vermez")


func test_score_is_deterministic_and_monotonic_over_a_bot_run() -> void:
	var a := _sim({"data_kind": "real"}, 77)
	var b := _sim({"data_kind": "real"}, 77)
	SimKit.godmode(a)
	SimKit.godmode(b)
	var last := 0
	for i in 1800:
		a.step(Vector2(1, 0))
		b.step(Vector2(1, 0))
		var t := a.score.total()
		assert_gte(t, last)
		last = t
		if i % 300 == 0:
			assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.score.total(), b.score.total())
	assert_gt(a.score.total(), 0)
	assert_eq(a.check_invariants(), PackedStringArray())
