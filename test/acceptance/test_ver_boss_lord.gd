extends GutTest
## Doğrulama (T20261023-64): Kale Lordu kazanmanın tek yolu. Gerçek `data/waves.json` ile: havuz doluyken, atlamalı
## `start_time`/`debug_set_time` ile, Lord ölümü = kazanma önceliği, Lord'un havuz baskısında hayatta kalması.
## Kod incelemesi kritik bulgusu (havuz doluyken Lord doğmuyor) fixture yerine gerçek veriyle yeniden sınanır.

const LORD := &"kale_lordu"


func _lord_events(sim: GameSim) -> Array:
	return SimKit.events(sim, SimEvents.BOSS_SPAWN).filter(
		func(e: Dictionary) -> bool: return e["enemy_type"] == LORD
	)


func _lord_alive_count(sim: GameSim) -> int:
	var n := 0
	for id in sim.alive_ids():
		if sim.enemies.type_id_of(EnemyPool.index_of(id)) == LORD:
			n += 1
	return n


## `steps` adım oynar; seviye atlamada ilk kartı seçer, her adım ölümsüzlüğü yeniler (choose max_hp'yi yeniden kurar).
func _play(sim: GameSim, steps: int) -> void:
	var n := 0
	while n < steps and sim.state in [GameSim.State.RUNNING, GameSim.State.LEVEL_UP]:
		SimKit.godmode(sim)
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			continue
		sim.step(Vector2.ZERO)
		n += 1


## Havuzu her adım başında doldurur: doğal boşalma (öldürme/geri taşıma) Lord'a yer açamaz; yalnız yer açma kuralı açar.
func _play_full_pool(sim: GameSim, steps: int) -> void:
	for i in steps:
		if sim.enemies.count < EnemyPool.CAP:
			sim.debug_fill(&"curumus_piyade", EnemyPool.CAP - sim.enemies.count, 1500.0)
		SimKit.godmode(sim)
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
		if sim.state != GameSim.State.RUNNING:
			return
		sim.step(Vector2.ZERO)


func _real(seed_value: int, start: float) -> GameSim:
	var sim := SimKit.make(seed_value, {"data_kind": "real", "start_time": start})
	SimKit.godmode(sim)
	return sim


func test_lord_spawns_with_a_full_pool_of_basic_enemies_real_waves() -> void:
	var sim := _real(301, 1196.0)
	assert_eq(sim.debug_fill(&"curumus_piyade", 400, 1100.0), 400)
	assert_eq(sim.enemies.count, EnemyPool.CAP)
	_play_full_pool(sim, 60 * 6)
	assert_eq(_lord_events(sim).size(), 1, "havuz her adım doluyken Lord yine de doğar")
	assert_eq(_lord_alive_count(sim), 1)
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_lord_spawns_with_a_full_pool_including_elites_and_knights() -> void:
	var sim := _real(302, 1196.0)
	for t in [&"elit_piyade", &"elit_sovalye", &"elit_karga"]:
		assert_gte(SimKit.add_enemy(sim, t, Vector2(1000, 0)), 0)
	assert_eq(sim.debug_fill(&"sovalye_hayaleti", 60, 1200.0), 60)
	assert_eq(sim.debug_fill(&"curumus_piyade", 337, 1100.0), 337)
	assert_eq(sim.enemies.count, EnemyPool.CAP)
	_play_full_pool(sim, 60 * 6)
	assert_eq(_lord_events(sim).size(), 1, "elit/şövalye dolu havuzda da Lord doğar")
	# yer açmak elit/Lord'u silmez: üç elit hâlâ canlı ya da gerçek ölümle (kill olayı) gitmiş olmalı
	var elite_alive := 0
	for id in sim.alive_ids():
		if sim.enemies.is_elite(EnemyPool.index_of(id)):
			elite_alive += 1
	assert_gte(elite_alive, 1, "Lord canlı (elit sayılır) ve silinmedi")


func test_lord_spawns_exactly_once_for_every_start_time_jump() -> void:
	for start in [1190.0, 1199.0, 1200.0, 1201.0, 1250.0, 1500.0, 3000.0]:
		var sim := _real(310 + int(start) % 97, start)
		_play(sim, 60 * (maxi(1200 - int(start), 0) + 5))
		assert_eq(_lord_events(sim).size(), 1, "start_time=%d: Lord bir kez doğar" % int(start))
		assert_eq(_lord_alive_count(sim), 1, "start_time=%d: tek Lord canlı" % int(start))
		assert_eq(
			SimKit.count_events(sim, SimEvents.BOSS_WARNING) <= 1,
			true,
			"start_time=%d: Lord uyarısı en çok bir kez" % int(start)
		)


func test_debug_set_time_jump_mid_run_still_spawns_lord() -> void:
	for target in [1100.0, 1199.99, 1200.0, 1600.0]:
		var sim := _real(320 + int(target) % 89, 0.0)
		_play(sim, 120)
		sim.debug_set_time(target)
		_play(sim, 60 * (maxi(1200 - int(target), 0) + 5))
		assert_eq(_lord_events(sim).size(), 1, "debug_set_time(%s): Lord doğar" % target)
		assert_eq(sim.check_invariants(), PackedStringArray())


func test_lord_warning_comes_5s_before_when_not_skipped() -> void:
	var sim := _real(330, 1190.0)
	_play(sim, 60 * 12)
	var warn := SimKit.events(sim, SimEvents.BOSS_WARNING).filter(
		func(e: Dictionary) -> bool: return e["kind"] == LORD
	)
	assert_eq(warn.size(), 1)
	var spawn := _lord_events(sim)
	assert_eq(spawn.size(), 1)
	var dt := float(int(spawn[0]["step"]) - int(warn[0]["step"])) * GameSim.STEP
	assert_almost_eq(dt, 5.0, 0.1, "uyarı doğuştan 5 sn önce")


func test_without_killing_the_lord_the_run_is_never_won() -> void:
	var sim := _real(340, 1195.0)
	_play(sim, 60 * 120)
	assert_eq(_lord_alive_count(sim), 1)
	assert_ne(sim.state, GameSim.State.WON, "süre dolsa da Lord yaşarken kazanılmaz")
	assert_false(sim.lord_killed)


func test_lord_kill_wins_even_when_player_dies_in_the_same_step() -> void:
	var sim := _real(350, 1196.0)
	_play(sim, 60 * 6)
	var ev := _lord_events(sim)
	assert_eq(ev.size(), 1)
	var lord_id := int(ev[0]["id"])
	assert_true(sim.enemies.is_alive(lord_id))
	sim.damage_enemy(lord_id, 1.0e9, &"explosion")
	assert_true(sim.lord_killed)
	sim.hp = 0.0
	sim.step(Vector2.ZERO)
	assert_eq(sim.state, GameSim.State.WON, "Lord ölümü ölümden önce işlenir")
	assert_eq(SimKit.count_events(sim, SimEvents.RUN_END), 1)
	assert_true(bool(SimKit.last_event(sim, SimEvents.RUN_END)["won"]))


func test_lord_survives_pool_pressure_while_summoning() -> void:
	var sim := _real(360, 1196.0)
	_play(sim, 60 * 6)
	var lord_id := int(_lord_events(sim)[0]["id"])
	var dropped_before := sim.spawn_dropped
	for i in 60 * 60:
		# havuzu her adım doldur: çağırmalar kaybolur ama Lord yerinde kalır
		if sim.enemies.count < EnemyPool.CAP:
			sim.debug_fill(&"curumus_piyade", EnemyPool.CAP - sim.enemies.count, 1500.0)
		SimKit.godmode(sim)
		sim.step(Vector2.ZERO)
	assert_true(sim.enemies.is_alive(lord_id), "Lord havuz baskısında silinmez")
	assert_eq(_lord_events(sim).size(), 1)
	assert_gt(sim.spawn_dropped, dropped_before, "dolu havuzda çağırmalar kaybolur (sayaç)")
	assert_eq(sim.check_invariants(), PackedStringArray())


func test_timer_mode_never_spawns_the_lord() -> void:
	var sim := SimKit.make(370, {"data_kind": "real", "end_mode": "timer", "end_time": 1200.0})
	SimKit.godmode(sim)
	sim.debug_set_time(1195.0)
	_play(sim, 60 * 10)
	assert_eq(_lord_events(sim).size(), 0, "zamanlayıcı kipinde Lord yok")
	assert_eq(sim.state, GameSim.State.WON, "zamanlayıcı kipi süre dolunca kazanır")
