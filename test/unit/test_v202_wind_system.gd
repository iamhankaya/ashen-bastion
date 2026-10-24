extends GutTest
## U3: WindSystem.step — ömür, hareket, tik/çekme/savurma, elit kuralı, rezerv, determinizm.

const STEP := GameSim.STEP


func _twister(sim: GameSim, pos: Vector2, o: Dictionary = {}) -> int:
	var d := {"radius": 100.0, "life": 5.0, "tick_every": 0.4, "dmg": 10.0}
	d.merge(o, true)
	return WindSystem.spawn_zone(sim, ZonePool.KIND_TWISTER, pos, d)


func test_empty_pool_step_is_noop() -> void:
	var sim := WindKit.make()
	var before := sim.state_hash()
	WindKit.zone_steps(sim, 5)
	assert_eq(sim.state_hash(), before)


func test_zone_expires_after_its_life() -> void:
	var sim := WindKit.make()
	_twister(sim, Vector2(500, 0), {"life": 0.1})
	WindKit.zone_steps(sim, 5)
	assert_eq(sim.zones.count, 1)
	WindKit.zone_steps(sim, 3)
	assert_eq(sim.zones.count, 0)


func test_tick_damages_every_interval_once_and_ignores_armor() -> void:
	var sim := WindKit.make()
	var id := WindKit.dummy(sim, Vector2(300, 0), &"sovalye_hayaleti")  # zırh 3
	_twister(sim, Vector2(300, 0), {"speed": 0.0, "max_dist": 9999.0, "target": Vector2(300, 0)})
	var hp0 := WindKit.hp_of(sim, id)
	WindKit.zone_steps(sim, 23)
	assert_eq(WindKit.hp_of(sim, id), hp0, "ilk tik 0,4 sn sonra")
	WindKit.zone_steps(sim, 2)
	assert_almost_eq(WindKit.hp_of(sim, id), hp0 - 10.0, 0.001, "tik hasarı zırhı yok sayar")
	WindKit.zone_steps(sim, 24)
	assert_almost_eq(WindKit.hp_of(sim, id), hp0 - 20.0, 0.001)


func test_enemy_outside_radius_is_untouched() -> void:
	var sim := WindKit.make()
	var near := WindKit.dummy(sim, Vector2(300, 0))
	var far := WindKit.dummy(sim, Vector2(300 + 100 + 26 + 40, 0))  # yarıçap + düşman yarıçapı dışında
	_twister(sim, Vector2(300, 0), {"pull": 100.0, "target": Vector2(300, 0)})
	var far_pos := WindKit.pos_of(sim, far)
	WindKit.zone_steps(sim, 30)
	assert_lt(WindKit.hp_of(sim, near), WindKit.TOUGH_HP)
	assert_eq(WindKit.hp_of(sim, far), WindKit.TOUGH_HP)
	assert_eq(WindKit.pos_of(sim, far), far_pos)


func test_pull_moves_toward_center_and_never_overshoots() -> void:
	var sim := WindKit.make()
	var id := WindKit.dummy(sim, Vector2(380, 0))
	_twister(sim, Vector2(300, 0), {"pull": 60.0, "target": Vector2(300, 0)})
	WindKit.zone_steps(sim, 30)
	assert_almost_eq(WindKit.pos_of(sim, id).x, 380.0 - 30.0, 0.5, "60 px/sn x 0,5 sn")
	# Çok güçlü çekme merkeze varınca durur.
	var sim2 := WindKit.make()
	var id2 := WindKit.dummy(sim2, Vector2(330, 0))
	_twister(sim2, Vector2(300, 0), {"pull": 100000.0, "target": Vector2(300, 0)})
	WindKit.zone_steps(sim2, 5)
	var p := WindKit.pos_of(sim2, id2)
	assert_almost_eq(p.x, 300.0, 0.01)
	assert_true(is_finite(p.x) and is_finite(p.y), "merkezde NaN yok")


func test_enemy_exactly_at_center_has_no_nan() -> void:
	var sim := WindKit.make()
	var id := WindKit.dummy(sim, Vector2(300, 0))
	_twister(
		sim, Vector2(300, 0), {"pull": 80.0, "fling": 200.0, "life": 0.2, "target": Vector2(300, 0)}
	)
	WindKit.zone_steps(sim, 20)
	var p := WindKit.pos_of(sim, id)
	assert_true(is_finite(p.x) and is_finite(p.y))
	assert_gt(p.x, 300.0, "mesafe 0'da sağa savrulur")


func test_elite_takes_boss_mult_damage_but_is_never_moved() -> void:
	var sim := WindKit.make()
	var id := WindKit.dummy(sim, Vector2(300, 0), &"elit_piyade")
	_twister(
		sim,
		Vector2(300, 40),
		{
			"radius": 150.0,
			"pull": 500.0,
			"fling": 300.0,
			"boss_mult": 0.5,
			"life": 0.5,
			"target": Vector2(300, 40)
		}
	)
	var p0 := WindKit.pos_of(sim, id)
	WindKit.zone_steps(sim, 40)
	assert_eq(WindKit.pos_of(sim, id), p0, "elit çekilmez/savrulmaz")
	# 1 tik (10 x 0,5) + son savurmada 2x tik (20 x 0,5) = 15
	assert_almost_eq(WindKit.TOUGH_HP - WindKit.hp_of(sim, id), 15.0, 0.001)


func test_life_end_flings_outward_and_deals_double_tick() -> void:
	var sim := WindKit.make()
	var id := WindKit.dummy(sim, Vector2(360, 0))
	_twister(sim, Vector2(300, 0), {"fling": 220.0, "life": 0.1, "target": Vector2(300, 0)})
	WindKit.zone_steps(sim, 8)
	assert_eq(sim.zones.count, 0)
	assert_almost_eq(WindKit.pos_of(sim, id).x, 360.0 + 220.0, 1.0, "merkezden dışarı fling px")
	assert_almost_eq(WindKit.TOUGH_HP - WindKit.hp_of(sim, id), 20.0, 0.001, "2x tik hasarı")


func test_ground_enemy_is_not_flung_into_solid_ruin() -> void:
	var sim := WindKit.make()
	var m := sim.map
	var ruin := Vector2.ZERO
	var rr := 0.0
	for i in m.count:
		if m.ob_solid[i] == 1 and m.ob_pos[i].length() > 700.0:
			ruin = m.ob_pos[i]
			rr = m.ob_r[i]
			break
	if rr <= 0.0:
		pending("haritada katı harabe yok")
		return
	var dir := ruin.normalized()
	var start := ruin - dir * (rr + 80.0)
	var id := WindKit.dummy(sim, start)
	_twister(
		sim, start - dir * 30.0, {"fling": 600.0, "life": 0.05, "radius": 200.0, "target": start}
	)
	WindKit.zone_steps(sim, 6)
	var er := sim.enemies.radius[EnemyPool.index_of(id)]
	var end := WindKit.pos_of(sim, id)
	for c in sim.map.obstacles_near(end):
		assert_gte(end.distance_to(Vector2(c.x, c.y)), c.z + er - 1.0, "harabe dairesine gömülmedi")


func test_movement_goes_to_target_and_returns_when_too_far() -> void:
	var sim := WindKit.make()
	var i := _twister(
		sim,
		Vector2(250, 0),
		{"speed": 100.0, "max_dist": 400.0, "target": Vector2(2000, 0), "retarget": 99.0}
	)
	WindKit.zone_steps(sim, 60)
	assert_almost_eq(sim.zones.pos[i].x, 350.0, 1.0, "1 sn x 100 px/sn hedefe doğru")
	# max_dist aşılınca hedef oyuncuya (0,0) döner.
	WindKit.zone_steps(sim, 120)
	assert_lt(sim.zones.pos[i].x, 400.0, "oyuncudan max_dist ötesine gitmez")
	assert_eq(sim.zones.target[i], sim.player_pos)


func test_retarget_consumes_exactly_one_randf_even_without_enemies() -> void:
	var sim := WindKit.make()
	_twister(sim, Vector2(250, 0), {"speed": 0.0, "max_dist": 9999.0})  # retarget_left 0 => ilk adımda
	var ref := RandomNumberGenerator.new()
	ref.seed = sim.rng_combat.seed
	ref.state = sim.rng_combat.state
	ref.randf()
	WindKit.zone_steps(sim, 1)
	assert_eq(sim.rng_combat.state, ref.state, "tam 1 randf")
	assert_eq(
		sim.zones.target[0], sim.player_pos + WindSystem.IDLE_OFFSET, "düşman yok => oyuncu + ofset"
	)


func test_retarget_picks_nearby_enemy_from_sorted_ids() -> void:
	var sim := WindKit.make()
	var ids := PackedInt32Array()
	for k in 5:
		ids.append(WindKit.dummy(sim, Vector2(200 + 40 * k, 100)))
	_twister(sim, Vector2(250, 0), {"speed": 0.0, "max_dist": 9999.0})
	var ref := RandomNumberGenerator.new()
	ref.seed = sim.rng_combat.seed
	ref.state = sim.rng_combat.state
	var want := ids[int(ref.randf() * ids.size())]
	WindKit.zone_steps(sim, 1)
	assert_eq(sim.zones.target[0], WindKit.pos_of(sim, want))


func test_cast_twisters_ring_spacing_scaling_and_single_randf() -> void:
	var sim := WindKit.make()
	sim.debug_grant(&"furtina_gozu", 5)  # area x1,6 ; süre x1,5
	var ref := RandomNumberGenerator.new()
	ref.seed = sim.rng_combat.seed
	ref.state = sim.rng_combat.state
	ref.randf()
	var lv := {
		"count": 3,
		"radius": 190.0,
		"life": 8.0,
		"damage": 16.0,
		"interval": 0.35,
		"pull": 260.0,
		"fling": 260.0
	}
	WindSystem.cast_twisters(sim, ZonePool.KIND_GIANT, lv)
	assert_eq(sim.rng_combat.state, ref.state, "çağrı başına tek randf")
	assert_eq(sim.zones.count, 3)
	for i in 3:
		assert_eq(sim.zones.kind[i], ZonePool.KIND_GIANT)
		assert_almost_eq(sim.zones.pos[i].distance_to(sim.player_pos), WindSystem.SPAWN_DIST, 0.01)
		assert_almost_eq(sim.zones.radius[i], 190.0 * 1.6, 0.01)
		assert_almost_eq(sim.zones.life[i], 8.0 * 1.5, 0.01)
		assert_eq(sim.zones.speed[i], 110.0)
	var a0 := (sim.zones.pos[0] - sim.player_pos).angle()
	var a1 := (sim.zones.pos[1] - sim.player_pos).angle()
	assert_almost_eq(wrapf(a1 - a0, 0.0, TAU), TAU / 3.0, 0.001)


func test_pocket_reserve_blocks_pockets_but_not_twisters_and_counts_drops() -> void:
	var sim := WindKit.make()
	for k in ZonePool.CAP - ZonePool.RESERVE:
		WindSystem.spawn_zone(sim, ZonePool.KIND_POCKET, Vector2(k, 0), {"life": 9.0})
	assert_eq(sim.fx.zone_dropped, 0)
	assert_eq(WindSystem.spawn_zone(sim, ZonePool.KIND_POCKET, Vector2.ZERO, {"life": 9.0}), -1)
	assert_eq(sim.fx.zone_dropped, 1, "kayıp sessiz değil")
	WindSystem.cast_twisters(sim, ZonePool.KIND_GIANT, {"count": 3, "radius": 190.0, "life": 8.0})
	WindSystem.cast_twisters(sim, ZonePool.KIND_TWISTER, {"count": 2, "radius": 150.0, "life": 3.0})
	assert_eq(
		sim.zones.count,
		ZonePool.CAP - ZonePool.RESERVE + 5,
		"Tufan/Hortum rezervden doğar, kaybolmaz"
	)
	assert_eq(sim.fx.zone_dropped, 1)


func test_zone_killing_enemy_can_spawn_new_zone_without_breaking_iteration() -> void:
	var sim := WindKit.make(&"hava_cebi", 5)
	var b := WindKit.behavior_of(sim, &"hava_cebi")
	b._chance = 1.0
	var id := sim.debug_spawn(&"curumus_piyade", Vector2(300, 0))
	sim.enemies.hp[EnemyPool.index_of(id)] = 1.0
	_twister(
		sim,
		Vector2(300, 0),
		{"dmg": 50.0, "target": Vector2(300, 0), "speed": 0.0, "max_dist": 9999.0}
	)
	_twister(sim, Vector2(2000, 0), {"life": 0.01, "target": Vector2(2000, 0)})
	WindKit.zone_steps(sim, 25)
	assert_eq(sim.kills, 1)
	var pockets := 0
	for i in sim.zones.count:
		if sim.zones.kind[i] == ZonePool.KIND_POCKET:
			pockets += 1
	assert_eq(pockets, 1, "ölen düşmanın yerinde cep açıldı, gezi bozulmadı")


func test_same_seed_same_zone_hash_and_zones_enter_hash() -> void:
	var a := WindKit.make(&"", 1, 7)
	var b := WindKit.make(&"", 1, 7)
	for s in [a, b]:
		WindKit.dummy(s, Vector2(260, 0))
		WindSystem.cast_twisters(
			s, ZonePool.KIND_TWISTER, {"count": 2, "radius": 150.0, "life": 3.0, "damage": 8.0}
		)
		for _k in 90:
			s.step(Vector2.ZERO)
	assert_eq(a.state_hash(), b.state_hash())
	var h := a.state_hash()
	a.zones.remove(0)
	assert_ne(a.state_hash(), h, "bölgeler state_hash'e girer")
