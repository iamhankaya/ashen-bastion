extends GutTest
## Doğrulama-3 (T20261023-83): F-ashen-bastion-020 (yer düşmanı katı harabeyi dolanır) regresyonu. Geliştirici
## birim testlerinden (test_enemy_detour) ve doğrulama-2 ölçümünden (test_ver_enemy_behind_ruin) bağımsız:
## yeni tohumlar, eğik başlangıç, grup yığılması, taraf salınımı, içbükey köşe (dar boşluk, kap, L), muafiyetler,
## determinizm (state_hash ai_dir içerir) ve kalabalık iş sayacı. Duvar saati iddiası yok.

const HZ := 60
const REACH := 70.0
const SEEDS: Array[int] = [4, 5, 6, 7, 8, 9]
const CASES_PER_SEED := 8
const WALL_R := 90.0


## Sim'in haritasını sentetik dairelerle değiştirir (oyuncu sabit; chunk üretimi tetiklenmez).
func _synthetic(circles: Array, player: Vector2, seed_value: int = 1) -> GameSim:
	var sim := SimKit.make(seed_value, {"data_kind": "quiet", "log_events": false})
	SimKit.godmode(sim)
	var m := sim.map
	m.circ_pos = PackedVector2Array()
	m.circ_r = PackedFloat32Array()
	m._cells.clear()
	for c in circles:
		m.circ_pos.append(Vector2(c.x, c.y))
		m.circ_r.append(c.z)
		m._register_cell(m.circ_pos.size() - 1)
	sim.player_pos = player
	m._last_chunk = MapSim.chunk_of(player)
	return sim


## a'dan b'ye WALL_R yarıçaplı, üst üste binen dairelerden duvar.
func _wall(a: Vector2, b: Vector2) -> Array:
	var out: Array = []
	var n := maxi(1, ceili(a.distance_to(b) / 100.0))
	for k in n + 1:
		var p := a.lerp(b, float(k) / float(n))
		out.append(Vector3(p.x, p.y, WALL_R))
	return out


## Düşmanları koşturur. Döner: {reached: bool, first: s, flips: en çok taraf değişimi, rev: en çok yön tersleme,
## camp: oyuncuya uzak ama duvara yapışık düşman sayısı (son adım), min_dist}.
func _run(sim: GameSim, ids: Array, seconds: int) -> Dictionary:
	var player := sim.player_pos
	var idx: Array[int] = []
	var last_side: Array[float] = []
	var flips: Array[int] = []
	var last_pos: Array[Vector2] = []
	var last_move: Array[Vector2] = []
	var rev: Array[int] = []
	for id in ids:
		idx.append(EnemyPool.index_of(id))
		last_side.append(0.0)
		flips.append(0)
		last_pos.append(SimKit.enemy_pos(sim, id))
		last_move.append(Vector2.ZERO)
		rev.append(0)
	var reached := false
	var first := -1.0
	for s in HZ * seconds:
		sim.step(Vector2.ZERO)
		var near := 0
		for k in ids.size():
			var p := sim.enemies.pos[idx[k]]
			if p.distance_to(player) < REACH:
				near += 1
			var side: float = sim.enemies.ai_aux[idx[k]]
			if side != 0.0 and last_side[k] != 0.0 and side != last_side[k]:
				flips[k] += 1
			if side != 0.0:
				last_side[k] = side
			var mv := p - last_pos[k]
			if mv.length_squared() > 0.25 and last_move[k].length_squared() > 0.25:
				if mv.dot(last_move[k]) < 0.0:
					rev[k] += 1
			if mv.length_squared() > 0.25:
				last_move[k] = mv
			last_pos[k] = p
		if near > 0 and first < 0.0:
			first = float(s) / HZ
		if near == ids.size():
			reached = true
			break
	var camp := 0
	for k in ids.size():
		var p := sim.enemies.pos[idx[k]]
		if p.distance_to(player) < REACH * 2.0:
			continue
		var lean := false
		for c in sim.map.circ_pos.size():
			if p.distance_to(sim.map.circ_pos[c]) < sim.map.circ_r[c] + 26.0 + 14.0:
				lean = true
				break
		if lean:
			camp += 1
	return {
		"reached": reached,
		"first": first,
		"flips": flips.max(),
		"rev": rev.max(),
		"camp": camp,
	}


func _spawn(sim: GameSim, at: Vector2, n: int) -> Array:
	var ids: Array = []
	for k in n:
		var e := SimKit.add_enemy(
			sim, &"curumus_piyade", at + Vector2(50.0 * (k % 4) - 75.0, 40.0 * (k / 4))
		)
		sim.enemies.hp[EnemyPool.index_of(e)] = 1.0e9
		ids.append(e)
	return ids


## Gerçek haritada: katı engel merkezinden geçen doğrultuda (angle_off ile eğik) düşman(lar) karşı yanda.
func _real_cases(seed_value: int, n: int, angle_off: float, seconds: int) -> Dictionary:
	var sim := SimKit.make(seed_value, {"data_kind": "quiet", "log_events": false})
	SimKit.godmode(sim)
	var m := sim.map
	for cx in range(-3, 4):
		for cy in range(-3, 4):
			m.ensure(Vector2(cx * 1024.0, cy * 1024.0))
	var tot := {"cases": 0, "stuck": 0, "camp": 0, "flips": 0, "rev": 0}
	for i in m.count:
		if m.ob_solid[i] != 1 or tot["cases"] >= CASES_PER_SEED:
			continue
		var c := m.ob_pos[i]
		if c.length() < 700.0 or c.length() > 2600.0:
			continue
		var dir := Vector2.from_angle(float(i) * 1.7 + 0.4)
		var reach := m.ob_r[i] + 260.0
		var player := c + dir * reach
		var foe := c - dir.rotated(angle_off) * reach
		if m.resolve(player, 22.0).distance_to(player) > 0.5:
			continue
		if m.resolve(foe, 26.0).distance_to(foe) > 0.5:
			continue
		sim.player_pos = player
		var ids := _spawn(sim, foe, n)
		tot["cases"] += 1
		var r := _run(sim, ids, seconds)
		if not r["reached"]:
			tot["stuck"] += 1
		tot["camp"] += r["camp"]
		tot["flips"] = maxi(tot["flips"], r["flips"])
		tot["rev"] = maxi(tot["rev"], r["rev"])
		for e in ids:
			if sim.enemies.is_alive(e):
				sim.enemies.alive[EnemyPool.index_of(e)] = 0
	return tot


func test_karakterizasyon_f_ver3_001_single_enemy_stuck_in_concave_real_ruins() -> void:
	## Katı harabeler çoğunlukla geçilir (137/144), ama içbükey çok daireli yapılarda (ncirc 9–11) tek düşman kalıcı takılır.
	## Düzeltilince `stuck` 0 olmalı: bu testi tersine çevir (assert_eq(stuck, 0)).
	var tot := {"cases": 0, "stuck": 0, "camp": 0, "flips": 0, "rev": 0}
	for s in SEEDS:
		for off in [0.0, 0.6, -0.6]:
			var r := _real_cases(s, 1, off, 30)
			for k in ["cases", "stuck", "camp"]:
				tot[k] += r[k]
			tot["flips"] = maxi(tot["flips"], r["flips"])
			tot["rev"] = maxi(tot["rev"], r["rev"])
	gut.p("TEK (yeni tohumlar, düz+eğik): %s" % str(tot))
	assert_gt(tot["cases"], 40)
	assert_eq(tot["stuck"], 7, "F-ver3-001: bilinen takılma sayısı (değişirse güncelle/ters çevir)")


func test_karakterizasyon_f_ver3_001_group_of_8_stacks_at_concave_real_ruins() -> void:
	## Aynı içbükey yapılarda 8'li grup yüzeyde yığılır. Düzeltilince stuck=0 ve camp=0 olmalı.
	var tot := {"cases": 0, "stuck": 0, "camp": 0, "flips": 0, "rev": 0}
	for s in SEEDS:
		for off in [0.0, 0.6]:
			var r := _real_cases(s, 8, off, 35)
			for k in ["cases", "stuck", "camp"]:
				tot[k] += r[k]
			tot["flips"] = maxi(tot["flips"], r["flips"])
			tot["rev"] = maxi(tot["rev"], r["rev"])
	gut.p("GRUP 8 (yeni tohumlar): %s" % str(tot))
	assert_gt(tot["cases"], 30)
	assert_eq(tot["stuck"], 6, "F-ver3-001: bilinen takılan grup sayısı")
	assert_lte(tot["camp"], 31, "F-ver3-001: yığılan düşman sayısı daha kötüye gitmez")


func test_karakterizasyon_f_ver3_001_camping_player_locks_group_only_at_concave_ruins() -> void:
	# Kamp: oyuncu sabit, 8'li grup 60 sn sonra bile oyuncuya yapışık (yüzeyde asılı kalan yok).
	var tot := {"cases": 0, "stuck": 0, "camp": 0, "flips": 0, "rev": 0}
	for s in [4, 5, 6]:
		var r := _real_cases(s, 8, 0.0, 60)
		for k in ["cases", "stuck", "camp"]:
			tot[k] += r[k]
	gut.p("KAMP 60sn: %s" % str(tot))
	assert_gt(tot["cases"], 10)
	assert_eq(tot["stuck"], 1, "F-ver3-001: 60 sn kampta takılan durum (yalnız içbükey yapı)")
	assert_lte(tot["camp"], 8)
	assert_eq(tot["flips"], 0, "takılmayan durumlarda taraf salınımı yok")


func test_concave_gap_between_two_ruins_enemy_passes_when_passable() -> void:
	# İki duvar arası dar boşluk: düşman 20,8 px yarıçaplı; boşluk 82 px (geçilebilir, oyuncu 44 px). Oyuncu boşluk
	# ekseninden farklı kayıklıklarda duvarın arkasında.
	var gap := 82.0
	var walls: Array = []
	walls += _wall(Vector2(-1100, 0), Vector2(-gap / 2.0 - WALL_R, 0))
	walls += _wall(Vector2(gap / 2.0 + WALL_R, 0), Vector2(1100, 0))
	var rows: Array[String] = []
	var stuck := 0
	var cases := 0
	for off in [0.0, 150.0, -150.0, 400.0, -400.0]:
		for n in [1, 8]:
			var sim := _synthetic(walls, Vector2(off, 500), 3)
			var ids := _spawn(sim, Vector2(0, -450), n)
			var r := _run(sim, ids, 40)
			cases += 1
			if not r["reached"]:
				stuck += 1
			(
				rows
				. append(
					(
						"boşluk kayıklık=%d n=%d ulaştı=%s ilk=%.1fs taraf_degisim=%d yon_tersleme=%d yigilan=%d"
						% [off, n, r["reached"], r["first"], r["flips"], r["rev"], r["camp"]]
					)
				)
			)
	for row in rows:
		gut.p(row)
	assert_eq(stuck, 0, "dar boşluktan geçemeyen: %d/%d" % [stuck, cases])


func test_karakterizasyon_f_ver3_001_concave_cup_traps_enemy_inside_pocket() -> void:
	# U kap: arka duvar oyuncuyla düşman arasında, yan duvarlar -y'ye açık. Düşman kabın içinde; yan duvarın uç
	# noktasını geçip dolanmalı.
	var walls: Array = []
	walls += _wall(Vector2(-350, 0), Vector2(350, 0))
	walls += _wall(Vector2(-350, 0), Vector2(-350, -500))
	walls += _wall(Vector2(350, 0), Vector2(350, -500))
	var stuck := 0
	var cases := 0
	for n in [1, 8]:
		for px in [0.0, 200.0, -200.0]:
			var sim := _synthetic(walls, Vector2(px, 450), 5)
			var ids := _spawn(sim, Vector2(0, -250), n)
			var r := _run(sim, ids, 60)
			cases += 1
			if not r["reached"]:
				stuck += 1
			gut.p(
				(
					"kap n=%d oyuncu_x=%d ulaştı=%s ilk=%.1fs taraf_degisim=%d yon_tersleme=%d"
					% [n, px, r["reached"], r["first"], r["flips"], r["rev"]]
				)
			)
	assert_eq(stuck, cases, "F-ver3-001: kap tuzağı (hepsi takılır; düzelince 0 olmalı)")


func test_karakterizasyon_f_ver3_001_concave_l_corner_traps_enemy() -> void:
	# L köşe: iki duvar 90° birleşir; düşman iç köşede, oyuncu köşenin dışında karşı çaprazda.
	var walls: Array = []
	walls += _wall(Vector2(0, 0), Vector2(700, 0))
	walls += _wall(Vector2(0, 0), Vector2(0, 700))
	var stuck := 0
	var cases := 0
	for n in [1, 8]:
		for s in [1, 2]:
			var sim := _synthetic(walls, Vector2(-300, -300), s)
			var ids := _spawn(sim, Vector2(260, 260), n)
			var r := _run(sim, ids, 60)
			cases += 1
			if not r["reached"]:
				stuck += 1
			gut.p(
				(
					"L n=%d tohum=%d ulaştı=%s ilk=%.1fs taraf_degisim=%d yon_tersleme=%d"
					% [n, s, r["reached"], r["first"], r["flips"], r["rev"]]
				)
			)
	assert_eq(stuck, cases, "F-ver3-001: L köşe tuzağı (hepsi takılır; düzelince 0 olmalı)")


func test_exempt_kinds_still_ignore_ruins_after_f020() -> void:
	# Elit/Lord/uçan/hayalet muaf: düz çizgide harabenin içinden geçer (itilmez); yer düşmanı itilir.
	var walls: Array = _wall(Vector2(-600, 0), Vector2(600, 0))
	var kinds: Array[StringName] = [
		&"elit_piyade", &"elit_sovalye", &"elit_karga", &"les_kargasi", &"sovalye_hayaleti"
	]
	for k in kinds:
		var sim := _synthetic(walls, Vector2(0, 400), 2)
		var id := SimKit.add_enemy(sim, k, Vector2(0, -400))
		sim.enemies.hp[EnemyPool.index_of(id)] = 1.0e9
		var crossed := false
		var i := EnemyPool.index_of(id)
		for _s in HZ * 12:
			sim.step(Vector2.ZERO)
			if sim.enemies.pos[i].y > 40.0:
				crossed = true
				break
		assert_true(crossed, "%s harabeden etkilenmeden geçer" % k)
		assert_eq(
			sim.enemies.ai_timer[i] if k != &"elit_karga" else 0.0, 0.0, "%s dolanma modu yok" % k
		)
	var sim2 := _synthetic(walls, Vector2(0, 400), 2)
	var gid := SimKit.add_enemy(sim2, &"curumus_piyade", Vector2(0, -150))
	sim2.enemies.hp[EnemyPool.index_of(gid)] = 1.0e9
	for _s in HZ * 3:
		sim2.step(Vector2.ZERO)
	assert_lt(SimKit.enemy_pos(sim2, gid).y, WALL_R, "yer düşmanı duvarın içine geçmez")


func test_same_seed_same_hash_with_detouring_enemies_and_ai_dir_is_in_the_hash() -> void:
	var hashes: Array[int] = []
	for _run_k in 2:
		var sim := SimKit.make(6, {"data_kind": "quiet", "log_events": false})
		SimKit.godmode(sim)
		var m := sim.map
		for cx in range(-3, 4):
			for cy in range(-3, 4):
				m.ensure(Vector2(cx * 1024.0, cy * 1024.0))
		for i in m.count:
			if m.ob_solid[i] == 1 and m.ob_pos[i].length() > 900.0:
				var d := Vector2.RIGHT
				sim.player_pos = m.ob_pos[i] + d * (m.ob_r[i] + 260.0)
				_spawn(sim, m.ob_pos[i] - d * (m.ob_r[i] + 260.0), 8)
				break
		for _s in HZ * 20:
			sim.step(Vector2.ZERO)
		hashes.append(sim.state_hash())
		# ai_dir hash'e girer: değiştirince hash değişir.
		var before := sim.state_hash()
		var ei := -1
		for k in EnemyPool.CAP:
			if sim.enemies.alive[k] == 1:
				ei = k
				break
		sim.enemies.ai_dir[ei] += Vector2(3.0, 0.0)
		assert_ne(sim.state_hash(), before, "ai_dir state_hash içinde")
	assert_eq(hashes[0], hashes[1], "aynı tohum aynı hash (dolanma dahil)")


func test_crowd_of_376_ground_enemies_pressing_on_ruins_stays_under_work_budget() -> void:
	var budget: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tools/perf_budget.json")
	)
	var work: Array[Dictionary] = []
	var hashes: Array[int] = []
	for _run_k in 2:
		var sim := SimKit.make(710, {"data_kind": "real", "log_events": false})
		SimKit.godmode(sim)
		var m := sim.map
		for cx in range(-3, 4):
			for cy in range(-3, 4):
				m.ensure(Vector2(cx * 1024.0, cy * 1024.0))
		# En çok katı daire içeren bölgeye oyuncuyu koy.
		var best := Vector2(2000, 0)
		var best_n := -1
		for i in m.count:
			if m.ob_solid[i] != 1:
				continue
			var n_near := 0
			for j in m.count:
				if m.ob_solid[j] == 1 and m.ob_pos[j].distance_to(m.ob_pos[i]) < 1100.0:
					n_near += 1
			if n_near > best_n:
				best_n = n_near
				best = m.ob_pos[i]
		sim.player_pos = best + Vector2(0, m.ob_r[0] + 300.0)
		var rng := Bots.make_rng(710)
		for k in 376:
			var e := sim.spawn_enemy(
				&"curumus_piyade",
				(
					sim.player_pos
					+ Vector2.from_angle(rng.randf() * TAU) * (500.0 + rng.randf() * 700.0)
				)
			)
			if e >= 0:
				sim.enemies.hp[EnemyPool.index_of(e)] = 1.0e9
		var t0 := Time.get_ticks_usec()
		for _s in 600:
			SimKit.godmode(sim)
			sim.step(Vector2.ZERO)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 600.0
		gut.p(
			(
				"BİLGİ ruin-kalabalık: %.2f ms/adım ort, canlı=%d, work=%s"
				% [ms, sim.enemies.count, str(sim.work)]
			)
		)
		assert_gte(sim.enemies.count, 300, "kalabalık korunur")
		for key in GameSim.WORK_KEYS:
			if budget.has(String(key)):
				assert_lte(
					float(sim.work[key]) / 600.0,
					float(budget[String(key)]),
					"%s adım başına bütçe altında" % key
				)
		work.append(sim.work.duplicate())
		hashes.append(sim.state_hash())
	assert_eq(work[0], work[1], "iş sayaçları tekrarlanabilir")
	assert_eq(hashes[0], hashes[1], "kalabalık koşusu deterministik")
