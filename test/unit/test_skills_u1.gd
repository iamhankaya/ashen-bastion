extends GutTest
## Uygulama-1 becerileri: seken_mermi (her N. kurşun), son_mermi_patlar (yalnız son kurşun), cift_tabanca (seviye değerleri).

var data: GameData


func before_each() -> void:
	data = GameData.load_default()


func _behavior(id: StringName, level: int) -> SkillBehavior:
	var b: SkillBehavior = SkillRegistry.BEHAVIORS[id].new()
	b.setup(GameSim.new(1, &"gunslinger"), data.get_skill(id), level)
	return b


func test_seken_mermi_applies_only_to_every_nth_bullet() -> void:
	var b := _behavior(&"seken_mermi", 1)  # her 3., 2 sekme, hasar x1.0
	for idx in range(1, 7):
		var ctx := ShotContext.new()
		ctx.index_in_mag = idx
		ctx.damage = 10.0
		b.modify_shot(ctx)
		var hit := idx % 3 == 0
		assert_eq(ctx.bounces, 2 if hit else 0, "kurşun %d" % idx)
		assert_eq(bool(ctx.flags & ProjectilePool.FLAG_RICOCHET), hit)


func test_seken_mermi_level_5_every_second_with_damage_bonus() -> void:
	var b := _behavior(&"seken_mermi", 5)
	var ctx := ShotContext.new()
	ctx.index_in_mag = 2
	ctx.damage = 10.0
	b.modify_shot(ctx)
	assert_eq(ctx.bounces, 5)
	assert_almost_eq(ctx.damage, 14.0, 1e-4)


func test_son_mermi_patlar_sets_explosion_on_last_bullet_only() -> void:
	var b := _behavior(&"son_mermi_patlar", 3)
	var ctx := ShotContext.new()
	b.modify_shot(ctx)
	assert_eq(ctx.flags, 0, "modify_shot dokunmaz")
	b.on_last_bullet(ctx)
	assert_true(bool(ctx.flags & ProjectilePool.FLAG_EXPLODES))
	assert_eq(ctx.ex_dmg, 90.0)
	assert_eq(ctx.ex_radius, 130.0)


func test_cift_tabanca_pushes_level_values_to_sim() -> void:
	var sim := GameSim.new(1, &"gunslinger")
	var def := data.get_skill(&"cift_tabanca")
	SkillRegistry.BEHAVIORS[&"cift_tabanca"].new().setup(sim, def, 4)
	assert_eq(sim.gun_damage, 24.0)
	assert_almost_eq(sim.gun_interval, 0.24, 1e-6)


func test_starting_skill_is_installed_from_character_data() -> void:
	var sim := GameSim.new(1, &"gunslinger")
	assert_eq(sim.loadout.level_of(&"cift_tabanca"), 1)
	assert_eq(sim.gun_damage, 15.0)


func test_upgrading_cift_tabanca_changes_fire_interval() -> void:
	var sim := KitDev.sim()
	sim.debug_grant(&"cift_tabanca", 5)
	assert_eq(sim.gun_damage, 28.0)
	assert_almost_eq(sim.gun_interval, 0.22, 1e-6)


func test_zincirleme_patlama_chains_every_second_bullet_with_explosion_per_bounce() -> void:
	var b: SkillBehavior = SkillRegistry.BEHAVIORS[&"zincirleme_patlama"].new()
	b.setup(null, null, 1)
	var odd := ShotContext.new()
	odd.index_in_mag = 1
	b.modify_shot(odd)
	assert_eq(odd.flags, 0)
	var even := ShotContext.new()
	even.index_in_mag = 2
	b.modify_shot(even)
	assert_eq(even.bounces, 8)
	assert_true(bool(even.flags & ProjectilePool.FLAG_RICOCHET))
	assert_true(bool(even.flags & ProjectilePool.FLAG_EXPLODE_ON_BOUNCE))
	assert_eq(even.ex_dmg, 40.0)
	assert_eq(even.ex_radius, 90.0)
