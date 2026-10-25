extends GutTest
## Kabul (v2.0.2 K, Z/E): bölge havuzu CAP 64 ve rezerv 8 (plan Arayüzler/5 + sözleşme: Hava Cebi rezervi dolu ise doğmaz,
## Tufan CAP dolu iken kaybolmaz). Kayıp sessiz değildir: `fx.zone_dropped` sayacı artar.


func _fill(sim: GameSim, kind: int, n: int) -> void:
	for k in n:
		sim.zones.spawn(
			kind, Vector2(6000 + k, 0), {"radius": 10.0, "life": 99.0, "tick_every": 0.4}
		)


func test_z1_pool_constants_and_basic_spawn_rules() -> void:
	if V202Slice.require(self, "Z"):
		return
	assert_eq(ZonePool.CAP, 64)
	assert_eq(ZonePool.RESERVE, 8)
	var sim := AccV202.zyfen()
	_fill(sim, ZonePool.KIND_POCKET, 100)
	assert_eq(sim.zones.count, 56, "cep CAP - RESERVE'e kadar")
	for k in 8:
		assert_gte(
			sim.zones.spawn(ZonePool.KIND_TWISTER, Vector2(7000 + k, 0), {"life": 9.0}),
			0,
			"hortum rezervden doğar (%d)" % k
		)
	assert_eq(sim.zones.count, 64)
	assert_eq(sim.zones.spawn(ZonePool.KIND_GIANT, Vector2.ZERO, {"life": 9.0}), -1, "tam dolu: -1")


func test_z2_twister_still_casts_when_pockets_have_filled_up_to_the_reserve() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hortum": 4})  # 2 hortum
	AccV202.dummy(sim, Vector2(400, 0))
	_fill(sim, ZonePool.KIND_POCKET, 56)
	var dropped := sim.fx.zone_dropped
	SimKit.run_until(sim, func() -> bool: return sim.zones.count > 56, 700)
	assert_eq(sim.zones.count, 58, "2 hortum rezervden doğdu")
	assert_eq(sim.fx.zone_dropped, dropped, "hiçbiri düşmedi")


func test_e1_tufan_does_not_vanish_when_pockets_fill_the_pool_to_the_reserve() -> void:
	if V202Slice.require(self, "E"):
		return
	var sim := AccV202.zyfen()
	sim.debug_grant(&"tufan")
	AccV202.dummy(sim, Vector2(400, 0))
	_fill(sim, ZonePool.KIND_POCKET, 56)
	var dropped := sim.fx.zone_dropped
	SimKit.run_until(sim, func() -> bool: return sim.zones.count > 56, 800)
	assert_eq(sim.zones.count, 59, "3 dev hortum rezervden doğdu")
	var giants := 0
	for i in sim.zones.count:
		giants += 1 if sim.zones.kind[i] == ZonePool.KIND_GIANT else 0
	assert_eq(giants, 3)
	assert_eq(sim.fx.zone_dropped, dropped, "Tufan kaybolmadı")


func test_z3_a_completely_full_pool_counts_the_loss_instead_of_staying_silent() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hortum": 1})
	AccV202.dummy(sim, Vector2(400, 0))
	_fill(sim, ZonePool.KIND_TWISTER, 64)
	assert_eq(sim.zones.count, 64)
	var dropped := sim.fx.zone_dropped
	AccV202.steps(sim, 400)
	assert_gt(sim.fx.zone_dropped, dropped, "kayıp sayaçta görünür")
	assert_lte(sim.zones.count, 64, "CAP aşılmaz")
	assert_eq(sim.check_invariants().size(), 0)


func test_z4_pocket_chain_is_bounded_by_the_pool_even_in_a_dense_crowd() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hava_cebi": 5, "girdap": 5})
	sim.debug_fill(&"curumus_piyade", 280, 70.0)
	var peak := 0
	for _k in 600:
		sim.step(Vector2.ZERO)
		peak = maxi(peak, sim.zones.count)
	assert_lte(peak, ZonePool.CAP, "zincir havuz sınırını aşmaz")
	assert_gt(sim.kills, 20, "kontrol: kalabalık gerçekten öldü")
	assert_eq(sim.check_invariants().size(), 0)
