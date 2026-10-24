extends GutTest
## U3 Z grubu: Girdap, Hortum, Hava Cebi, Nefes Dalgası, Fırtına Gözü etkisi.

const STEP := GameSim.STEP

# --- Girdap ----------------------------------------------------------------------------------------------


func test_girdap_one_pulse_per_interval_with_damage_and_outward_push() -> void:
	var sim := WindKit.make(&"girdap", 1)  # r90, hasar 6, 0,5 sn, push 14
	var id := WindKit.dummy(sim, Vector2(60, 0))
	var hp0 := WindKit.hp_of(sim, id)
	WindKit.skill_steps(sim, 29)
	assert_eq(WindKit.hp_of(sim, id), hp0, "ilk darbe 0,5 sn sonra")
	WindKit.skill_steps(sim, 2)
	assert_almost_eq(hp0 - WindKit.hp_of(sim, id), 6.0, 0.001)
	assert_almost_eq(WindKit.pos_of(sim, id).x, 60.0 + 14.0, 0.01, "dışa 14 px")
	WindKit.skill_steps(sim, 30)
	assert_almost_eq(hp0 - WindKit.hp_of(sim, id), 12.0, 0.001, "tam bir darbe daha")


func test_girdap_ignores_armor_and_does_not_push_elites() -> void:
	var sim := WindKit.make(&"girdap", 1)
	var id := WindKit.dummy(sim, Vector2(80, 0), &"elit_piyade")
	var p0 := WindKit.pos_of(sim, id)
	WindKit.skill_steps(sim, 31)
	assert_almost_eq(WindKit.TOUGH_HP - WindKit.hp_of(sim, id), 6.0, 0.001, "zırhsız 6 hasar")
	assert_eq(WindKit.pos_of(sim, id), p0, "elit itilmez")


func test_girdap_radius_follows_area_mult_every_step() -> void:
	var sim := WindKit.make(&"girdap", 1)
	var b := WindKit.behavior_of(sim, &"girdap")
	assert_almost_eq(b.current_radius(), 90.0, 0.001)
	sim.debug_grant(&"furtina_gozu", 5)
	assert_almost_eq(b.current_radius(), 90.0 * 1.6, 0.001, "Fırtına Gözü anında etki eder")
	# Yarıçap dışındaki düşman, Fırtına Gözü ile içeri girer.
	var id := WindKit.dummy(sim, Vector2(90 + 26 + 20, 0))
	var hp0 := WindKit.hp_of(sim, id)
	WindKit.skill_steps(sim, 31)
	assert_lt(WindKit.hp_of(sim, id), hp0)


func test_girdap_damage_scales_with_bullet_dmg_mult() -> void:
	var sim := WindKit.make(&"girdap", 1)
	sim.stats.set_buffs(2.0, 1.0)
	var id := WindKit.dummy(sim, Vector2(50, 0))
	WindKit.skill_steps(sim, 31)
	assert_almost_eq(WindKit.TOUGH_HP - WindKit.hp_of(sim, id), 12.0, 0.001)


# --- Hortum ----------------------------------------------------------------------------------------------


func test_hortum_does_not_cast_without_nearby_enemy_and_keeps_cooldown_ready() -> void:
	var sim := WindKit.make(&"hortum", 1)
	WindKit.skill_steps(sim, 120)
	assert_eq(sim.zones.count, 0)
	WindKit.dummy(sim, Vector2(300, 0))
	WindKit.skill_steps(sim, 1)
	assert_eq(sim.zones.count, 1, "düşman gelir gelmez atar (soğuma harcanmamıştı)")


func test_hortum_spawns_count_twisters_with_level_values() -> void:
	var sim := WindKit.make(&"hortum", 4)  # 2 hortum r200 ömür 3,8 hasar 14 çekme 100
	WindKit.dummy(sim, Vector2(300, 0))
	WindKit.skill_steps(sim, 1)
	assert_eq(sim.zones.count, 2)
	for i in 2:
		assert_eq(sim.zones.kind[i], ZonePool.KIND_TWISTER)
		assert_almost_eq(sim.zones.radius[i], 200.0, 0.001)
		assert_almost_eq(sim.zones.life[i], 3.8, 0.05)
		assert_almost_eq(sim.zones.dmg[i], 14.0, 0.001)
		assert_almost_eq(sim.zones.pull[i], 100.0, 0.001)
		assert_almost_eq(sim.zones.fling[i], 220.0, 0.001)
		assert_almost_eq(sim.zones.tick_every[i], 0.4, 0.001)
		assert_eq(sim.zones.speed[i], 90.0)
	assert_almost_eq(
		sim.zones.pos[0].distance_to(sim.zones.pos[1]), 2.0 * WindSystem.SPAWN_DIST, 4.0
	)


func test_hortum_cooldown_divides_by_fire_rate_and_respawns() -> void:
	var sim := WindKit.make(&"hortum", 1)  # soğuma 6,0
	WindKit.dummy(sim, Vector2(300, 0))
	sim.stats.set_buffs(1.0, 2.0)
	WindKit.skill_steps(sim, 1)
	assert_eq(sim.zones.count, 1)
	sim.zones.count = 0
	WindKit.skill_steps(sim, 170)
	assert_eq(sim.zones.count, 0, "6 / 2 = 3 sn dolmadı")
	WindKit.skill_steps(sim, 20)
	assert_eq(sim.zones.count, 1)


func test_hortum_wind_time_and_area_scale_at_spawn() -> void:
	var sim := WindKit.make(&"hortum", 1)
	sim.debug_grant(&"furtina_gozu", 5)
	WindKit.dummy(sim, Vector2(300, 0))
	WindKit.skill_steps(sim, 1)
	assert_almost_eq(sim.zones.radius[0], 150.0 * 1.6, 0.001)
	assert_almost_eq(sim.zones.life[0], 3.0 * 1.5, 0.05)


# --- Hava Cebi -------------------------------------------------------------------------------------------


func _kill_one(sim: GameSim, pos: Vector2) -> void:
	var id := sim.debug_spawn(&"curumus_piyade", pos)
	sim.damage_enemy(id, 1.0e6, &"bullet")


func test_hava_cebi_probability_over_1000_kills_with_exactly_one_randf_each() -> void:
	var sim := WindKit.make(&"hava_cebi", 1)  # chance 0.25
	var ref := RandomNumberGenerator.new()
	ref.seed = sim.rng_combat.seed
	ref.state = sim.rng_combat.state
	var pockets := 0
	for k in 1000:
		_kill_one(sim, Vector2(2000 + k, 0))
		ref.randf()
		pockets += sim.zones.count
		sim.zones.count = 0
	assert_eq(sim.rng_combat.state, ref.state, "kill başına tam 1 randf")
	assert_almost_eq(float(pockets) / 1000.0, 0.25, 0.05)
	assert_eq(sim.fx.zone_dropped, 0)


func test_hava_cebi_pocket_values_and_position() -> void:
	var sim := WindKit.make(&"hava_cebi", 5)
	sim.debug_grant(&"furtina_gozu", 5)
	WindKit.behavior_of(sim, &"hava_cebi")._chance = 1.0
	_kill_one(sim, Vector2(777, 33))
	assert_eq(sim.zones.count, 1)
	assert_eq(sim.zones.kind[0], ZonePool.KIND_POCKET)
	assert_eq(sim.zones.pos[0], Vector2(777, 33))
	assert_almost_eq(sim.zones.radius[0], 100.0 * 1.6, 0.001)
	assert_almost_eq(sim.zones.life[0], 2.0 * 1.5, 0.001)
	assert_almost_eq(sim.zones.pull[0], 50.0, 0.001)
	assert_almost_eq(sim.zones.dmg[0], 16.0, 0.001)


func test_pocket_tick_kill_never_chains_a_new_pocket() -> void:
	var sim := WindKit.make(&"hava_cebi", 5)
	WindKit.behavior_of(sim, &"hava_cebi")._chance = 1.0
	for k in 5:
		var id := sim.debug_spawn(&"curumus_piyade", Vector2(300 + k * 5, 0))
		sim.enemies.hp[EnemyPool.index_of(id)] = 1.0
	WindSystem.spawn_zone(
		sim,
		ZonePool.KIND_POCKET,
		Vector2(300, 0),
		{"radius": 120.0, "life": 2.0, "tick_every": 0.4, "dmg": 50.0}
	)
	var ref := RandomNumberGenerator.new()
	ref.seed = sim.rng_combat.seed
	ref.state = sim.rng_combat.state
	WindKit.zone_steps(sim, 30)
	assert_eq(sim.kills, 5, "cep tiki hepsini öldürdü")
	assert_eq(sim.zones.count, 1, "yeni cep doğmadı")
	assert_false(sim.wind.in_pocket_tick, "bayrak tik sonunda kapanır")
	assert_eq(sim.rng_combat.state, ref.state, "zincir engelinde randf harcanmaz")


func test_pocket_damage_ignores_armor_and_pulls() -> void:
	var sim := WindKit.make()
	var id := WindKit.dummy(sim, Vector2(350, 0), &"sovalye_hayaleti")
	WindSystem.spawn_zone(
		sim,
		ZonePool.KIND_POCKET,
		Vector2(300, 0),
		{"radius": 120.0, "life": 2.0, "tick_every": 0.4, "dmg": 10.0, "pull": 30.0}
	)
	WindKit.zone_steps(sim, 25)
	assert_almost_eq(WindKit.TOUGH_HP - WindKit.hp_of(sim, id), 10.0, 0.001)
	assert_lt(WindKit.pos_of(sim, id).x, 350.0)


# --- Nefes Dalgası ---------------------------------------------------------------------------------------


func test_nefes_dalgasi_single_wave_on_reload_start() -> void:
	var sim := WindKit.make(&"nefes_dalgasi", 1)  # r200 hasar 14 push 120
	var inside := WindKit.dummy(sim, Vector2(150, 0))
	var outside := WindKit.dummy(sim, Vector2(200 + 26 + 40, 0))
	var elite := WindKit.dummy(sim, Vector2(0, 150), &"elit_piyade")
	WindKit.rebuild(sim)
	var waves: Array = []
	sim.fx.wind_wave.connect(
		func(o: Vector2, r: float, big: bool) -> void: waves.append([o, r, big])
	)
	var ep := WindKit.pos_of(sim, elite)
	sim.magazine.count = 0
	sim.magazine.start_reload(sim.stats)
	assert_eq(waves.size(), 1)
	assert_eq(waves[0], [sim.player_pos, 200.0, false])
	assert_almost_eq(WindKit.TOUGH_HP - WindKit.hp_of(sim, inside), 14.0, 0.001)
	assert_almost_eq(WindKit.pos_of(sim, inside).x, 150.0 + 120.0, 0.01)
	assert_eq(WindKit.hp_of(sim, outside), WindKit.TOUGH_HP)
	assert_lt(WindKit.hp_of(sim, elite), WindKit.TOUGH_HP, "elit hasar alır")
	assert_eq(WindKit.pos_of(sim, elite), ep, "elit itilmez")
	WindKit.rebuild(sim)
	for _k in 30:
		sim.magazine.tick(STEP, sim.stats)
	assert_eq(waves.size(), 1, "doldurma boyunca tek dalga")


func test_nefes_dalgasi_does_not_fire_with_endless_drum() -> void:
	var sim := WindKit.make(&"nefes_dalgasi", 1)
	var id := WindKit.dummy(sim, Vector2(100, 0))
	sim.magazine.set_unlimited(true)
	sim.magazine.start_reload(sim.stats)
	for _k in 200:
		sim.magazine.tick(STEP, sim.stats)
	assert_eq(
		WindKit.hp_of(sim, id), WindKit.TOUGH_HP, "Sonsuz Tambur'da doldurma yok => dalga yok"
	)


func test_nefes_dalgasi_radius_scales_with_storm_eye() -> void:
	var sim := WindKit.make(&"nefes_dalgasi", 1)
	sim.debug_grant(&"furtina_gozu", 5)
	var id := WindKit.dummy(sim, Vector2(200 + 26 + 30, 0))
	WindKit.rebuild(sim)
	sim.magazine.count = 0
	sim.magazine.start_reload(sim.stats)
	assert_lt(WindKit.hp_of(sim, id), WindKit.TOUGH_HP)


# --- Fırtına Gözü ----------------------------------------------------------------------------------------


func test_storm_eye_level_5_multipliers() -> void:
	var sim := WindKit.make(&"furtina_gozu", 5)
	assert_almost_eq(sim.stats.area_mult, 1.6, 0.0001)
	assert_almost_eq(sim.stats.wind_time_mult, 1.5, 0.0001)
	var sim1 := WindKit.make(&"furtina_gozu", 1)
	assert_almost_eq(sim1.stats.area_mult, 1.12, 0.0001)
	assert_almost_eq(sim1.stats.wind_time_mult, 1.1, 0.0001)


func test_hava_cebi_chain_with_a_full_pool_never_exceeds_cap_or_loses_giants() -> void:
	var sim := WindKit.make(&"hava_cebi", 5)
	WindKit.behavior_of(sim, &"hava_cebi")._chance = 1.0
	# 56 cep (rezerv hariç doluluk; ilki tik atar) + 8 dev hortum = CAP 64.
	WindSystem.spawn_zone(
		sim,
		ZonePool.KIND_POCKET,
		Vector2(900, 900),
		{"radius": 80.0, "life": 99.0, "tick_every": 0.1, "dmg": 9.0}
	)
	for k in ZonePool.CAP - ZonePool.RESERVE - 1:
		WindSystem.spawn_zone(
			sim,
			ZonePool.KIND_POCKET,
			Vector2(3000 + 300 * k, 0),
			{"radius": 100.0, "life": 99.0, "tick_every": 99.0}
		)
	for k in ZonePool.RESERVE:
		WindSystem.spawn_zone(
			sim, ZonePool.KIND_GIANT, Vector2(0, 3000 + 300 * k), {"radius": 50.0, "life": 99.0}
		)
	assert_eq(sim.zones.count, ZonePool.CAP)
	# Normal ölümler cep doğurmaya çalışır: havuz dolu => doğmaz, sayaç artar, taşma yok.
	for k in 10:
		_kill_one(sim, Vector2(500 + k, 500))
	assert_eq(sim.zones.count, ZonePool.CAP)
	assert_eq(sim.fx.zone_dropped, 10)
	# Cep tiki ile ölen düşman zincir denemesi bile yapmaz: sayaç artmaz.
	var id := sim.debug_spawn(&"curumus_piyade", Vector2(900, 900))
	sim.enemies.hp[EnemyPool.index_of(id)] = 1.0
	WindKit.zone_steps(sim, 10)
	assert_eq(sim.kills, 11, "cep tiki öldürdü")
	assert_eq(sim.fx.zone_dropped, 10, "zincir denemesi yok")
	assert_eq(sim.zones.count, ZonePool.CAP)
