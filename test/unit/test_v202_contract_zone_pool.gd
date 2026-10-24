extends GutTest
## S1 sözleşmesi: ZonePool (spawn/remove/rezerv/gen/hash), WindSystem iskeleti.


func test_constants() -> void:
	assert_eq(ZonePool.CAP, 64)
	assert_eq(ZonePool.RESERVE, 8)
	assert_eq([ZonePool.KIND_TWISTER, ZonePool.KIND_POCKET, ZonePool.KIND_GIANT], [1, 2, 3])


func test_empty_pool_hash_items_is_empty() -> void:
	assert_eq(ZonePool.new().hash_items().size(), 0)


func test_spawn_fields_and_gen_ids_increase() -> void:
	var z := ZonePool.new()
	var a := z.spawn(
		ZonePool.KIND_TWISTER,
		Vector2(3, 4),
		{"radius": 150.0, "life": 3.0, "tick_every": 0.4, "dmg": 8.0}
	)
	var b := z.spawn(ZonePool.KIND_GIANT, Vector2(9, 9))
	assert_eq([a, b], [0, 1])
	assert_eq(z.count, 2)
	assert_eq(z.pos[0], Vector2(3, 4))
	assert_eq(z.radius[0], 150.0)
	assert_almost_eq(z.tick_left[0], 0.4, 0.0001, "ilk tik tick_every sonra")
	assert_gt(z.gen[1], z.gen[0])
	assert_eq(z.index_of_gen(z.gen[1]), 1)
	assert_eq(z.index_of_gen(9999), -1)


func test_remove_swaps_last_and_gen_resolves_to_new_index() -> void:
	var z := ZonePool.new()
	for k in 3:
		z.spawn(ZonePool.KIND_TWISTER, Vector2(float(k), 0.0), {"life": float(k + 1)})
	var last_gen := z.gen[2]
	z.remove(0)
	assert_eq(z.count, 2)
	assert_eq(z.pos[0], Vector2(2, 0), "son bölge 0'a taşındı")
	assert_eq(z.index_of_gen(last_gen), 0)
	z.remove(5)
	z.remove(-1)
	assert_eq(z.count, 2, "geçersiz indeks yok sayılır")


func test_cap_and_pocket_reserve() -> void:
	var z := ZonePool.new()
	for k in ZonePool.CAP - ZonePool.RESERVE:
		assert_gte(z.spawn(ZonePool.KIND_POCKET, Vector2.ZERO), 0)
	assert_eq(z.spawn(ZonePool.KIND_POCKET, Vector2.ZERO), -1, "cep rezerve girmez")
	for k in ZonePool.RESERVE:
		assert_gte(z.spawn(ZonePool.KIND_GIANT, Vector2.ZERO), 0, "Tufan/Hortum rezervi kullanır")
	assert_eq(z.count, ZonePool.CAP)
	assert_eq(z.spawn(ZonePool.KIND_TWISTER, Vector2.ZERO), -1, "tam dolu")


func test_hash_items_layout_and_quantisation() -> void:
	var z := ZonePool.new()
	z.spawn(
		ZonePool.KIND_POCKET, Vector2(1.5, -2.25), {"radius": 70.0, "life": 1.2, "tick_every": 0.4}
	)
	var h := z.hash_items()
	assert_eq(h.size(), 7)
	assert_eq(h[0], z.gen[0])
	assert_eq(h[1], ZonePool.KIND_POCKET)
	assert_eq(h[2], roundi(1.5 * GameSim.HASH_QUANT))
	assert_eq(h[3], roundi(-2.25 * GameSim.HASH_QUANT))
	assert_eq(h[5], roundi(70.0 * GameSim.HASH_QUANT))


func test_spawn_zone_counts_dropped_zones_on_the_sim() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "character": &"zyfen"})
	for k in ZonePool.CAP - ZonePool.RESERVE:
		WindSystem.spawn_zone(sim, ZonePool.KIND_POCKET, Vector2.ZERO, {"life": 5.0})
	assert_eq(sim.fx.zone_dropped, 0)
	assert_eq(WindSystem.spawn_zone(sim, ZonePool.KIND_POCKET, Vector2.ZERO), -1)
	assert_eq(sim.fx.zone_dropped, 1, "kayıp sessiz değil")


func test_no_zones_leaves_state_hash_and_step_unchanged() -> void:
	var a := SimKit.make(3, {"data_kind": "real"})
	var b := SimKit.make(3, {"data_kind": "real"})
	assert_eq(a.zones.count, 0)
	SimKit.run(a, 120)
	SimKit.run(b, 120)
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.zones.hash_items().size(), 0)


func test_wind_system_skeleton_expires_zones() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "character": &"zyfen"})
	WindSystem.spawn_zone(sim, ZonePool.KIND_TWISTER, Vector2(500, 500), {"life": 0.1})
	assert_eq(sim.zones.count, 1)
	SimKit.run(sim, 10)
	assert_eq(sim.zones.count, 0)
	assert_false(sim.wind.in_pocket_tick)
