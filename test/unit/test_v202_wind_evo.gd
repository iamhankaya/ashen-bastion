extends GutTest
## U3 E grubu: Kasırga Patlaması, Tufan (Ay Orağı ve Göğün Mızrağı test_v202_wind_basic'te).

const STEP := GameSim.STEP


func _waves(sim: GameSim) -> Array:
	var waves: Array = []
	sim.fx.wind_wave.connect(
		func(o: Vector2, r: float, big: bool) -> void: waves.append([o, r, big])
	)
	return waves


func _start_reload(sim: GameSim) -> void:
	sim.magazine.count = 0
	sim.magazine.start_reload(sim.stats)


func _tick_reload(sim: GameSim, n: int) -> void:
	var b := WindKit.behavior_of(sim, &"kasirga_patlamasi")
	for _k in n:
		b.on_reload_tick(STEP)


func test_kasirga_two_big_waves_second_after_half_second() -> void:
	var sim := WindKit.make(&"kasirga_patlamasi", 1)
	var id := WindKit.dummy(sim, Vector2(800, 0))
	WindKit.rebuild(sim)
	var waves := _waves(sim)
	_start_reload(sim)  # doldurma 1,3 sn
	assert_eq(waves.size(), 1)
	assert_eq(waves[0], [sim.player_pos, 900.0, true])
	assert_almost_eq(WindKit.TOUGH_HP - WindKit.hp_of(sim, id), 36.0, 0.001)
	_tick_reload(sim, 29)
	assert_eq(waves.size(), 1)
	_tick_reload(sim, 2)
	assert_eq(waves.size(), 2, "0,5 sn sonra ikinci dalga")
	_tick_reload(sim, 120)
	assert_eq(waves.size(), 2, "count 2: fazlası yok")


func test_kasirga_gap_shrinks_with_short_reload() -> void:
	var sim := WindKit.make(&"kasirga_patlamasi", 1)
	sim.magazine.base_reload = 0.5  # kısa doldurma
	var waves := _waves(sim)
	_start_reload(sim)
	var gap := minf(0.5, sim.magazine.reload_total * 0.8)
	assert_lt(gap, 0.5, "kısa doldurmada aralık doldurma x 0,8")
	_tick_reload(sim, int(gap / STEP) - 2)
	assert_eq(waves.size(), 1)
	_tick_reload(sim, 5)
	assert_eq(waves.size(), 2)


func test_kasirga_second_wave_is_cancelled_when_reload_ends_early() -> void:
	var sim := WindKit.make(&"kasirga_patlamasi", 1)
	var waves := _waves(sim)
	_start_reload(sim)
	_tick_reload(sim, 10)
	WindKit.behavior_of(sim, &"kasirga_patlamasi").on_reload_end()  # ör. Sonsuz Tambur / iptal
	_tick_reload(sim, 120)
	assert_eq(waves.size(), 1)
	sim.magazine.reloading = false
	_start_reload(sim)
	assert_eq(waves.size(), 2, "yeni doldurma yeniden çalışır")


func test_kasirga_timer_does_not_advance_while_sim_is_paused() -> void:
	var sim := WindKit.make(&"kasirga_patlamasi", 1)
	var waves := _waves(sim)
	_start_reload(sim)
	_tick_reload(sim, 10)
	# Seviye atlama/duraklatma: sim adımlanmaz => on_reload_tick çağrılmaz; zamanlayıcı kaldığı yerden sürer.
	assert_eq(waves.size(), 1)
	_tick_reload(sim, 21)
	assert_eq(waves.size(), 2)


func test_kasirga_runs_in_real_step_loop_and_not_with_endless_drum() -> void:
	var sim := SimKit.make(5, {"character": &"zyfen", "log_events": false})
	SimKit.godmode(sim)
	sim.debug_grant(&"kasirga_patlamasi", 1)
	sim.gun_cd = PackedFloat32Array([0.0, 0.1])
	WindKit.dummy(sim, Vector2(400, 0))
	var waves := _waves(sim)
	for _k in 600:
		sim.step(Vector2.ZERO)
	assert_gte(waves.size(), 2, "gerçek sim'de doldurmalarda dalga")
	var big := true
	for w in waves:
		big = big and w[2]
	assert_true(big)
	var sim2 := SimKit.make(5, {"character": &"zyfen", "log_events": false})
	SimKit.godmode(sim2)
	sim2.debug_grant(&"kasirga_patlamasi", 1)
	sim2.magazine.set_unlimited(true)
	WindKit.dummy(sim2, Vector2(400, 0))
	var waves2 := _waves(sim2)
	for _k in 600:
		sim2.step(Vector2.ZERO)
	assert_eq(waves2.size(), 0)


func test_tufan_three_giants_with_table_values() -> void:
	var sim := WindKit.make(&"tufan", 1)
	WindKit.dummy(sim, Vector2(300, 0))
	WindKit.skill_steps(sim, 1)
	assert_eq(sim.zones.count, 3)
	for i in 3:
		assert_eq(sim.zones.kind[i], ZonePool.KIND_GIANT)
		assert_almost_eq(sim.zones.radius[i], 190.0, 0.001)
		assert_almost_eq(sim.zones.life[i], 8.0, 0.05)
		assert_almost_eq(sim.zones.dmg[i], 20.0, 0.001)
		assert_almost_eq(sim.zones.tick_every[i], 0.35, 0.001)
		assert_almost_eq(sim.zones.pull[i], 260.0, 0.001)
		assert_almost_eq(sim.zones.fling[i], 260.0, 0.001)
		assert_eq(sim.zones.speed[i], 110.0)
		assert_eq(sim.zones.max_dist[i], 700.0)


func test_tufan_survives_a_full_zone_pool_and_is_not_dropped() -> void:
	var sim := WindKit.make(&"tufan", 1)
	for k in ZonePool.CAP - ZonePool.RESERVE:
		WindSystem.spawn_zone(sim, ZonePool.KIND_POCKET, Vector2(5000 + k, 0), {"life": 99.0})
	WindKit.dummy(sim, Vector2(300, 0))
	WindKit.skill_steps(sim, 1)
	var giants := 0
	for i in sim.zones.count:
		if sim.zones.kind[i] == ZonePool.KIND_GIANT:
			giants += 1
	assert_eq(giants, 3)
	assert_eq(sim.fx.zone_dropped, 0)


func test_tufan_life_scales_with_storm_eye() -> void:
	var sim := WindKit.make(&"tufan", 1)
	sim.debug_grant(&"furtina_gozu", 5)
	WindKit.dummy(sim, Vector2(300, 0))
	WindKit.skill_steps(sim, 1)
	assert_almost_eq(sim.zones.life[0], 12.0, 0.05, "8 sn x 1,5")
	assert_almost_eq(sim.zones.radius[0], 190.0 * 1.6, 0.001)
