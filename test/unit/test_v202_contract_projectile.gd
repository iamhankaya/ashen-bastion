extends GutTest
## S1 sözleşmesi: ProjectilePool (rad, HIT_SLOTS 48, remove kopyası, bayraklar), ShotContext, SimFx, WindUtil.

const ENEMY := &"curumus_piyade"


func _quiet_zyfen() -> GameSim:
	var sim := SimKit.make(1, {"data_kind": "quiet", "character": &"zyfen", "pickups": false})
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	return sim


func _still_enemy(sim: GameSim, pos: Vector2) -> int:
	var id := SimKit.add_enemy(sim, ENEMY, pos)
	sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
	return id


func test_constants_and_flags() -> void:
	assert_eq(ProjectilePool.HIT_SLOTS, 96)
	assert_eq(ProjectilePool.DEFAULT_RADIUS, 8.0)
	assert_eq(GameSim.BULLET_RADIUS, ProjectilePool.DEFAULT_RADIUS)
	assert_eq(ProjectilePool.PIERCE_ALL, 99)
	assert_eq(ProjectilePool.FLAG_WIND, 128)
	assert_eq(ProjectilePool.FLAG_SPLIT, 256)
	var seen := {}
	for c in [
		"EXPLODES",
		"EXPLODE_ON_EXPIRE",
		"EXPLODE_ON_BOUNCE",
		"RICOCHET",
		"RADIAL",
		"LOB",
		"SHRAPNEL",
		"WIND",
		"SPLIT"
	]:
		var v: int = ProjectilePool.new().get_script().get_script_constant_map()["FLAG_" + c]
		assert_false(seen.has(v), "bayraklar çakışmaz: %s" % c)
		assert_eq(v & (v - 1), 0, "tek bit: %s" % c)
		seen[v] = true


func test_rad_defaults_and_overrides() -> void:
	var pp := ProjectilePool.new()
	pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0)
	pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0, {"radius": 14.0})
	pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0, {"radius": 0.0, "life": 0.0})
	assert_eq(pp.rad[0], ProjectilePool.DEFAULT_RADIUS)
	assert_eq(pp.rad[1], 14.0)
	assert_eq(pp.rad[2], ProjectilePool.DEFAULT_RADIUS, "0 => varsayılan")
	assert_almost_eq(pp.life[2], ProjectilePool.DEFAULT_LIFE, 0.0001, "ömür 0 => havuz varsayılanı")


func test_remove_copies_rad_and_only_used_hit_slots() -> void:
	var pp := ProjectilePool.new()
	pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0)
	pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0, {"radius": 40.0})
	var n := ProjectilePool.HIT_SLOTS + 12  # halka tampon taşar
	for k in n:
		pp.mark_hit(1, 1000 + k)
	pp.remove(0)
	assert_eq(pp.count, 1)
	assert_eq(pp.rad[0], 40.0)
	assert_eq(pp.hit_n[0], n)
	assert_true(pp.has_hit(0, 1000 + n - 1))
	assert_false(pp.has_hit(0, 1000 + 11), "ezilen en eski kayıt")
	assert_true(pp.has_hit(0, 1000 + 12))


func test_remove_partially_filled_slots() -> void:
	var pp := ProjectilePool.new()
	pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0)
	pp.spawn(Vector2.ZERO, Vector2.ZERO, 1.0)
	pp.mark_hit(1, 7)
	pp.mark_hit(1, 8)
	pp.remove(0)
	assert_true(pp.has_hit(0, 7))
	assert_true(pp.has_hit(0, 8))
	assert_false(pp.has_hit(0, 9))


func test_shot_context_new_fields_default_to_zero() -> void:
	var c := ShotContext.new()
	assert_eq([c.radius, c.speed, c.life], [0.0, 0.0, 0.0])


func test_sim_fx_signals_and_stat_block_field() -> void:
	var sigs := {}
	for s in SimFx.new().get_signal_list():
		sigs[s["name"]] = (s["args"] as Array).map(func(a: Dictionary) -> String: return a["name"])
	assert_eq(sigs.get("wind_wave"), ["origin", "radius", "big"])
	assert_eq(sigs.get("wind_cast"), ["origin"])
	assert_eq(StatBlock.new().wind_time_mult, 1.0)


func test_wind_time_mult_passive_rebuilds() -> void:
	var data := GameData.load_default()
	var l := Loadout.new(data, &"zyfen")
	for i in 5:
		l.add_or_upgrade(&"furtina_gozu")
	var sb := StatBlock.new()
	sb.rebuild(l, data)
	assert_almost_eq(sb.wind_time_mult, 1.5, 0.0001)
	assert_almost_eq(sb.area_mult, 1.6, 0.0001, "alan çarpanı mevcut area_mult")


func test_crescent_fields() -> void:
	var sim := _quiet_zyfen()
	var i := WindUtil.crescent(sim, Vector2(10, 20), Vector2(0, 3), 12.0, 450.0)
	var pr := sim.projectiles
	assert_eq(pr.pos[i], Vector2(10, 20))
	assert_eq(pr.vel[i], Vector2(0, 900))
	assert_eq(pr.rad[i], 14.0)
	assert_eq(pr.pierce[i], ProjectilePool.PIERCE_ALL)
	assert_true(pr.flags[i] & ProjectilePool.FLAG_WIND != 0)
	assert_almost_eq(pr.life[i], 0.5, 0.0001, "range / speed")
	var j := WindUtil.crescent(
		sim,
		Vector2.ZERO,
		Vector2.RIGHT,
		5.0,
		1100.0,
		{"speed": 1300.0, "radius": 40.0, "flags": ProjectilePool.FLAG_SPLIT}
	)
	assert_eq(pr.vel[j], Vector2(1300, 0))
	assert_eq(pr.rad[j], 40.0)
	assert_true(pr.flags[j] & ProjectilePool.FLAG_SPLIT != 0)
	assert_true(pr.flags[j] & ProjectilePool.FLAG_WIND != 0, "FLAG_WIND her zaman eklenir")
	assert_almost_eq(pr.life[j], 1100.0 / 1300.0, 0.0001)


func test_wide_radius_hits_enemy_a_default_bullet_misses() -> void:
	# Yarıçap sorguya girer: 26 + 8 = 34 px'in dışında (y = 40) varsayılan mermi kaçırır, yarıçap 20 yakalar.
	var sim := _quiet_zyfen()
	var id := _still_enemy(sim, Vector2(300, 40))
	var thin := sim.spawn_projectile(Vector2(100, 0), Vector2(900, 0), 1.0, {"life": 1.0})
	assert_gte(thin, 0)
	SimKit.run(sim, 30)
	assert_eq(SimKit.enemy_hp(sim, id), 30.0, "ince mermi kaçırdı")
	WindUtil.crescent(
		sim, Vector2(sim.player_pos.x + 100.0, 0.0), Vector2.RIGHT, 1.0, 600.0, {"radius": 20.0}
	)
	SimKit.run(sim, 30)
	assert_lt(SimKit.enemy_hp(sim, id), 30.0, "geniş mermi vurdu")


func _damage_counts(sim: GameSim) -> Dictionary:
	var counts := {}
	for e in SimKit.events(sim, SimEvents.DAMAGE):
		counts[e["target"]] = int(counts.get(e["target"], 0)) + 1
	return counts


func test_spaced_line_of_60_gets_no_double_damage() -> void:
	var sim := _quiet_zyfen()
	for k in 60:
		_still_enemy(sim, Vector2(160.0 + 30.0 * k, 0.0))
	WindUtil.crescent(sim, Vector2(60, 0), Vector2.RIGHT, 0.5, 2200.0)
	SimKit.run(sim, 130)
	var counts := _damage_counts(sim)
	assert_gt(counts.size(), 55, "çizgideki düşmanların neredeyse hepsine vurdu")
	for id in counts:
		assert_eq(counts[id], 1, "düşman %d tek hasar" % id)


func test_dense_cluster_of_60_double_damage_measurement() -> void:
	# S1 ölçümü (plan: HIT_SLOTS 48 kararı): 60 düşman AYNI anda mermi menzilinde (üst üste yığın). Sıfır olmalı;
	# değilse HIT_SLOTS 96'ya çıkarılır (planın kuralı).
	var sim := _quiet_zyfen()
	for k in 60:
		_still_enemy(sim, Vector2(400.0 + 0.5 * k, 0.0))
	WindUtil.crescent(sim, Vector2(60, 0), Vector2.RIGHT, 0.5, 1200.0)
	SimKit.run(sim, 60)
	var doubled := 0
	for id in _damage_counts(sim):
		if _damage_counts(sim)[id] > 1:
			doubled += 1
	assert_eq(doubled, 0, "aynı düşmana çift hasar alan sayısı")
