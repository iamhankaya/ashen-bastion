extends GutTest
## Kabul (v1.1 D2): Kara Bomba - toplama noktasında 0,8 sn fitil, alan hasarı, elit/Lord, havuz/durum kuralları (P15-P17).
## Dilim D2 bitmeden pending.

const SLICE := "D2"
const RADIUS := 320.0
const FUSE := 48


func _sim(seed_value: int = 1) -> GameSim:
	return SimKit.make(seed_value, {"data_kind": "quiet_pickups"})


## Oyuncu ateş etmesin (hasar ölçümünü kirletmesin).
func _mute_guns(sim: GameSim) -> void:
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])


func _foe(sim: GameSim, type_id: StringName, pos: Vector2, hp: float) -> int:
	var id := SimKit.add_enemy(sim, type_id, pos)
	var i := EnemyPool.index_of(id)
	sim.enemies.hp[i] = hp
	sim.enemies.speed[i] = 0.0
	return id


func _plant(sim: GameSim, at: Vector2) -> void:
	assert_gte(sim.debug_spawn_pickup(&"kara_bomba", at), 0)
	sim.debug_collect_pickups()


func test_p15_bomb_plants_at_pickup_position_and_blasts_after_48_steps() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(1)
	_mute_guns(sim)
	var at := Vector2(60, 0)
	var inside := _foe(sim, &"curumus_piyade", Vector2(60, 150), 1000.0)
	sim.enemies.armor[EnemyPool.index_of(inside)] = 50.0
	var outside := _foe(sim, &"curumus_piyade", Vector2(60, 700), 1000.0)
	sim.gems.drop(Vector2(60, 100), 7)
	var gems_before := sim.gems.total_value()
	var hp_before := sim.hp
	_plant(sim, at)
	var pl := SimKit.last_event(sim, SimEvents.BOMB_PLANT)
	assert_eq(pl.get("pos"), at, "bomb_plant toplama (eklenti) konumunda")
	assert_almost_eq(float(pl.get("radius", 0.0)), RADIUS, 0.001)
	var fuse := float(pl.get("fuse", 0.0))
	assert_true(
		absf(fuse - 0.8) < 0.001 or absf(fuse - float(FUSE)) < 0.001,
		"fitil 0,8 sn / 48 adım: %f" % fuse
	)
	assert_eq(sim.bombs.count, 1)
	var t0 := sim.step_count
	SimKit.run(sim, 40, Vector2.LEFT)  # oyuncu uzaklaşır
	assert_eq(SimKit.count_events(sim, SimEvents.EXPLOSION), 0, "fitil sürerken patlama yok")
	SimKit.run(sim, 12, Vector2.LEFT)
	var ex := SimKit.events(sim, SimEvents.EXPLOSION)
	assert_eq(ex.size(), 1, "tek patlama")
	if ex.is_empty():
		return
	assert_between(int(ex[0]["step"]) - t0, FUSE - 1, FUSE + 1, "48 adım sonra")
	assert_eq(ex[0]["pos"], at, "patlama toplama konumunda (oyuncu uzaklaşsa da)")
	assert_almost_eq(float(ex[0]["radius"]), RADIUS, 0.001)
	assert_gt(sim.player_pos.distance_to(at), 100.0, "oyuncu gerçekten uzaklaştı")
	var be := SimKit.last_event(sim, SimEvents.BOMB_EXPLODE)
	assert_eq(be.get("pos"), at)
	assert_gte(int(be.get("hits", 0)), 1)
	var dmg_inside := 0.0
	var dmg_outside := 0.0
	for e in SimKit.events(sim, SimEvents.DAMAGE):
		if e["kind"] != &"explosion":
			continue
		if e["target"] == inside:
			dmg_inside += float(e["amount"])
		if e["target"] == outside:
			dmg_outside += float(e["amount"])
	assert_almost_eq(dmg_inside, 600.0, 0.01, "zırhlı (armor 50) düşman tam 600 alır")
	assert_almost_eq(SimKit.enemy_hp(sim, inside), 400.0, 0.01)
	assert_eq(dmg_outside, 0.0, "dışarıdaki hasarsız")
	assert_almost_eq(SimKit.enemy_hp(sim, outside), 1000.0, 0.01)
	assert_almost_eq(sim.hp, hp_before, 0.001, "oyuncu hp değişmez")
	assert_eq(sim.gems.total_value(), gems_before, "XP taşları değişmez")
	assert_eq(sim.bombs.count, 0, "patlayan bomba havuzdan çıkar")


func test_p15_bomb_hits_use_enemy_radius_edge() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(2)
	_mute_guns(sim)
	var r := sim.data.get_enemy(&"curumus_piyade").radius
	var just_in := _foe(sim, &"curumus_piyade", Vector2(RADIUS + r - 2.0, 0), 1000.0)
	var just_out := _foe(sim, &"curumus_piyade", Vector2(-(RADIUS + r + 2.0), 0), 1000.0)
	_plant(sim, Vector2.ZERO)
	sim.player_pos = Vector2(0, 2000)
	SimKit.run(sim, FUSE + 2)
	assert_lt(SimKit.enemy_hp(sim, just_in), 1000.0, "yarıçap + düşman yarıçapı içinde: vurulur")
	assert_almost_eq(SimKit.enemy_hp(sim, just_out), 1000.0, 0.01, "dışında: vurulmaz")


func test_p16_elite_and_lord_take_max_of_600_and_8_percent_of_max_hp() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(3)
	_mute_guns(sim)
	var elit := _foe(sim, &"elit_piyade", Vector2(60, 120), 1800.0)
	var lord := _foe(sim, &"kale_lordu", Vector2(-60, 160), 45000.0)
	var ei := EnemyPool.index_of(elit)
	var li := EnemyPool.index_of(lord)
	var want_e := maxf(600.0, 0.08 * sim.enemies.max_hp[ei])
	var want_l := maxf(600.0, 0.08 * sim.enemies.max_hp[li])
	assert_almost_eq(want_e, 600.0, 0.5, "elit 1800 maks. can -> 600 (düzey çarpanı yok)")
	assert_almost_eq(want_l, 3600.0, 0.5, "Lord 45000 maks. can -> 3600")
	_plant(sim, Vector2.ZERO)
	sim.player_pos = Vector2(0, 2500)
	SimKit.run(sim, FUSE + 2)
	var got_e := 0.0
	var got_l := 0.0
	for e in SimKit.events(sim, SimEvents.DAMAGE):
		if e["kind"] != &"explosion":
			continue
		if e["target"] == elit:
			got_e += float(e["amount"])
		if e["target"] == lord:
			got_l += float(e["amount"])
	assert_almost_eq(got_e, want_e, 0.5, "elit hasarı")
	assert_almost_eq(got_l, want_l, 0.5, "Lord hasarı (tek vuruşta bitmez)")
	assert_true(sim.enemies.is_alive(lord))


func test_p16_bomb_kills_drop_xp_gems_and_count_as_kills() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(4)
	_mute_guns(sim)
	var weak := _foe(sim, &"curumus_piyade", Vector2(60, 100), 30.0)
	var elit := _foe(sim, &"elit_piyade", Vector2(-60, 140), 500.0)  # 600 hasarla ölür
	var kills0 := sim.kills
	var score0 := sim.score.total()
	_plant(sim, Vector2.ZERO)
	sim.player_pos = Vector2(0, 2500)
	SimKit.run(sim, FUSE + 2)
	assert_false(sim.enemies.is_alive(weak))
	assert_false(sim.enemies.is_alive(elit))
	assert_eq(sim.kills, kills0 + 2, "iki öldürme")
	assert_gte(sim.gems.count, 2, "ölenler XP taşı düşürür")
	assert_eq(SimKit.count_events(sim, SimEvents.GEM_DROPPED), 2)
	if V11Slice.done("D3"):
		assert_eq(sim.score.kills_part, 10 + 400, "bomba öldürmeleri skora yazılır")
		assert_gt(sim.score.total(), score0)


func test_p17_full_bomb_pool_blocks_collection() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(5)
	for k in BombPool.CAP:
		assert_gte(sim.bombs.plant(Vector2(3000 + k * 10, 0), 600, RADIUS, 4), 0)
	assert_true(sim.bombs.is_full())
	assert_gte(sim.debug_spawn_pickup(&"kara_bomba", sim.player_pos), 0)
	sim.debug_collect_pickups()
	assert_eq(sim.pickups.count, 1, "havuz doluyken eklenti toplanmaz, yerde kalır")
	assert_eq(sim.bombs.count, BombPool.CAP)
	assert_eq(SimKit.count_events(sim, SimEvents.PICKUP_COLLECT), 0)
	assert_eq(SimKit.count_events(sim, SimEvents.BOMB_PLANT), 0)


func test_p17_fuse_freezes_during_level_up_and_resumes() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(6)
	_mute_guns(sim)
	_plant(sim, Vector2(500, 0))
	SimKit.run(sim, 10)
	sim.debug_add_xp(100000)
	assert_true(SimKit.run_to_level_up(sim, 5))
	var fuse_at_freeze := sim.bombs.fuse_steps[0]
	for i in 120:
		sim.step(Vector2.ZERO)  # LEVEL_UP: no-op
	assert_eq(sim.bombs.fuse_steps[0], fuse_at_freeze, "LEVEL_UP'ta fitil donar")
	assert_eq(SimKit.count_events(sim, SimEvents.EXPLOSION), 0)
	assert_true(Bots.choose(sim, Bots.make_rng(6)))
	while sim.state == GameSim.State.LEVEL_UP:
		Bots.choose(sim, Bots.make_rng(7))
	var t0 := sim.step_count
	SimKit.run(sim, 200)
	var ex := SimKit.events(sim, SimEvents.EXPLOSION)
	assert_eq(ex.size(), 1)
	if not ex.is_empty():
		assert_between(
			int(ex[0]["step"]) - t0,
			fuse_at_freeze - 2,
			fuse_at_freeze + 2,
			"kalan fitil kadar sonra patlar"
		)


func test_p17_bomb_does_not_blast_after_player_death() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(7)
	_mute_guns(sim)
	_plant(sim, Vector2(500, 0))
	SimKit.run(sim, 5)
	sim.hp = 0.0
	sim.step(Vector2.ZERO)
	assert_eq(sim.state, GameSim.State.LOST)
	var blasts := SimKit.count_events(sim, SimEvents.EXPLOSION)
	for i in 120:
		sim.step(Vector2.ZERO)
	assert_eq(SimKit.count_events(sim, SimEvents.EXPLOSION), blasts, "LOST sonrası patlamaz")
	assert_eq(SimKit.count_events(sim, SimEvents.BOMB_EXPLODE), 0)


func test_p17_bomb_does_not_blast_after_lord_kill() -> void:
	if V11Slice.require(self, SLICE):
		return
	var sim := _sim(8)
	_mute_guns(sim)
	_plant(sim, Vector2(500, 0))
	var lord := _foe(sim, &"kale_lordu", Vector2(-900, 0), 10.0)
	sim.damage_enemy(lord, 1.0e9, &"bullet")
	sim.step(Vector2.ZERO)
	assert_eq(sim.state, GameSim.State.WON)
	var blasts := SimKit.count_events(sim, SimEvents.EXPLOSION)
	for i in 120:
		sim.step(Vector2.ZERO)
	assert_eq(SimKit.count_events(sim, SimEvents.EXPLOSION), blasts, "WON sonrası patlamaz")
	assert_eq(SimKit.count_events(sim, SimEvents.BOMB_EXPLODE), 0)
