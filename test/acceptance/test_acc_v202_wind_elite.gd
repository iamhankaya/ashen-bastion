extends GutTest
## Kabul (v2.0.2 K, Z/E): elit ve Lord rüzgarda itilmez/çekilmez ama hasar alır (plan: "Elit/Lord itilmez + hasar") ve Lord HP
## bütçesi (plan U3 kabul 3: Hortum/Tufan dakikada Lord HP'sinin <= %25'i; D'de ayarlanır, eşik planın yazdığı değerdir).

const LORD_BUDGET_PER_MIN := 0.25


func _frozen_lord(sim: GameSim, pos: Vector2) -> int:
	var id := AccV202.dummy(sim, pos, &"kale_lordu")
	var i := EnemyPool.index_of(id)
	sim.enemies.hp[i] = 45000.0
	sim.enemies.max_hp[i] = 45000.0
	return id


func _dot_total(sim: GameSim, id: int) -> float:
	var t := 0.0
	for e in AccV202.damages(sim, &"dot", id):
		t += float(e["amount"])
	return t


func test_z1_elite_and_lord_take_girdap_damage_but_are_not_pushed() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"girdap": 5})
	var elite := AccV202.dummy(sim, Vector2(110, 0), &"elit_piyade")
	var lord := _frozen_lord(sim, Vector2(-130, 0))
	var normal := AccV202.dummy(sim, Vector2(0, 100))
	AccV202.steps(sim, 120)
	assert_gt(AccV202.damages(sim, &"dot", elite).size(), 0, "elit hasar alır")
	assert_gt(AccV202.damages(sim, &"dot", lord).size(), 0, "Lord hasar alır")
	assert_eq(AccV202.pos_of(sim, elite), Vector2(110, 0), "elit itilmez")
	assert_eq(AccV202.pos_of(sim, lord), Vector2(-130, 0), "Lord itilmez")
	assert_gt(
		AccV202.pos_of(sim, normal).distance_to(Vector2(0, 100)),
		10.0,
		"kontrol: sıradan düşman itilir"
	)


func test_z2_elite_and_lord_are_not_pushed_by_the_breath_wave() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"nefes_dalgasi": 5})
	var elite := AccV202.dummy(sim, Vector2(110, 0), &"elit_piyade")
	var lord := _frozen_lord(sim, Vector2(0, 140))
	AccV202.steps(sim, 2)
	AccV202.begin_reload(sim)
	assert_eq(AccV202.damages(sim, &"dot", elite).size(), 1, "elit vuruldu")
	assert_eq(AccV202.damages(sim, &"dot", lord).size(), 1, "Lord vuruldu")
	assert_eq(AccV202.pos_of(sim, elite), Vector2(110, 0), "elit yerinde")
	assert_eq(AccV202.pos_of(sim, lord), Vector2(0, 140), "Lord yerinde")


func test_z3_elite_is_neither_pulled_nor_flung_by_a_twister() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hortum": 1})
	AccV202.dummy(sim, Vector2(400, 0))
	SimKit.run_until(sim, func() -> bool: return sim.zones.count > 0, 700)
	assert_gt(sim.zones.count, 0)
	sim.zones.speed[0] = 0.0
	var elite := AccV202.dummy(sim, sim.zones.pos[0] + Vector2(60, 0), &"elit_piyade")
	var start := AccV202.pos_of(sim, elite)
	var gen := sim.zones.gen[0]
	while sim.zones.index_of_gen(gen) >= 0:
		sim.step(Vector2.ZERO)
	assert_eq(AccV202.pos_of(sim, elite), start, "elit çekilmez/savrulmaz")
	assert_gt(AccV202.damages(sim, &"dot", elite).size(), 3, "elit tikleri alır")


func _lord_run(grants: Dictionary, evo: StringName, seconds: int) -> float:
	var sim := AccV202.zyfen(grants)
	if evo != &"":
		sim.debug_grant(evo)
	var lord := _frozen_lord(sim, Vector2(260, 0))
	for _k in seconds * 60:
		sim.step(Vector2.ZERO)
		sim.enemies.pos[EnemyPool.index_of(lord)] = Vector2(260, 0)  # Lord sürekli kümenin içinde (en kötü durum)
		sim.enemies.hp[EnemyPool.index_of(lord)] = maxf(
			sim.enemies.hp[EnemyPool.index_of(lord)], 1.0
		)
	return _dot_total(sim, lord) * (60.0 / float(seconds))


func test_z4_twister_damage_per_minute_stays_within_the_lord_budget() -> void:
	if V202Slice.require(self, "Z"):
		return
	var per_min := _lord_run({"hortum": 5}, &"", 30)
	assert_lte(
		per_min,
		45000.0 * LORD_BUDGET_PER_MIN,
		"Hortum sv5: dakikada Lord HP'sinin <= yüzde 25'i (ölçülen %.0f)" % per_min
	)


func test_e1_tufan_damage_per_minute_stays_within_the_lord_budget() -> void:
	if V202Slice.require(self, "E"):
		return
	var per_min := _lord_run({}, &"tufan", 30)
	assert_lte(
		per_min,
		45000.0 * LORD_BUDGET_PER_MIN,
		"Tufan: dakikada Lord HP'sinin <= yüzde 25'i (ölçülen %.0f)" % per_min
	)
	assert_gt(per_min, 1000.0, "kontrol: Tufan Lord'a gerçekten vuruyor")
