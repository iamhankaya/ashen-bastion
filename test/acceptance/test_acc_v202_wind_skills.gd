extends GutTest
## Kabul (v2.0.2 K, W/Z/E): davranış sözleşmesi tablosu satır satır (docs/design/v2.0.2/behavior-contract.md = plan Arayüzler/7).
## Sayılar JSON'dan değil plan tablosundan (ExpectedTablesV202 / sözleşme metni) gelir. Dilim: W = temel rüzgar (Hava Bıçakları,
## Delen Rüzgar, Bölünen Kesik), Z = bölgeler (Girdap, Hortum, Hava Cebi, Nefes Dalgası, Fırtına Gözü), E = evrimler (Ay Orağı,
## Kasırga Patlaması, Göğün Mızrağı, Tufan). Rüzgar Kesiği satırı test_acc_v202_rig_pierce.gd'dedir (R).
## Düşmanlar dondurulur (hız 0, hp çok yüksek) ve tabanca çoğu testte susturulur: yalnız sınanan beceri etkindir.

const STEP := GameSim.STEP
const ORIGIN_Y_PROBE := Vector2.ZERO


## Atış ekseni: kesikler cast noktasından çıktığı için hizalı düşman çizgisi cast noktasının y'sindedir.
func _cast_y() -> float:
	var p := AccV202.zyfen()
	return PlayerRig.cast_point_world(p.player_pos, false, p.character.rig).y


func _spears(sim: GameSim) -> Array[int]:
	var out: Array[int] = []
	for i in sim.projectiles.count:
		if sim.projectiles.rad[i] == 10.0 and sim.projectiles.life[i] > 0.58:
			out.append(i)
	return out


# --- Hava Bıçakları (W) ----------------------------------------------------------------------------------


func test_w1_hava_bicaklari_fan_count_spread_symmetry_and_pierce() -> void:
	if V202Slice.require(self, "W"):
		return
	var table := ExpectedTablesV202.SKILLS["hava_bicaklari"]["levels"] as Array
	for lv in [1, 3, 4, 5]:
		var want: Dictionary = table[lv - 1]
		var sim := AccV202.zyfen({"hava_bicaklari": lv})
		for k in 6:
			AccV202.dummy(sim, Vector2(220.0, -40.0 + 16.0 * k))
		assert_true(
			SimKit.run_until(sim, func() -> bool: return sim.projectiles.count > 0, 40),
			"sv%d: kesikler doğdu" % lv
		)
		var n := sim.projectiles.count
		assert_eq(n, int(want["pellets"]), "sv%d kesik sayısı" % lv)
		var a: Array[float] = []
		for i in n:
			a.append(sim.projectiles.vel[i].angle())
			assert_eq(sim.projectiles.pierce[i], int(want["pierce"]), "sv%d pierce" % lv)
			assert_almost_eq(sim.projectiles.dmg[i], float(want["damage"]), 0.01, "sv%d hasar" % lv)
		a.sort()
		assert_almost_eq(a[n - 1] - a[0], 0.70, 0.01, "sv%d toplam açı 0,70 rad" % lv)
		for i in n:
			assert_almost_eq(
				a[i] + a[n - 1 - i], a[0] + a[n - 1], 0.01, "sv%d simetri %d" % [lv, i]
			)


func test_w2_hava_bicaklari_blade_stops_after_pierce_plus_one_hits() -> void:
	if V202Slice.require(self, "W"):
		return
	var sim := AccV202.zyfen({"hava_bicaklari": 1})  # 3 kesik, pierce 1
	var y := _cast_y()
	var ids: Array[int] = []
	for k in 5:
		ids.append(AccV202.dummy(sim, Vector2(260.0 + 55.0 * k, y)))
	AccV202.steps(sim, 90)
	var hits := 0
	for id in ids:
		hits += AccV202.damages(sim, &"bullet", id).size()
	assert_eq(hits, 2, "ortadaki kesik pierce(1)+1 = 2 düşmanı vurup biter; yan kesikler ıskalar")


func test_w3_hava_bicaklari_waits_for_a_target_inside_range_380() -> void:
	if V202Slice.require(self, "W"):
		return
	var sim := AccV202.zyfen({"hava_bicaklari": 1})
	AccV202.dummy(sim, Vector2(500, 0))  # menzil dışı
	AccV202.steps(sim, 20)
	assert_eq(sim.projectiles.count, 0, "menzil dışında atış yok")


# --- Delen Rüzgar (W) ------------------------------------------------------------------------------------


func test_w4_delen_ruzgar_picks_highest_hp_and_pierces_everything_with_armor() -> void:
	if V202Slice.require(self, "W"):
		return
	var sim := AccV202.zyfen({"delen_ruzgar": 1})
	var low := AccV202.dummy(sim, Vector2(300, 0), &"elit_piyade")  # zırh 2
	var high := AccV202.dummy(sim, Vector2(0, 400), &"elit_piyade")
	sim.enemies.hp[EnemyPool.index_of(high)] = AccV202.TOUGH_HP * 2.0
	assert_true(
		SimKit.run_until(sim, func() -> bool: return sim.projectiles.count > 0, 40), "mızrak doğdu"
	)
	var i := 0
	var v := sim.projectiles.vel[i]
	assert_almost_eq(v.length(), 1400.0, 1.0, "hız 1400")
	assert_gt(absf(v.y), absf(v.x) * 3.0, "en yüksek can: yukarı/aşağı yön")
	assert_eq(sim.projectiles.pierce[i], ProjectilePool.PIERCE_ALL, "PIERCE_ALL")
	assert_almost_eq(sim.projectiles.rad[i], 10.0, 0.001, "yarıçap 10")
	AccV202.steps(sim, 60)
	var hit_high := AccV202.damages(sim, &"bullet", high)
	assert_eq(hit_high.size(), 1, "en yüksek canlıya tek isabet")
	assert_almost_eq(float(hit_high[0]["amount"]), 80.0 - 2.0, 0.8, "zırh uygulanır (80 - 2)")
	assert_eq(AccV202.damages(sim, &"bullet", low).size(), 0, "düşük canlıya vurmaz")


func test_w5_delen_ruzgar_reach_is_850() -> void:
	if V202Slice.require(self, "W"):
		return
	var sim := AccV202.zyfen({"delen_ruzgar": 1})
	AccV202.dummy(sim, Vector2(950, 0))
	AccV202.steps(sim, 20)
	assert_eq(sim.projectiles.count, 0, "850 px dışındaki hedefe atış yok")


# --- Bölünen Kesik (W) -----------------------------------------------------------------------------------


## Yalnız tabanca 0 etkin (şarjör sırası: 1., 2., 3. kesik ... tek elden); düşman çizgisi cast ekseninde.
func _split_sim(level: int) -> GameSim:
	var sim := AccV202.zyfen({"bolunen_kesik": level}, false)
	sim.gun_cd = PackedFloat32Array([0.0, 1.0e9])
	return sim


func _split_children(sim: GameSim) -> Array[int]:
	var out: Array[int] = []
	for i in sim.projectiles.count:
		if sim.projectiles.flags[i] & ProjectilePool.FLAG_SPLIT:
			out.append(i)
	return out


func test_w6_bolunen_kesik_children_angles_damage_pierce_and_no_victim_rehit() -> void:
	if V202Slice.require(self, "W"):
		return
	var sim := _split_sim(5)  # every_n 2, count 3, damage_mult 1.4
	var y := _cast_y()
	var a := AccV202.dummy(sim, Vector2(300, y))
	var b := AccV202.dummy(sim, Vector2(520, y))
	var split_step := -1
	var max_children := 0
	for n in 200:
		sim.step(Vector2.ZERO)
		var ch := _split_children(sim)
		max_children = maxi(max_children, ch.size())
		if split_step < 0 and not ch.is_empty():
			split_step = sim.step_count
			sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
			assert_eq(ch.size(), 3, "count 3 çocuk")
			var ang: Array[float] = []
			for i in ch:
				ang.append(sim.projectiles.vel[i].angle())
				assert_eq(sim.projectiles.pierce[i], 3, "çocuk pierce 3")
				assert_almost_eq(sim.projectiles.rad[i], 14.0, 0.001, "yarıçap mirası")
				assert_almost_eq(sim.projectiles.vel[i].length(), 900.0, 0.5, "hız mirası")
			ang.sort()
			assert_almost_eq(ang[0], -0.5, 0.01, "sol çocuk -0,5 rad")
			assert_almost_eq(ang[1], 0.0, 0.01, "orta çocuk 0 rad")
			assert_almost_eq(ang[2], 0.5, 0.01, "sağ çocuk +0,5 rad")
		if split_step > 0 and sim.step_count > split_step + 70:
			break
	assert_gt(split_step, 0, "ebeveyn bölündü")
	assert_lte(max_children, 3, "çocuk bölünmez: aynı anda en çok count çocuk")
	# ebeveyn hasarı = ilk isabet eden mermi (bölünme adımındaki A hasarı); çocuk = x 0,6
	var parent_hits: Array = []
	for e in AccV202.damages(sim, &"bullet", a):
		if absf(float(e["amount"]) - 12.0) > 0.5:
			parent_hits.append(e)
	assert_eq(parent_hits.size(), 1, "A'ya yalnız ebeveyn (hasar x 1,4) vurdu")
	var parent_dmg := float(parent_hits[0]["amount"])
	assert_almost_eq(parent_dmg, 12.0 * 1.4, 0.2, "ebeveyn hasarı 12 x damage_mult 1,4")
	var child_hits_a := 0
	var child_hits_b := 0
	for e in AccV202.damages(sim, &"bullet", a, split_step):
		child_hits_a += 1 if absf(float(e["amount"]) - parent_dmg * 0.6) < 0.2 else 0
	for e in AccV202.damages(sim, &"bullet", b, split_step):
		child_hits_b += 1 if absf(float(e["amount"]) - parent_dmg * 0.6) < 0.2 else 0
	assert_eq(child_hits_a, 0, "çocuk ebeveynin vurduğu düşmana vurmaz")
	assert_eq(child_hits_b, 1, "orta çocuk arkadaki düşmana tek kez vurur (hasar ebeveyn x 0,6)")


func test_w7_bolunen_kesik_parent_hitting_two_enemies_in_one_frame_splits_once() -> void:
	if V202Slice.require(self, "W"):
		return
	var sim := _split_sim(1)  # every_n 3, count 2
	var y := _cast_y()
	AccV202.dummy(sim, Vector2(300, y))
	AccV202.dummy(sim, Vector2(300, y + 18.0))
	var seen := 0
	var splits := 0
	for n in 260:
		sim.step(Vector2.ZERO)
		var c := _split_children(sim).size()
		if c > 0 and seen == 0:
			sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
			splits = c
		seen = maxi(seen, c)
	assert_gt(splits, 0, "bölünme oldu")
	assert_eq(splits, 2, "iki düşmana aynı karede çarpan ebeveyn yalnız 1 kez bölünür (count 2)")
	assert_lte(seen, 2, "çocuk sayısı hiçbir zaman count'u aşmaz")


func test_w8_bolunen_kesik_parent_expiring_without_a_hit_does_not_split() -> void:
	if V202Slice.require(self, "W"):
		return
	for control in [true, false]:
		var sim := _split_sim(1)  # her 3. kesik ebeveyn
		var y := _cast_y()
		var id := AccV202.dummy(sim, Vector2(700, y))
		var moved := false
		var children := 0
		for n in 220:
			sim.step(Vector2.ZERO)
			if not control and not moved and SimKit.count_events(sim, SimEvents.SHOT) >= 3:
				sim.enemies.pos[EnemyPool.index_of(id)] = Vector2(0, 1800)  # 3. kesik hedefsiz uçup söner
				moved = true
			children = maxi(children, _split_children(sim).size())
		if control:
			assert_gt(children, 0, "kontrol: hedef yerinde kalırsa 3. kesik bölünür")
		else:
			assert_true(moved)
			assert_eq(children, 0, "menzil sonunda bölünme yok")


# --- Girdap (Z) ------------------------------------------------------------------------------------------


func test_z1_girdap_pulses_once_per_interval_hits_elite_but_does_not_move_it() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"girdap": 1})
	var elite := AccV202.dummy(sim, Vector2(100, 0), &"elit_piyade")
	AccV202.steps(sim, 180)
	var ev := AccV202.damages(sim, &"dot", elite)
	assert_between(ev.size(), 5, 7, "180 adımda (3 sn) 6 darbe +-1 (interval 0,5)")
	for e in ev:
		assert_almost_eq(float(e["amount"]), 6.0, 0.01, "darbe hasarı 6")
	assert_eq(AccV202.pos_of(sim, elite), Vector2(100, 0), "elit itilmez")
	# darbe aralığı 30 adım +-1
	for k in range(1, ev.size()):
		assert_between(int(ev[k]["step"]) - int(ev[k - 1]["step"]), 29, 31, "darbe aralığı")


func test_z2_girdap_pushes_a_normal_enemy_outward_by_push_px_per_pulse() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"girdap": 1})
	var id := AccV202.dummy(sim, Vector2(100, 0))
	AccV202.steps(sim, 45)  # tek darbe (0,5 sn)
	var ev := AccV202.damages(sim, &"dot", id)
	assert_eq(ev.size(), 1, "tek darbe")
	assert_almost_eq(AccV202.pos_of(sim, id).x, 114.0, 1.0, "dışa 14 px")
	assert_almost_eq(AccV202.pos_of(sim, id).y, 0.0, 0.5, "yön dışa (radyal)")


func test_z3_girdap_radius_follows_area_mult_every_step() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"girdap": 1})
	var id := AccV202.dummy(sim, Vector2(150, 0), &"elit_piyade")  # elit: yerinde kalır; yarıçap 90 + 60 = 150 sınır
	AccV202.dummy(sim, Vector2(0, 2000))  # sim kapanmasın
	AccV202.steps(sim, 70)
	var before := AccV202.damages(sim, &"dot", id).size()
	sim.enemies.pos[EnemyPool.index_of(id)] = Vector2(185, 0)  # taban yarıçap 90 + 60 = 150 < 185: dışarıda
	AccV202.steps(sim, 70)
	assert_eq(AccV202.damages(sim, &"dot", id).size(), before, "yarıçap dışında darbe yok")
	sim.debug_grant(&"furtina_gozu", 5)  # x1,60 => 144 + 60 = 204 >= 185
	AccV202.steps(sim, 70)
	assert_gt(AccV202.damages(sim, &"dot", id).size(), before, "Fırtına Gözü anında etki eder")


# --- Hortum (Z) ------------------------------------------------------------------------------------------


func _first_zone(sim: GameSim, max_steps: int = 700) -> int:
	SimKit.run_until(sim, func() -> bool: return sim.zones.count > 0, max_steps)
	return sim.zones.count - 1 if sim.zones.count > 0 else -1


func test_z4_hortum_spawns_count_zones_with_life_tick_and_spawn_distance() -> void:
	if V202Slice.require(self, "Z"):
		return
	for pair in [[1, 1], [4, 2]]:
		var sim := AccV202.zyfen({"hortum": pair[0]})
		AccV202.dummy(sim, Vector2(400, 0))
		_first_zone(sim)
		assert_eq(sim.zones.count, pair[1], "sv%d: %d hortum" % [pair[0], pair[1]])
		var want: Dictionary = ExpectedTablesV202.SKILLS["hortum"]["levels"][pair[0] - 1]
		for i in sim.zones.count:
			assert_eq(sim.zones.kind[i], ZonePool.KIND_TWISTER, "tür")
			assert_almost_eq(sim.zones.life[i], float(want["life"]), 0.05, "ömür")
			assert_almost_eq(sim.zones.radius[i], float(want["radius"]), 0.5, "yarıçap")
			assert_almost_eq(sim.zones.tick_every[i], 0.4, STEP + 0.001, "tik 0,4 sn")
			assert_almost_eq(
				sim.zones.pos[i].distance_to(sim.player_pos),
				250.0,
				60.0,
				"oyuncudan ~250 px doğar (ilk adım hareketi dahil)"
			)


func test_z5_hortum_pulls_to_center_ticks_every_0_4s_and_does_not_fling_at_the_end_with_double_tick(
) -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hortum": 1})
	AccV202.dummy(sim, Vector2(400, 0))
	var zi := _first_zone(sim)
	assert_gte(zi, 0, "hortum doğdu")
	sim.zones.speed[zi] = 0.0  # merkez sabit: çekme ölçülebilir
	var gen := sim.zones.gen[zi]
	var c := sim.zones.pos[zi]
	var id := AccV202.dummy(sim, c + Vector2(100, 0))
	var d0 := AccV202.pos_of(sim, id).distance_to(c)
	AccV202.steps(sim, 12)  # 0,2 sn, ilk tikten önce
	var d1 := AccV202.pos_of(sim, id).distance_to(c)
	assert_almost_eq(d0 - d1, 70.0 * 0.2, 3.0, "çekme: merkeze pull px/sn (sv1: 70)")
	var from := sim.step_count
	var last_pos := AccV202.pos_of(sim, id)
	var prev_move := 0.0
	var last_move := 0.0
	while sim.zones.index_of_gen(gen) >= 0 and sim.step_count < from + 400:
		last_pos = AccV202.pos_of(sim, id)
		sim.step(Vector2.ZERO)
		prev_move = last_move
		last_move = AccV202.pos_of(sim, id).distance_to(last_pos)
	var ev := AccV202.damages(sim, &"dot", id)
	assert_gte(ev.size(), 5, "tikler")
	assert_almost_eq(float(ev[ev.size() - 1]["amount"]), 16.0, 0.01, "son darbe 2 x tik (2 x 8)")
	for k in range(0, ev.size() - 1):
		assert_almost_eq(float(ev[k]["amount"]), 8.0, 0.01, "tik hasarı 8")
	for k in range(1, ev.size() - 1):
		assert_between(
			int(ev[k]["step"]) - int(ev[k - 1]["step"]), 23, 25, "tik aralığı 0,4 sn = 24 adım"
		)
	# T20261025-68: bitişte savurma YOK. Kukla hareketsiz (hız 0): bitiş adımındaki yer değiştirme bir
	# önceki adımınkine (çekme adımı) en fazla +-2 px sözleşme toleransıyla eşit; ~220 px sıçrama yok.
	assert_lt(
		last_move, prev_move + 2.0, "ömür sonunda savurma yok (adım hareketi çekme adımını aşmaz)"
	)
	assert_lt(AccV202.pos_of(sim, id).distance_to(last_pos), 20.0, "~220 px ışınlanma yok")


func test_z6_hortum_draws_exactly_one_randf_per_retarget() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hortum": 1})
	AccV202.dummy(sim, Vector2(400, 0))
	_first_zone(sim)
	var rep := RandomNumberGenerator.new()
	rep.state = sim.rng_combat.state
	var t0 := sim.step_count
	AccV202.steps(sim, 150)  # 2,5 sn: retarget_every 1,0 => ~2 çekiliş
	var used := -1
	for k in range(0, 8):
		var r2 := RandomNumberGenerator.new()
		r2.state = rep.state
		for _j in k:
			r2.randf()
		if r2.state == sim.rng_combat.state:
			used = k
			break
	assert_between(
		used, 1, 3, "150 adımda %d çekiliş (retarget başına tam 1; boş liste de 1)" % used
	)
	assert_gt(sim.step_count, t0)


# --- Hava Cebi (Z) ---------------------------------------------------------------------------------------


func _kill_dummy(sim: GameSim, pos: Vector2) -> void:
	var id := AccV202.dummy(sim, pos)
	sim.enemies.hp[EnemyPool.index_of(id)] = 1.0
	sim.damage_enemy(id, 10.0, &"bullet")


func test_z7_hava_cebi_draws_one_randf_per_kill_and_matches_chance_over_1000_kills() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hava_cebi": 1})  # chance 0,25
	var pockets := 0
	var bad_draws := 0
	var first := {}
	for k in 1000:
		var before := sim.rng_combat.state
		_kill_dummy(sim, Vector2(200, 0))
		var rep := RandomNumberGenerator.new()
		rep.state = before
		rep.randf()
		bad_draws += 1 if rep.state != sim.rng_combat.state else 0
		if sim.zones.count > 0:
			pockets += 1
			if first.is_empty():
				first = {
					"kind": sim.zones.kind[0],
					"life": sim.zones.life[0],
					"radius": sim.zones.radius[0],
					"pos": sim.zones.pos[0],
				}
		sim.zones.count = 0
	assert_eq(bad_draws, 0, "kill başına tam 1 randf")
	assert_between(float(pockets) / 1000.0, 0.20, 0.30, "olasılık 0,25 +-0,05 (%d/1000)" % pockets)
	assert_eq(first["kind"], ZonePool.KIND_POCKET, "cep türü")
	assert_almost_eq(float(first["life"]), 1.2, 0.001, "cep ömrü life")
	assert_almost_eq(float(first["radius"]), 70.0, 0.01, "cep yarıçapı")
	assert_eq(first["pos"], Vector2(200, 0), "cep ölen düşmanın yerinde")


func test_z8_enemy_killed_by_a_pocket_tick_spawns_no_new_pocket() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hava_cebi": 5})  # chance 0,5
	var done := 0
	var tries := 0
	while done < 10 and tries < 80:
		tries += 1
		sim.zones.count = 0
		_kill_dummy(sim, Vector2(250, 0))
		if sim.zones.count != 1:
			continue
		var victim := AccV202.dummy(sim, sim.zones.pos[0])
		sim.enemies.hp[EnemyPool.index_of(victim)] = 0.5
		var kills0 := sim.kills
		for _k in 60:
			sim.step(Vector2.ZERO)
			if sim.kills > kills0:
				break
		assert_gt(sim.kills, kills0, "cep tiki düşmanı öldürdü")
		assert_lte(
			sim.zones.count, 1, "cep tiki ile ölen düşman yeni cep doğurmaz (deneme %d)" % tries
		)
		done += 1
	assert_eq(done, 10, "10 cep doğdu")


func test_z9_pocket_reserve_blocks_spawn_and_counts_the_drop() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hava_cebi": 5})
	for k in ZonePool.CAP - ZonePool.RESERVE:
		sim.zones.spawn(
			ZonePool.KIND_POCKET,
			Vector2(5000 + k, 0),
			{"radius": 10.0, "life": 99.0, "tick_every": 0.4}
		)
	assert_eq(sim.zones.count, ZonePool.CAP - ZonePool.RESERVE)
	var dropped0 := sim.fx.zone_dropped
	for k in 60:
		_kill_dummy(sim, Vector2(250, 0))
	assert_eq(sim.zones.count, ZonePool.CAP - ZonePool.RESERVE, "rezerv dolu: yeni cep doğmaz")
	assert_gt(sim.fx.zone_dropped, dropped0, "kayıp sessiz değil: sayaç arttı")


# --- Nefes Dalgası (Z) -----------------------------------------------------------------------------------


func _waves(sim: GameSim) -> Array:
	var out: Array = []
	sim.fx.wind_wave.connect(
		func(o: Vector2, r: float, big: bool) -> void:
			out.append({"step": sim.step_count, "origin": o, "radius": r, "big": big})
	)
	return out


func test_z10_nefes_dalgasi_hits_inside_radius_once_pushes_and_spares_elite_position() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"nefes_dalgasi": 1})
	var inside := AccV202.dummy(sim, Vector2(150, 0))
	var outside := AccV202.dummy(sim, Vector2(0, 300))
	var elite := AccV202.dummy(sim, Vector2(-100, 0), &"elit_piyade")
	AccV202.steps(sim, 2)  # ızgara kurulur (doldurma gerçekte bir adım içinde başlar)
	var waves := _waves(sim)
	AccV202.begin_reload(sim)
	assert_eq(waves.size(), 1, "doldurma başlayınca o anda tek dalga")
	assert_eq(waves[0]["big"], false)
	assert_almost_eq(float(waves[0]["radius"]), 200.0, 0.5, "sv1 yarıçap 200")
	var ev := AccV202.damages(sim, &"dot", inside)
	assert_eq(ev.size(), 1, "içerideki tek darbe")
	assert_almost_eq(float(ev[0]["amount"]), 14.0, 0.01, "hasar 14")
	assert_almost_eq(AccV202.pos_of(sim, inside).x, 150.0 + 120.0, 1.5, "dışa 120 px itme")
	assert_eq(AccV202.damages(sim, &"dot", outside).size(), 0, "dışarıdaki etkilenmez")
	assert_eq(AccV202.damages(sim, &"dot", elite).size(), 1, "elit hasar alır")
	assert_eq(AccV202.pos_of(sim, elite), Vector2(-100, 0), "elit itilmez")
	AccV202.steps(sim, 60)
	assert_eq(waves.size(), 1, "bu doldurmada ikinci dalga yok")


func test_z11_nefes_dalgasi_does_not_fire_during_endless_drum_but_does_otherwise() -> void:
	if V202Slice.require(self, "Z"):
		return
	for drum in [false, true]:
		var sim := AccV202.zyfen({"nefes_dalgasi": 1}, false)
		AccV202.dummy(sim, Vector2(300, 0))
		var waves := _waves(sim)
		if drum:
			sim.debug_spawn_pickup(&"sonsuz_tambur", sim.player_pos)
			sim.debug_collect_pickups()
			assert_true(sim.magazine.unlimited, "Sonsuz Tambur etkin")
		AccV202.steps(sim, 420)
		if drum:
			assert_eq(waves.size(), 0, "Sonsuz Tambur'da dalga yok")
			assert_eq(SimKit.count_events(sim, SimEvents.RELOAD_START), 0, "doldurma hiç başlamadı")
		else:
			assert_gte(waves.size(), 1, "kontrol: Sonsuz Tambur yokken doldurmada dalga var")


# --- Fırtına Gözü (Z) ------------------------------------------------------------------------------------


func test_z12_storm_eye_sv5_scales_twister_pocket_by_1_60_area_and_1_50_life() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hortum": 5, "furtina_gozu": 5})
	AccV202.dummy(sim, Vector2(400, 0))
	var zi := _first_zone(sim)
	assert_almost_eq(sim.zones.radius[zi], 220.0 * 1.60, 220.0 * 1.60 * 0.005, "Hortum alanı x1,60")
	assert_almost_eq(sim.zones.life[zi], 4.2 * 1.50, 4.2 * 1.50 * 0.005 + STEP, "Hortum ömrü x1,50")
	var p := AccV202.zyfen({"hava_cebi": 5, "furtina_gozu": 5})
	_kill_dummy(p, Vector2(200, 0))
	for k in 40:
		if p.zones.count > 0:
			break
		_kill_dummy(p, Vector2(200, 0))
	assert_eq(p.zones.count, 1)
	assert_almost_eq(p.zones.radius[0], 100.0 * 1.60, 100.0 * 1.60 * 0.005, "Hava Cebi alanı x1,60")
	assert_almost_eq(p.zones.life[0], 2.0 * 1.50, 2.0 * 1.50 * 0.005, "Hava Cebi ömrü x1,50")


func test_z13_storm_eye_widens_girdap_by_1_60() -> void:
	if V202Slice.require(self, "Z"):
		return
	# sv5 taban 135: x1,60 = 216. Elit yarıçapı 60: 276 içinde, 200 dışında ek payı yok.
	for pair in [[0, 0], [5, 1]]:
		var sim := AccV202.zyfen({"girdap": 5})
		if pair[0] > 0:
			sim.debug_grant(&"furtina_gozu", pair[0])
		var id := AccV202.dummy(sim, Vector2(260, 0), &"elit_piyade")  # 135 + 60 = 195 < 260 <= 216 + 60 = 276
		AccV202.steps(sim, 60)
		var n := AccV202.damages(sim, &"dot", id).size()
		if pair[1] == 1:
			assert_gt(n, 0, "Fırtına Gözü sv5: 216 px yarıçap erişir")
		else:
			assert_eq(n, 0, "Fırtına Gözü yok: 135 px yarıçap erişmez")


# --- Ay Orağı (E) ----------------------------------------------------------------------------------------


func test_e1_ay_oragi_every_second_shot_is_a_giant_unsplit_pierce_all_crescent_with_zero_double_hits(
) -> void:
	if V202Slice.require(self, "E"):
		return
	var sim := AccV202.zyfen({"bolunen_kesik": 5, "agir_kursun": 1}, false)
	sim.debug_grant(&"ay_oragi")
	sim.gun_cd = PackedFloat32Array([0.0, 1.0e9])
	var y := _cast_y()
	var ids: Array[int] = []
	for k in 60:
		ids.append(AccV202.dummy(sim, Vector2(400.0 + 18.0 * k, y)))
	var proj := {}
	for n in 80:
		sim.step(Vector2.ZERO)
		for i in sim.projectiles.count:
			if sim.projectiles.rad[i] > 30.0 and proj.is_empty():
				proj = {
					"rad": sim.projectiles.rad[i],
					"speed": sim.projectiles.vel[i].length(),
					"pierce": sim.projectiles.pierce[i],
					"flags": sim.projectiles.flags[i],
					"life": sim.projectiles.life[i],
				}
				sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
		if not proj.is_empty():
			break
	assert_false(proj.is_empty(), "hilal doğdu")
	assert_almost_eq(float(proj["rad"]), 40.0, 0.01, "yarıçap 40")
	assert_almost_eq(float(proj["speed"]), 1300.0, 1.0, "hız 1300")
	assert_eq(int(proj["pierce"]), ProjectilePool.PIERCE_ALL, "PIERCE_ALL")
	assert_almost_eq(float(proj["life"]) * 1300.0, 1100.0, 40.0, "menzil 1100")
	var max_proj := 0
	for _k in 120:
		sim.step(Vector2.ZERO)
		max_proj = maxi(max_proj, sim.projectiles.count)
	assert_lte(max_proj, 2, "hilal bölünmez: havuzda yalnız 1. kesik + hilal vardı, çocuk doğmadı")
	var doubles := 0
	var hit := 0
	var crescent_hits := 0
	# Temel kesik hasarı (12, Ağır Kurşun sv1 +%10); hilal vuruşu bunun açıkça üstünde olmalı (denge ayarına bağlı sabit eşik yok).
	var base_cut := 12.0 * 1.1
	var crescent_dmg := base_cut * 2.0  # damage_mult 2,0
	var crescent_min := base_cut * 1.5
	for id in ids:
		var big := 0
		for e in AccV202.damages(sim, &"bullet", id):
			if float(e["amount"]) > crescent_min:
				big += 1
				assert_almost_eq(
					float(e["amount"]),
					crescent_dmg,
					crescent_dmg * 0.011 + 0.2,
					"hasar x2,0 (Ağır Kurşun sv1 +%10)"
				)
		doubles += 1 if big > 1 else 0
		crescent_hits += big
		hit += 1 if big > 0 else 0
	assert_gt(hit, 30, "hilal hattı deler (%d/60)" % hit)
	assert_eq(doubles, 0, "60 düşmanlı çizgide çift hasar = 0")


# --- Kasırga Patlaması (E) -------------------------------------------------------------------------------


func test_e2_kasirga_two_big_waves_at_start_and_after_min_0_5_or_80_percent() -> void:
	if V202Slice.require(self, "E"):
		return
	for pair in [[1.3, 30], [0.5, 24]]:  # doldurma süresi -> ikinci dalga gecikmesi (adım): min(0,5; süre x 0,8)
		var sim := AccV202.zyfen({"nefes_dalgasi": 5})
		sim.debug_grant(&"kasirga_patlamasi")
		sim.magazine.base_reload = float(pair[0])
		AccV202.dummy(sim, Vector2(500, 0))
		var waves := _waves(sim)
		AccV202.begin_reload(sim)
		var start := sim.step_count
		AccV202.steps(sim, 70)
		var big: Array = waves.filter(func(w: Dictionary) -> bool: return w["big"])
		assert_eq(big.size(), 2, "doldurma %.1f sn: iki ekran boyu dalga" % pair[0])
		if big.size() == 2:
			assert_eq(int(big[0]["step"]), start, "ilki doldurma başında")
			assert_almost_eq(float(big[0]["radius"]), 900.0, 1.0, "ekran boyu")
			assert_between(
				int(big[1]["step"]) - start,
				int(pair[1]) - 1,
				int(pair[1]) + 1,
				"ikinci dalga gecikmesi (adım)"
			)


func test_e3_kasirga_second_wave_is_cancelled_when_reload_is_interrupted() -> void:
	if V202Slice.require(self, "E"):
		return
	# (a) Sonsuz Tambur doldurmayı keser
	var sim := AccV202.zyfen({"nefes_dalgasi": 5})
	sim.debug_grant(&"kasirga_patlamasi")
	var waves := _waves(sim)
	AccV202.begin_reload(sim)
	AccV202.steps(sim, 8)
	sim.magazine.set_unlimited(true)
	AccV202.steps(sim, 120)
	assert_eq(waves.size(), 1, "doldurma kesildi: ikinci dalga yok")
	# (b) seviye atlama ekranı: sim durur, zamanlayıcı ilerlemez
	var s2 := AccV202.zyfen({"nefes_dalgasi": 5})
	s2.debug_grant(&"kasirga_patlamasi")
	var w2 := _waves(s2)
	AccV202.begin_reload(s2)
	AccV202.steps(s2, 5)
	assert_true(SimKit.level_up_with(s2, 100000), "seviye atlama ekranı")
	var n_before := w2.size()
	for _k in 120:
		s2.step(Vector2.ZERO)
	assert_eq(w2.size(), n_before, "LEVEL_UP sırasında dalga yok (zamanlayıcı ilerlemez)")
	s2.choose(0)
	AccV202.steps(s2, 120)
	assert_lte(w2.size(), 2, "toplam dalga sayısı count'u aşmaz")
	# (c) ölüm
	var s3 := AccV202.zyfen({"nefes_dalgasi": 5})
	s3.debug_grant(&"kasirga_patlamasi")
	var w3 := _waves(s3)
	AccV202.begin_reload(s3)
	AccV202.steps(s3, 3)
	s3.hp = 0.0
	s3.max_hp = 1.0
	AccV202.steps(s3, 120)
	assert_ne(s3.state, GameSim.State.RUNNING, "koşu bitti")
	assert_lte(w3.size(), 1 + 1, "ölümden sonra dalga üretilmez")
	var after_end := w3.size()
	AccV202.steps(s3, 60)
	assert_eq(w3.size(), after_end)


# --- Göğün Mızrağı (E) -----------------------------------------------------------------------------------


func test_e4_gogun_mizragi_fires_4_spears_0_12s_apart_each_at_the_current_highest_hp() -> void:
	if V202Slice.require(self, "E"):
		return
	var sim := AccV202.zyfen({})
	sim.debug_grant(&"gogun_mizragi")
	var a := AccV202.dummy(sim, Vector2(500, 0))
	var b := AccV202.dummy(sim, Vector2(0, 500))
	sim.enemies.hp[EnemyPool.index_of(a)] = AccV202.TOUGH_HP * 2.0
	var origin := PlayerRig.cast_point_world(sim.player_pos, false, sim.character.rig)
	var order: Array[String] = []
	var at: Array[int] = []
	var seen := 0
	for n in 200:
		sim.step(Vector2.ZERO)
		var sp := _spears(sim)
		if sp.is_empty():
			continue
		for i in sp:
			var v := sim.projectiles.vel[i].normalized()
			var ta := (AccV202.pos_of(sim, a) - origin).normalized()
			var tb := (AccV202.pos_of(sim, b) - origin).normalized()
			var cls := "A" if v.dot(ta) > 0.99 else ("B" if v.dot(tb) > 0.99 else "?")
			order.append(cls)
			at.append(sim.step_count)
			seen += 1
			# bir sonraki mızrak için en yüksek canlıyı değiştir
			var hi := b if cls == "A" else a
			var lo := a if cls == "A" else b
			sim.enemies.hp[EnemyPool.index_of(lo)] = AccV202.TOUGH_HP * 0.1
			sim.enemies.hp[EnemyPool.index_of(hi)] = AccV202.TOUGH_HP
		if seen >= 4:
			break
	assert_eq(order, ["A", "B", "A", "B"] as Array[String], "her mızrak o anki en yüksek canlıya")
	if at.size() == 4:
		for k in range(1, 4):
			assert_between(at[k] - at[k - 1], 6, 9, "mızrak aralığı 0,12 sn (7,2 adım +-1)")


# --- Tufan (E) -------------------------------------------------------------------------------------------


func test_e5_tufan_spawns_three_giant_twisters_radius_190_life_8() -> void:
	if V202Slice.require(self, "E"):
		return
	var sim := AccV202.zyfen({})
	sim.debug_grant(&"tufan")
	AccV202.dummy(sim, Vector2(400, 0))
	_first_zone(sim, 800)
	assert_eq(sim.zones.count, 3, "3 dev hortum")
	for i in 3:
		assert_eq(sim.zones.kind[i], ZonePool.KIND_GIANT, "KIND_GIANT")
		assert_almost_eq(sim.zones.radius[i], 190.0, 0.5, "yarıçap 190")
		assert_almost_eq(sim.zones.life[i], 8.0, 0.05, "ömür 8 sn")
	var stormy := AccV202.zyfen({"furtina_gozu": 5})
	stormy.debug_grant(&"tufan")
	AccV202.dummy(stormy, Vector2(400, 0))
	_first_zone(stormy, 800)
	assert_almost_eq(
		stormy.zones.radius[0], 190.0 * 1.6, 190.0 * 1.6 * 0.005, "Fırtına Gözü: alan x1,60"
	)
	assert_almost_eq(
		stormy.zones.life[0], 8.0 * 1.5, 8.0 * 1.5 * 0.005 + STEP, "Fırtına Gözü: ömür x1,50"
	)


func test_e5b_tufan_pulls_does_not_fling_at_the_end_and_deals_double_tick() -> void:
	if V202Slice.require(self, "E"):
		return
	var sim := AccV202.zyfen({})
	sim.debug_grant(&"tufan")
	AccV202.dummy(sim, Vector2(400, 0))
	var zi := _first_zone(sim, 800)
	assert_eq(sim.zones.count, 3, "3 dev hortum")
	var gen := sim.zones.gen[zi]
	# Ölçüm temizliği: yalnız bu dev hortum etkili olsun (diğerleri durur ve küçültülür).
	for j in sim.zones.count:
		sim.zones.speed[j] = 0.0
		if sim.zones.gen[j] != gen:
			sim.zones.radius[j] = 1.0
	var c := sim.zones.pos[zi]
	var id := AccV202.dummy(sim, c + Vector2(100, 0))
	var from := sim.step_count
	var last_pos := AccV202.pos_of(sim, id)
	var prev_move := 0.0
	var last_move := 0.0
	var d_start := last_pos.distance_to(c)
	while sim.zones.index_of_gen(gen) >= 0 and sim.step_count < from + 700:
		last_pos = AccV202.pos_of(sim, id)
		sim.step(Vector2.ZERO)
		prev_move = last_move
		last_move = AccV202.pos_of(sim, id).distance_to(last_pos)
	assert_lt(AccV202.pos_of(sim, id).distance_to(c), d_start, "ömür boyunca merkeze çekildi")
	var ev := AccV202.damages(sim, &"dot", id)
	assert_gte(ev.size(), 5, "tikler")
	assert_almost_eq(float(ev[ev.size() - 1]["amount"]), 40.0, 0.01, "son darbe 2 x tik (2 x 20)")
	for k in range(0, ev.size() - 1):
		assert_almost_eq(float(ev[k]["amount"]), 20.0, 0.01, "tik hasarı 20")
	assert_lt(
		last_move, prev_move + 2.0, "ömür sonunda savurma yok (adım hareketi çekme adımını aşmaz)"
	)
	assert_lt(AccV202.pos_of(sim, id).distance_to(last_pos), 20.0, "~260 px ışınlanma yok")


func test_z14_breath_wave_fires_on_the_exact_step_the_natural_reload_starts() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"nefes_dalgasi": 1}, false)
	AccV202.dummy(sim, Vector2(300, 0))
	var waves := _waves(sim)
	SimKit.run_until(
		sim, func() -> bool: return SimKit.count_events(sim, SimEvents.RELOAD_START) > 0, 600
	)
	var rs := SimKit.last_event(sim, SimEvents.RELOAD_START)
	assert_false(rs.is_empty(), "doğal doldurma başladı")
	assert_eq(waves.size(), 1, "tek dalga")
	assert_eq(
		int(waves[0]["step"]), int(rs["step"]), "dalga doldurmanın başladığı adımda (adım +-0)"
	)


func test_z15_pocket_ticks_with_pocket_dot_pulls_and_expires() -> void:
	if V202Slice.require(self, "Z"):
		return
	var sim := AccV202.zyfen({"hava_cebi": 1})
	var gen := 0
	for _k in 60:
		_kill_dummy(sim, Vector2(250, 0))
		if sim.zones.count > 0:
			gen = sim.zones.gen[0]
			break
	assert_gt(gen, 0, "cep doğdu")
	var c := sim.zones.pos[0]
	var e := AccV202.dummy(sim, c + Vector2(40, 0))
	AccV202.steps(sim, 12)
	assert_almost_eq(
		AccV202.pos_of(sim, e).distance_to(c),
		40.0 - 30.0 * 0.2,
		1.5,
		"cep merkeze çeker (30 px/sn)"
	)
	while sim.zones.index_of_gen(gen) >= 0:
		sim.step(Vector2.ZERO)
	var ev := AccV202.damages(sim, &"pocket_dot", e)
	assert_between(ev.size(), 2, 3, "1,2 sn ömürde 0,4 sn'lik 2-3 tik")
	for x in ev:
		assert_almost_eq(float(x["amount"]), 8.0, 0.01, "tik hasarı 8")
