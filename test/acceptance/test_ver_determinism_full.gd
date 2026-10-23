extends GutTest
## Doğrulama (T20261023-64): determinizm. Aynı tohum → aynı `state_hash` (boss/elit AI durumu ve doğuş ilerlemesi
## hash'te), harita düzeni tohuma bağlı ve sürüm-bağımsız karıştırma.


## Aynı sim'i iki kopya olarak aynı girdiyle sürer; her `every` adımda hash'leri karşılaştırır.
func _lockstep(opts: Dictionary, seed_value: int, steps: int, every: int) -> Dictionary:
	var a := SimKit.make(seed_value, opts)
	var b := SimKit.make(seed_value, opts)
	SimKit.godmode(a)
	SimKit.godmode(b)
	var n := 0
	var mismatches := 0
	var checks := 0
	while n < steps and a.state in [GameSim.State.RUNNING, GameSim.State.LEVEL_UP]:
		SimKit.godmode(a)
		SimKit.godmode(b)
		if a.state == GameSim.State.LEVEL_UP:
			a.choose(0)
			b.choose(0)
			continue
		var mv := Bots.move(&"kite", a)
		a.step(mv)
		b.step(mv)
		n += 1
		if n % every == 0:
			checks += 1
			if a.state_hash() != b.state_hash():
				mismatches += 1
	return {"a": a, "b": b, "mismatches": mismatches, "checks": checks, "steps": n}


func test_same_seed_same_hash_through_elite_boss_fights() -> void:
	# t=290..: elit_piyade (300) + uyarı; AI zamanlayıcıları ve doğuş ilerlemesi hash'te
	var r := _lockstep({"data_kind": "real", "start_time": 290.0}, 401, 60 * 40, 30)
	assert_gt(r["checks"], 60)
	assert_eq(r["mismatches"], 0, "elit doğuşu boyunca iki kopya aynı hash'te kalır")
	var a: GameSim = r["a"]
	assert_gte(a.time, 325.0, "40 sn oynandı")
	assert_true(a.enemies.count > 0)


func test_same_seed_same_hash_through_lord_spawn_summon_and_enrage() -> void:
	var r := _lockstep({"data_kind": "real", "start_time": 1190.0}, 402, 60 * 45, 30)
	assert_eq(r["mismatches"], 0, "Lord doğuşu/çağırma sırasında hash'ler eşit")
	var a: GameSim = r["a"]
	var lord_seen := false
	for id in a.alive_ids():
		if a.enemies.type_id_of(EnemyPool.index_of(id)) == &"kale_lordu":
			lord_seen = true
	assert_true(lord_seen, "Lord sahnede (hash onu kapsıyor)")


func test_hash_covers_lord_ai_state() -> void:
	var a := SimKit.make(403, {"data_kind": "real", "start_time": 1196.0})
	var b := SimKit.make(403, {"data_kind": "real", "start_time": 1196.0})
	SimKit.godmode(a)
	SimKit.godmode(b)
	SimKit.run(a, 60 * 6)
	SimKit.run(b, 60 * 6)
	assert_eq(a.state_hash(), b.state_hash())
	var lord_id := -1
	for id in a.alive_ids():
		if a.enemies.type_id_of(EnemyPool.index_of(id)) == &"kale_lordu":
			lord_id = id
	assert_gte(lord_id, 0)
	var i := EnemyPool.index_of(lord_id)
	b.enemies.ai_aux[i] = 1.0  # öfke bayrağı
	assert_ne(a.state_hash(), b.state_hash(), "Lord öfke durumu hash'e girer")
	b.enemies.ai_aux[i] = a.enemies.ai_aux[i]
	assert_eq(a.state_hash(), b.state_hash())
	b.enemies.ai_timer[i] += 0.5
	assert_ne(a.state_hash(), b.state_hash(), "Lord çağırma zamanlayıcısı hash'e girer")


func test_different_seeds_give_different_runs_and_start_time_is_part_of_the_run() -> void:
	var a := SimKit.make(404, {"data_kind": "real"})
	var b := SimKit.make(405, {"data_kind": "real"})
	var c := SimKit.make(404, {"data_kind": "real", "start_time": 60.0})
	for s in [a, b, c]:
		SimKit.godmode(s)
		SimKit.run(s, 600)
	assert_ne(a.state_hash(), b.state_hash(), "farklı tohum farklı oyun")
	assert_ne(a.state_hash(), c.state_hash(), "farklı başlangıç zamanı farklı oyun")


func test_map_layout_is_deterministic_and_seed_dependent() -> void:
	var data := SimKit.data_for("real")
	var s1 := MapSim.new(11, data.ruins)
	var s2 := MapSim.new(11, data.ruins)
	var s3 := MapSim.new(12, data.ruins)
	for m in [s1, s2, s3]:
		m.ensure(Vector2(5000, -3000))
		m.ensure(Vector2.ZERO)
	assert_eq(s1.count, s2.count)
	assert_gt(s1.count, 20, "harita dolu")
	assert_eq(s1.ob_pos, s2.ob_pos, "aynı tohum aynı harabe konumları")
	assert_eq(s1.ob_ruin, s2.ob_ruin)
	assert_ne(s1.ob_pos, s3.ob_pos, "farklı tohum farklı harita")


func test_map_layout_does_not_depend_on_generation_order() -> void:
	var data := SimKit.data_for("real")
	var fwd := MapSim.new(21, data.ruins)
	var back := MapSim.new(21, data.ruins)
	fwd.ensure(Vector2.ZERO)
	fwd.ensure(Vector2(4096, 0))
	back.ensure(Vector2(4096, 0))
	back.ensure(Vector2.ZERO)
	var ca := Vector2i(1, 0)
	var pa := PackedVector2Array()
	for i in fwd.chunk_obstacles(ca):
		pa.append(fwd.ob_pos[i])
	var pb := PackedVector2Array()
	for i in back.chunk_obstacles(ca):
		pb.append(back.ob_pos[i])
	assert_gt(pa.size(), 0)
	assert_eq(pa, pb, "chunk içeriği üretim sırasından bağımsız")


func test_map_mix_function_is_pinned_integer_arithmetic() -> void:
	# Elle yazılmış tamsayı karıştırma: Variant hash'e bağlı değil; değerler sürümler arası sabit olmalı.
	assert_eq(MapSim._mix(1, 0, 0), 2558316640067307269)
	assert_eq(MapSim._mix(1, 3, -2), 3612907411951505402)
	assert_eq(MapSim._mix(123456789, -5, 7), 1931917913334126648)
	assert_eq(MapSim._mix(-1, 0, 0), 6514504133438201533)


func test_stream_seeds_do_not_depend_on_variant_hash() -> void:
	# F-ver-001: GameSim._stream_seed Variant hash([tohum, ad]) kullanıyor; harita tohumu (ve 3 RNG akışı) buna bağlı.
	# Variant hash motor sürümüne/platforma bağlıdır: "sürüm-bağımsız harita tohumu" iddiası boşa çıkar.
	var sim := SimKit.make(1)
	for stream in [&"map", &"spawn", &"choice", &"combat"]:
		assert_ne(
			sim._stream_seed(stream),
			hash([1, String(stream)]),
			"akış '%s' tohumu Variant hash'ten türemiş" % stream
		)
