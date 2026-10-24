extends GutTest
## U3 W grubu: Hava Bıçakları, Delen Rüzgar, Bölünen Kesik, Ay Orağı, Göğün Mızrağı (+ Öfke Barutu/Kızgın Namlu).

const STEP := GameSim.STEP


func _crescents(sim: GameSim) -> Array[int]:
	var out: Array[int] = []
	for i in sim.projectiles.count:
		out.append(i)
	return out


func _angles(sim: GameSim) -> Array[float]:
	var out: Array[float] = []
	for i in sim.projectiles.count:
		out.append(sim.projectiles.vel[i].angle())
	out.sort()
	return out


# --- Hava Bıçakları --------------------------------------------------------------------------------------


func test_hava_bicaklari_fan_is_symmetric_0_70_rad_with_pierce() -> void:
	var sim := WindKit.make(&"hava_bicaklari", 4)  # 4 kesik, hasar 13, pierce 2
	WindKit.dummy(sim, Vector2(200, 0))
	WindKit.skill_steps(sim, 1)
	assert_eq(sim.projectiles.count, 4)
	var a := _angles(sim)
	assert_almost_eq(a[3] - a[0], 0.70, 0.01, "toplam açı")
	assert_almost_eq(a[0] + a[3], 2.0 * (a[1] + a[2]) / 2.0, 0.01, "simetrik")
	for i in 4:
		assert_eq(sim.projectiles.pierce[i], 2)
		assert_true(sim.projectiles.flags[i] & ProjectilePool.FLAG_WIND != 0)
		assert_almost_eq(sim.projectiles.dmg[i], 13.0, 0.001)
		assert_almost_eq(sim.projectiles.life[i], 380.0 / 900.0, 0.01, "menzil 380")


func test_hava_bicaklari_waits_without_target_then_cooldown_scales_with_fire_rate() -> void:
	var sim := WindKit.make(&"hava_bicaklari", 1)
	WindKit.skill_steps(sim, 10)
	assert_eq(sim.projectiles.count, 0, "hedef yok => atış yok")
	WindKit.dummy(sim, Vector2(200, 0))
	sim.stats.set_buffs(1.0, 2.0)  # Kızgın Namlu: atış hızı x2
	WindKit.skill_steps(sim, 1)
	assert_eq(sim.projectiles.count, 3)
	sim.projectiles.count = 0
	WindKit.skill_steps(sim, int(3.4 / 2.0 / STEP) - 3)
	assert_eq(sim.projectiles.count, 0, "soğuma 3,4 / 2")
	WindKit.skill_steps(sim, 6)
	assert_eq(sim.projectiles.count, 3)


func test_hava_bicaklari_damage_follows_bullet_dmg_mult() -> void:
	var sim := WindKit.make(&"hava_bicaklari", 1)
	sim.stats.set_buffs(1.5, 1.0)  # Öfke Barutu
	WindKit.dummy(sim, Vector2(200, 0))
	WindKit.skill_steps(sim, 1)
	assert_almost_eq(sim.projectiles.dmg[0], 15.0, 0.001)


func test_hava_bicaklari_uses_cast_point_for_armless_zyfen() -> void:
	var sim := WindKit.make(&"hava_bicaklari", 1)
	WindKit.dummy(sim, Vector2(-250, 0))
	WindKit.skill_steps(sim, 1)
	var want := PlayerRig.cast_point_world(sim.player_pos, true, sim.character.rig)
	assert_eq(sim.projectiles.pos[0], want, "hedef solda => aynalı cast noktası")


# --- Delen Rüzgar ----------------------------------------------------------------------------------------


func test_delen_ruzgar_targets_highest_hp_and_pierces_everything() -> void:
	var sim := WindKit.make(&"delen_ruzgar", 1)
	var low := WindKit.dummy(sim, Vector2(200, 0))
	var high := WindKit.dummy(sim, Vector2(0, 300))
	sim.enemies.hp[EnemyPool.index_of(high)] = WindKit.TOUGH_HP * 2.0
	WindKit.skill_steps(sim, 1)
	assert_eq(sim.projectiles.count, 1)
	assert_true(low != high)
	var v := sim.projectiles.vel[0]
	assert_almost_eq(v.length(), 1400.0, 0.5)
	assert_gt(absf(v.y), absf(v.x) * 3.0, "en yüksek can: yukarı/aşağı yön")
	assert_eq(sim.projectiles.pierce[0], ProjectilePool.PIERCE_ALL)
	assert_almost_eq(sim.projectiles.rad[0], 10.0, 0.001)
	assert_almost_eq(sim.projectiles.dmg[0], 80.0, 0.001)
	assert_almost_eq(sim.projectiles.life[0], 850.0 / 1400.0, 0.001)


func test_delen_ruzgar_is_reduced_by_armor_on_hit() -> void:
	var sim := WindKit.make(&"delen_ruzgar", 1)
	var id := WindKit.dummy(sim, Vector2(300, 0), &"elit_piyade")  # zırh 2
	var hp0 := WindKit.hp_of(sim, id)
	WindKit.skill_steps(sim, 1)
	for _k in 30:
		sim._phase_projectiles()
	assert_almost_eq(hp0 - WindKit.hp_of(sim, id), 80.0 - 2.0, 0.001)


func test_pierce_all_crescent_never_double_hits_a_60_enemy_line() -> void:
	var sim := WindKit.make()
	var ids := PackedInt32Array()
	for k in 60:
		ids.append(WindKit.dummy(sim, Vector2(160 + 18 * k, 0)))
	WindUtil.crescent(
		sim, Vector2(60, 0), Vector2.RIGHT, 5.0, 1400.0, {"speed": 1400.0, "radius": 40.0}
	)
	for _k in 90:
		sim._phase_rebuild_hash()
		sim._phase_projectiles()
	for id in ids:
		assert_almost_eq(WindKit.TOUGH_HP - WindKit.hp_of(sim, id), 5.0, 0.001, "tam 1 isabet")


# --- Bölünen Kesik ---------------------------------------------------------------------------------------


func _parent(sim: GameSim, pos: Vector2, dmg: float = 10.0) -> int:
	return sim.spawn_projectile(
		pos,
		Vector2(900, 0),
		dmg,
		{
			"radius": 14.0,
			"pierce": ProjectilePool.PIERCE_ALL,
			"flags": ProjectilePool.FLAG_WIND | ProjectilePool.FLAG_SPLITTER,
			"life": 0.8
		}
	)


func test_bolunen_kesik_marks_every_nth_shot() -> void:
	var sim := WindKit.make(&"bolunen_kesik", 1)  # her 3., x1.0
	var b := WindKit.behavior_of(sim, &"bolunen_kesik")
	for idx in range(1, 7):
		var ctx := ShotContext.new()
		ctx.index_in_mag = idx
		ctx.damage = 10.0
		b.modify_shot(ctx)
		assert_eq(ctx.flags & ProjectilePool.FLAG_SPLITTER != 0, idx % 3 == 0, "kurşun %d" % idx)
	var sim5 := WindKit.make(&"bolunen_kesik", 5)  # her 2., x1.4, 3 çocuk
	var ctx5 := ShotContext.new()
	ctx5.index_in_mag = 2
	ctx5.damage = 10.0
	WindKit.behavior_of(sim5, &"bolunen_kesik").modify_shot(ctx5)
	assert_almost_eq(ctx5.damage, 14.0, 0.001)


func test_bolunen_kesik_parent_ends_at_first_hit_and_spawns_three_children() -> void:
	var sim := WindKit.make(&"bolunen_kesik", 5)
	var a := WindKit.dummy(sim, Vector2(100, 0))
	var b := WindKit.dummy(sim, Vector2(104, 6))  # aynı karede ikinci düşman
	var pi := _parent(sim, Vector2(60, 0), 10.0)
	assert_gte(pi, 0)
	sim._phase_rebuild_hash()
	sim._phase_projectiles()
	assert_eq(sim.projectiles.count, 3, "ebeveyn gitti, yalnız 1 kez bölündü: 3 çocuk")
	var ang := _angles(sim)
	assert_almost_eq(ang[1] - ang[0], 0.5, 0.01)
	assert_almost_eq(ang[2] - ang[1], 0.5, 0.01)
	assert_almost_eq(ang[1], 0.0, 0.01, "ortadaki çocuk ebeveyn yönünde")
	for i in 3:
		assert_almost_eq(sim.projectiles.dmg[i], 6.0, 0.001, "ebeveyn x 0,6")
		assert_eq(sim.projectiles.pierce[i], 3)
		assert_almost_eq(sim.projectiles.rad[i], 14.0, 0.001, "yarıçap miras")
		assert_almost_eq(sim.projectiles.vel[i].length(), 900.0, 0.5, "hız miras")
		var f := sim.projectiles.flags[i]
		assert_true(f & ProjectilePool.FLAG_SPLIT != 0 and f & ProjectilePool.FLAG_SPLITTER == 0)
		assert_true(
			sim.projectiles.has_hit(i, a) or sim.projectiles.has_hit(i, b),
			"vurulan düşmana tekrar vurmaz"
		)
	assert_eq(
		WindKit.TOUGH_HP - WindKit.hp_of(sim, a) + WindKit.TOUGH_HP - WindKit.hp_of(sim, b), 10.0
	)


func test_children_do_not_split_again() -> void:
	var sim := WindKit.make(&"bolunen_kesik", 1)
	WindKit.dummy(sim, Vector2(100, 0))
	WindKit.dummy(sim, Vector2(400, 0))
	_parent(sim, Vector2(60, 0))
	for _k in 40:
		sim._phase_rebuild_hash()
		sim._phase_projectiles()
	assert_lte(sim.projectiles.count, 2, "çocuklar ikinci kez bölünmedi (2 çocuk)")


func test_parent_expiring_without_hit_does_not_split() -> void:
	var sim := WindKit.make(&"bolunen_kesik", 1)
	_parent(sim, Vector2(60, 0))
	for _k in 60:
		sim._phase_rebuild_hash()
		sim._phase_projectiles()
	assert_eq(sim.projectiles.count, 0)


func test_children_never_hit_the_enemy_their_parent_hit() -> void:
	var sim := WindKit.make(&"bolunen_kesik", 1)
	var a := WindKit.dummy(sim, Vector2(100, 0))
	_parent(sim, Vector2(60, 0), 10.0)
	for _k in 30:
		sim._phase_rebuild_hash()
		sim._phase_projectiles()
	assert_almost_eq(WindKit.TOUGH_HP - WindKit.hp_of(sim, a), 10.0, 0.001, "yalnız ebeveyn vurdu")


# --- Ay Orağı --------------------------------------------------------------------------------------------


func test_ay_oragi_makes_every_second_shot_a_giant_unsplittable_crescent() -> void:
	var sim := WindKit.make(&"ay_oragi", 1)
	var b := WindKit.behavior_of(sim, &"ay_oragi")
	var odd := ShotContext.new()
	odd.index_in_mag = 1
	odd.damage = 10.0
	b.modify_shot(odd)
	assert_eq([odd.damage, odd.radius, odd.speed, odd.flags], [10.0, 0.0, 0.0, 0])
	var even := ShotContext.new()
	even.index_in_mag = 2
	even.damage = 10.0
	even.radius = 14.0
	even.pierce = ProjectilePool.PIERCE_ALL
	even.flags = ProjectilePool.FLAG_WIND | ProjectilePool.FLAG_SPLITTER
	b.modify_shot(even)
	assert_almost_eq(even.damage, 35.0, 0.001)
	assert_eq([even.radius, even.speed], [40.0, 1300.0])
	assert_almost_eq(even.life, 1100.0 / 1300.0, 0.0001)
	assert_eq(even.pierce, ProjectilePool.PIERCE_ALL)
	assert_true(even.flags & ProjectilePool.FLAG_WIND != 0)
	assert_true(
		(
			even.flags & ProjectilePool.FLAG_SPLIT != 0
			and even.flags & ProjectilePool.FLAG_SPLITTER == 0
		)
	)


func test_ay_oragi_shot_actually_fired_by_sim_has_giant_stats() -> void:
	var sim := SimKit.make(3, {"character": &"zyfen", "log_events": false})
	SimKit.godmode(sim)
	sim.debug_grant(&"ay_oragi", 1)
	WindKit.dummy(sim, Vector2(300, 0))
	var giants := 0
	for _k in 120:
		sim.step(Vector2.ZERO)
		for i in sim.projectiles.count:
			if sim.projectiles.rad[i] >= 40.0:
				giants += 1
	assert_gt(giants, 0, "sim'in kendi atışlarında dev hilal çıktı")


# --- Göğün Mızrağı ---------------------------------------------------------------------------------------


func test_gogun_mizragi_fires_four_spears_gap_0_12_each_at_current_highest() -> void:
	var sim := WindKit.make(&"gogun_mizragi", 1)
	var a := WindKit.dummy(sim, Vector2(200, 0))
	var b := WindKit.dummy(sim, Vector2(0, 300))
	sim.enemies.hp[EnemyPool.index_of(a)] = WindKit.TOUGH_HP * 3.0
	var fired_at: Array[int] = []
	var dirs: Array[Vector2] = []
	var seen := 0
	for k in 40:
		if k == 4:
			sim.enemies.hp[EnemyPool.index_of(b)] = WindKit.TOUGH_HP * 9.0  # en yüksek değişti
		WindKit.skill_steps(sim, 1)
		if sim.projectiles.count > seen:
			fired_at.append(k)
			dirs.append(sim.projectiles.vel[sim.projectiles.count - 1].normalized())
			seen = sim.projectiles.count
	assert_eq(fired_at.size(), 4, "4 mızrak")
	assert_almost_eq(float(fired_at[1] - fired_at[0]), 7.2, 1.0)
	assert_almost_eq(float(fired_at[3] - fired_at[2]), 7.2, 1.0)
	assert_gt(dirs[0].x, 0.85, "ilk mızrak a'ya")
	assert_gt(absf(dirs[3].y), 0.95, "son mızrak o anki en yüksek b'ye")
	for i in sim.projectiles.count:
		assert_almost_eq(sim.projectiles.dmg[i], 100.0, 0.001)
		assert_eq(sim.projectiles.pierce[i], ProjectilePool.PIERCE_ALL)
