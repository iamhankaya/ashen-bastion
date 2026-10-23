extends GutTest
## PickupSystem (toplama, etkiler, bomba) — GameSim üzerinden.

const POFF := {"data_kind": "quiet", "pickups": false, "log_events": true}


func _sim(seed_value: int = 1) -> GameSim:
	return SimKit.make(seed_value, POFF)


func _drop_at_player(sim: GameSim, id: StringName, off: Vector2 = Vector2.ZERO) -> int:
	return sim.debug_spawn_pickup(id, sim.player_pos + off)


func test_collect_radius_is_inclusive_72() -> void:
	var sim := _sim()
	_drop_at_player(sim, &"kizil_iksir", Vector2(72, 0))
	_drop_at_player(sim, &"kizil_iksir", Vector2(73, 0))
	sim.hp = 10.0
	sim.debug_collect_pickups()
	assert_eq(sim.pickups.count, 1, "72 toplanır, 73 kalır")
	assert_eq(sim.hp, 35.0)
	assert_eq(SimKit.count_events(sim, SimEvents.PICKUP_COLLECT), 1)


func test_xp_magnet_does_not_pull_pickups() -> void:
	var sim := _sim()
	var p := sim.player_pos + Vector2(110, 0)
	sim.debug_spawn_pickup(&"kizil_iksir", p)
	SimKit.run(sim, 30)
	assert_eq(sim.pickups.pos[0], p)


func test_heal_caps_at_max_hp() -> void:
	var sim := _sim()
	sim.hp = sim.max_hp * 0.5
	var want := minf(sim.max_hp, sim.hp + 25.0)
	_drop_at_player(sim, &"kizil_iksir")
	sim.debug_collect_pickups()
	assert_eq(sim.hp, want)
	sim.hp = sim.max_hp - 5.0
	_drop_at_player(sim, &"kizil_iksir")
	sim.debug_collect_pickups()
	assert_eq(sim.hp, sim.max_hp)
	assert_eq(sim.pickups.count, 0, "can doluyken de tüketilir")
	assert_true(sim.check_invariants().is_empty())


func test_magnet_pulls_every_gem_present_but_not_later_ones() -> void:
	var sim := _sim()
	for k in 200:
		sim.gems.drop(sim.player_pos + Vector2(1500 + k, 0), 1)
	_drop_at_player(sim, &"cekim_tasi")
	sim.debug_collect_pickups()
	for k in sim.gems.count:
		assert_eq(sim.gems.pulled[k], 1)
	sim.gems.drop(sim.player_pos + Vector2(1200, 0), 1)
	assert_eq(sim.gems.pulled[sim.gems.count - 1], 0, "sonradan düşen çekilmez")
	assert_true(sim.check_invariants().is_empty(), "XP korunumu")


func test_damage_buff_scales_projectile_and_explosion_for_720_steps() -> void:
	var sim := _sim()
	var base_b := sim.stats.bullet_dmg_mult
	var base_e := sim.stats.explosion_dmg_mult
	_drop_at_player(sim, &"ofke_barutu")
	sim.debug_collect_pickups()
	assert_eq(sim.stats.bullet_dmg_mult, base_b * 1.5)
	assert_eq(sim.stats.explosion_dmg_mult, base_e * 1.5)
	var start := SimKit.last_event(sim, SimEvents.BUFF_START)
	assert_eq(start["kind"], &"damage")
	assert_false(start["refreshed"])
	SimKit.run(sim, 719)
	assert_true(sim.buffs.active(BuffManager.Kind.DAMAGE))
	sim.step(Vector2.ZERO)
	assert_false(sim.buffs.active(BuffManager.Kind.DAMAGE))
	assert_eq(sim.stats.bullet_dmg_mult, base_b)
	assert_eq(SimKit.count_events(sim, SimEvents.BUFF_END), 1)


func test_buff_refresh_resets_to_full_and_flags_refreshed() -> void:
	var sim := _sim()
	_drop_at_player(sim, &"kizgin_namlu")
	sim.debug_collect_pickups()
	SimKit.run(sim, 300)
	_drop_at_player(sim, &"kizgin_namlu")
	sim.debug_collect_pickups()
	assert_eq(sim.buffs.left_steps[BuffManager.Kind.FIRE_RATE], 720)
	assert_true(SimKit.last_event(sim, SimEvents.BUFF_START)["refreshed"])


func test_damage_and_rate_buffs_are_independent() -> void:
	var sim := _sim()
	_drop_at_player(sim, &"ofke_barutu")
	_drop_at_player(sim, &"kizgin_namlu")
	sim.debug_collect_pickups()
	assert_true(sim.buffs.active(BuffManager.Kind.DAMAGE))
	assert_true(sim.buffs.active(BuffManager.Kind.FIRE_RATE))
	assert_eq(sim.stats.buff_dmg_mult, 1.5)
	assert_almost_eq(sim.stats.buff_rate_mult, 1.4, 0.0001)


func test_buff_survives_stat_rebuild() -> void:
	var sim := _sim()
	_drop_at_player(sim, &"ofke_barutu")
	sim.debug_collect_pickups()
	sim.stats.rebuild(sim.loadout, sim.data)
	assert_almost_eq(sim.stats.bullet_dmg_mult, sim.stats.buff_dmg_mult * 1.0, 0.0001)
	assert_eq(sim.stats.buff_dmg_mult, 1.5)


func test_unlimited_drum_keeps_full_for_10_seconds_and_ends_full() -> void:
	var sim := _sim()
	_drop_at_player(sim, &"sonsuz_tambur")
	sim.debug_collect_pickups()
	assert_true(sim.magazine.unlimited)
	var e := SimEvents
	var foe := SimKit.add_enemy(sim, &"curumus_piyade", sim.player_pos + Vector2(300, 0))
	sim.enemies.hp[EnemyPool.index_of(foe)] = 1.0e9
	var shots_before := SimKit.count_events(sim, e.SHOT)
	for _s in 599:
		sim.step(Vector2.ZERO)
		assert_eq(sim.magazine.count, sim.magazine.cap)
	assert_gt(SimKit.count_events(sim, e.SHOT) - shots_before, 6, "cap'ten fazla atış")
	assert_eq(SimKit.count_events(sim, e.RELOAD_START), 0)
	var idx: Array = []
	for ev in SimKit.events(sim, e.SHOT):
		idx.append(ev["index_in_mag"])
	assert_true(idx.has(sim.magazine.cap) and idx.has(1), "ritim indeksi 1..cap döner")
	SimKit.run(sim, 2)
	assert_false(sim.magazine.unlimited)
	assert_eq(sim.magazine.count, sim.magazine.cap)


func test_pickup_while_reloading_cancels_reload() -> void:
	var sim := _sim()
	sim.magazine.count = 0
	sim.step(Vector2.ZERO)
	assert_true(sim.magazine.reloading)
	_drop_at_player(sim, &"sonsuz_tambur")
	sim.debug_collect_pickups()
	assert_false(sim.magazine.reloading)
	assert_eq(sim.magazine.count, sim.magazine.cap)
	assert_eq(SimKit.count_events(sim, SimEvents.RELOAD_END), 1)


func test_bomb_plants_at_pickup_position_and_explodes_after_48_steps() -> void:
	var sim := _sim()
	var at := sim.player_pos + Vector2(60, 0)
	sim.debug_spawn_pickup(&"kara_bomba", at)
	sim.debug_collect_pickups()
	assert_eq(sim.bombs.count, 1)
	var plant := SimKit.last_event(sim, SimEvents.BOMB_PLANT)
	assert_eq(plant["pos"], at)
	assert_eq(plant["radius"], 320.0)
	assert_eq(sim.bombs.fuse_steps[0], 48)
	var hp := sim.hp
	var gems := sim.gems.count
	SimKit.run(sim, 47)
	assert_eq(SimKit.count_events(sim, SimEvents.BOMB_EXPLODE), 0)
	sim.step(Vector2.ZERO)
	assert_eq(SimKit.count_events(sim, SimEvents.BOMB_EXPLODE), 1)
	assert_eq(sim.bombs.count, 0)
	var ex := SimKit.last_event(sim, SimEvents.EXPLOSION)
	assert_eq(ex["pos"], at)
	assert_eq(ex["radius"], 320.0)
	assert_eq(sim.hp, hp, "oyuncuya zarar yok")
	assert_eq(sim.gems.count, gems, "taşlara dokunmaz")


func test_bomb_hits_inside_radius_ignores_armor_and_spares_outside() -> void:
	var sim := _sim()
	SimKit.godmode(sim)
	var c := sim.player_pos + Vector2(1200, 0)
	var inside := SimKit.add_enemy(sim, &"sovalye_hayaleti", c + Vector2(200, 0))
	var outside := SimKit.add_enemy(sim, &"curumus_piyade", c + Vector2(600, 0))
	var ii := EnemyPool.index_of(inside)
	var oi := EnemyPool.index_of(outside)
	sim.enemies.hp[ii] = 1000.0
	sim.enemies.armor[ii] = 50.0
	var o_hp := sim.enemies.hp[oi]
	sim.step(Vector2.ZERO)  # ızgara adım içinde kurulur
	var n := sim.bomb_blast(c, 320.0, 600.0, 0.08, 600.0)
	assert_eq(n, 1)
	assert_eq(sim.enemies.hp[ii], 400.0, "zırh yok sayılır: 600 hasar")
	assert_eq(sim.enemies.hp[oi], o_hp)


func test_bomb_elite_and_lord_damage_is_max_of_min_and_fraction() -> void:
	var sim := _sim()
	SimKit.godmode(sim)
	var c := sim.player_pos + Vector2(1200, 0)
	var elite := SimKit.add_enemy(sim, &"elit_piyade", c)
	var lord := SimKit.add_enemy(sim, &"kale_lordu", c + Vector2(50, 0))
	var ei := EnemyPool.index_of(elite)
	var li := EnemyPool.index_of(lord)
	sim.enemies.max_hp[ei] = 1800.0
	sim.enemies.hp[ei] = 1800.0
	sim.enemies.max_hp[li] = 45000.0
	sim.enemies.hp[li] = 45000.0
	sim.step(Vector2.ZERO)
	sim.bomb_blast(c, 320.0, 600.0, 0.08, 600.0)
	assert_eq(sim.enemies.hp[ei], 1200.0, "max(600, 144) = 600")
	assert_eq(sim.enemies.hp[li], 45000.0 - 3600.0, "max(600, 3600)")


func test_bomb_kills_award_xp_and_events() -> void:
	var sim := _sim()
	SimKit.godmode(sim)
	var c := sim.player_pos + Vector2(1200, 0)
	SimKit.add_enemy(sim, &"curumus_piyade", c)
	var gems := sim.gems.count
	var kills := sim.kills
	sim.step(Vector2.ZERO)
	sim.bomb_blast(c, 320.0, 600.0, 0.08, 600.0)
	assert_eq(sim.kills, kills + 1)
	assert_gt(sim.gems.count, gems)


func test_full_bomb_pool_leaves_bomb_pickup_on_the_ground() -> void:
	var sim := _sim()
	for k in BombPool.CAP:
		sim.bombs.plant(Vector2(9000 + k, 0), 600, 320.0, 4)
	_drop_at_player(sim, &"kara_bomba")
	sim.debug_collect_pickups()
	assert_eq(sim.pickups.count, 1, "toplanmaz, yerde kalır")
	assert_eq(sim.bombs.count, BombPool.CAP)
	_drop_at_player(sim, &"kizil_iksir")
	sim.debug_collect_pickups()
	assert_eq(sim.pickups.count, 1, "diğer eklenti toplanır")


func test_bomb_fuse_freezes_during_level_up() -> void:
	var sim := _sim()
	sim.bombs.plant(Vector2(9000, 0), 48, 320.0, 4)
	SimKit.run(sim, 10)
	sim.debug_add_xp(1000000)
	assert_true(SimKit.run_to_level_up(sim))
	var fuse := sim.bombs.fuse_steps[0]
	for _s in 120:
		sim.step(Vector2.ZERO)
	assert_eq(sim.bombs.fuse_steps[0], fuse)
	assert_eq(SimKit.count_events(sim, SimEvents.BOMB_EXPLODE), 0)


func test_bomb_does_not_explode_after_run_ended() -> void:
	var sim := _sim()
	sim.bombs.plant(Vector2(9000, 0), 48, 320.0, 4)
	sim.hp = 0.0
	SimKit.run(sim, 5)
	assert_eq(sim.state, GameSim.State.LOST)
	var fuse := sim.bombs.fuse_steps[0]
	for _s in 120:
		sim.step(Vector2.ZERO)
	assert_eq(sim.bombs.fuse_steps[0], fuse)
	assert_eq(SimKit.count_events(sim, SimEvents.BOMB_EXPLODE), 0)


func test_same_seed_with_greedy_walk_has_equal_hashes() -> void:
	var hashes: Array[int] = []
	for _r in 2:
		var sim := SimKit.make(33, {"data_kind": "quiet", "log_events": false})
		SimKit.godmode(sim)
		for s in 4000:
			var move := Vector2.ZERO
			if sim.pickups.count > 0:
				move = (sim.pickups.pos[0] - sim.player_pos).normalized()
			sim.step(move)
		hashes.append(sim.state_hash())
		assert_true(sim.check_invariants().is_empty())
	assert_eq(hashes[0], hashes[1])
