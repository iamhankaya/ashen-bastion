extends GutTest
## Kabul: zorluk eğrisi (zamanla güç ve sayı artışı). Plan "Difficulty" + doğurma çizelgesi.
## Sim düzeyi ölçümler oyuncuyu ölümsüz yapar (godmode) ve gerçek doğurma çizelgesini ("real") kullanır.

const WINDOW_STEPS := 1800  # 30 sn


func test_multipliers_at_5_10_15_20_minutes() -> void:
	for m in ExpectedTables.DIFFICULTY_POINTS.keys():
		var t := float(m) * 60.0
		var want: Array = ExpectedTables.DIFFICULTY_POINTS[m]
		assert_almost_eq(
			Difficulty.enemy_hp_mult(t), float(want[0]), 0.005, "hp çarpanı %d. dk" % m
		)
		assert_almost_eq(
			Difficulty.enemy_dmg_mult(t), float(want[1]), 0.005, "hasar çarpanı %d. dk" % m
		)


func test_alive_cap_fixed_points() -> void:
	for t in ExpectedTables.CAP_POINTS.keys():
		assert_eq(
			Difficulty.alive_cap(float(t)),
			int(ExpectedTables.CAP_POINTS[t]),
			"alive_cap(%d)" % int(t)
		)


func test_start_of_run_multipliers_are_neutral() -> void:
	assert_almost_eq(Difficulty.enemy_hp_mult(0.0), 1.0, 0.0001)
	assert_almost_eq(Difficulty.enemy_dmg_mult(0.0), 1.0, 0.0001)
	assert_almost_eq(Difficulty.enemy_speed_mult(0.0), 1.0, 0.0001)
	assert_eq(Difficulty.alive_cap(0.0), 40)


func test_curves_never_decrease_and_cap_is_bounded() -> void:
	var prev_hp := 0.0
	var prev_dmg := 0.0
	var prev_speed := 0.0
	var prev_cap := 0
	for i in range(0, 41):
		var t := float(i) * 30.0
		var hp := Difficulty.enemy_hp_mult(t)
		var dmg := Difficulty.enemy_dmg_mult(t)
		var sp := Difficulty.enemy_speed_mult(t)
		var cap := Difficulty.alive_cap(t)
		assert_gte(hp, prev_hp, "hp t=%d" % t)
		assert_gte(dmg, prev_dmg, "dmg t=%d" % t)
		assert_gte(sp, prev_speed, "hız t=%d" % t)
		assert_gte(cap, prev_cap, "cap t=%d" % t)
		assert_lte(sp, 1.25 + 0.0001, "hız çarpanı en çok 1,25")
		assert_lte(cap, 400, "cap en çok 400")
		prev_hp = hp
		prev_dmg = dmg
		prev_speed = sp
		prev_cap = cap
	assert_almost_eq(
		Difficulty.enemy_speed_mult(3000.0), 1.25, 0.0001, "hız çarpanı 1,25'te sabitlenir"
	)
	assert_eq(Difficulty.alive_cap(5000.0), 400)


func test_alive_cap_exceeds_300_after_14_5_minutes() -> void:
	assert_gte(Difficulty.alive_cap(900.0), 300, "kalabalık hedefi: 15. dk'da cap >= 300")
	assert_gte(Difficulty.alive_cap(867.0), 300)


func _measure_window(start: float) -> Dictionary:
	var sim := SimKit.make(91, {"data_kind": "real", "start_time": start})
	SimKit.godmode(sim)
	var max_alive := 0
	var over_cap := 0
	for i in WINDOW_STEPS:
		sim.step(Vector2.ZERO)
		max_alive = maxi(max_alive, sim.enemies.count)
		if sim.enemies.count > Difficulty.alive_cap(sim.time):
			over_cap += 1
	var piyade_spawns := 0
	for e in SimKit.events(sim, SimEvents.SPAWN):
		if e["enemy_type"] == &"curumus_piyade":
			piyade_spawns += 1
	return {"spawns": piyade_spawns, "max_alive": max_alive, "over_cap": over_cap}


func test_enemy_count_grows_over_time() -> void:
	var prev_spawns := -1
	var first := 0
	var last := 0
	for start in [60.0, 330.0, 630.0, 930.0, 1140.0]:
		var m := _measure_window(start)
		assert_gt(
			int(m["spawns"]),
			prev_spawns,
			"t=%d: 30 sn'deki piyade doğuşu önceki pencereden fazla olmalı" % start
		)
		assert_eq(int(m["over_cap"]), 0, "t=%d: canlı düşman alive_cap(t) üstüne çıkmamalı" % start)
		if prev_spawns < 0:
			first = int(m["spawns"])
		last = int(m["spawns"])
		prev_spawns = int(m["spawns"])
	assert_gt(
		last,
		first * 2,
		"20. dk'ya doğru doğuş oranı en az 2 katına çıkmalı (%d -> %d)" % [first, last]
	)


func test_alive_enemies_grow_over_time() -> void:
	var early := _measure_window(60.0)
	var late := _measure_window(1140.0)
	assert_gt(
		int(late["max_alive"]), int(early["max_alive"]), "ekrandaki düşman sayısı zamanla artar"
	)


func test_spawned_enemy_hp_scales_with_difficulty() -> void:
	for start in [0.0, 300.0, 900.0]:
		var sim := SimKit.make(92, {"data_kind": "real", "start_time": start})
		SimKit.godmode(sim)
		var def := sim.data.get_enemy(&"curumus_piyade")
		assert_not_null(def)
		if def == null:
			return
		var checked := 0
		for i in 600:
			sim.step(Vector2.ZERO)
			if checked >= 3:
				break
			for e in SimKit.events(sim, SimEvents.SPAWN):
				if int(e["step"]) == sim.step_count and e["enemy_type"] == &"curumus_piyade":
					var hp := SimKit.enemy_hp(sim, int(e["id"]))
					if hp > 0.0:
						checked += 1
						var want := def.hp * Difficulty.enemy_hp_mult(sim.time)
						assert_almost_eq(
							hp, want, want * 0.03, "t=%d: doğan piyade hp = taban x çarpan" % start
						)
		assert_gt(checked, 0, "t=%d: en az bir piyade doğmalı" % start)


func test_spawn_rate_matches_wave_table_roughly() -> void:
	# rate satırı 0,8 -> 3,5 /sn doğrusal: 0-30 sn ortalama ~0,85/sn => ~25 doğuş; geniş pay (rastgele Poisson/biriktirici).
	var sim := SimKit.make(93, {"data_kind": "real"})
	SimKit.godmode(sim)
	SimKit.run(sim, 1800)
	var n := 0
	for e in SimKit.events(sim, SimEvents.SPAWN):
		if e["enemy_type"] == &"curumus_piyade":
			n += 1
	assert_between(n, 15, 40, "0-30 sn piyade doğuşu ~25")
	var sim2 := SimKit.make(94, {"data_kind": "real", "start_time": 1100.0})
	SimKit.godmode(sim2)
	SimKit.run(sim2, 1800)
	var n2 := 0
	for e in SimKit.events(sim2, SimEvents.SPAWN):
		if e["enemy_type"] == &"curumus_piyade":
			n2 += 1
	assert_between(n2, 70, 130, "1100-1130 sn piyade doğuşu ~ 3,4/sn x 30 = ~100")
