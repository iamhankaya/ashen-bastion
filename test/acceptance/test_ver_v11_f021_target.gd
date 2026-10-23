extends GutTest
## Doğrulama (v1.1 kabul, D2 hedefi): F-ashen-bastion-021 (içbükey cepte yer düşmanı takılması, ~%5) DÜZELDİĞİNDE geçmesi
## gereken sürüm. test_ver_f020_regression.gd içindeki karakterizasyonların (F-ver3-001) `stuck=0` hedefli karşılıkları:
## aynı senaryolar, aynı tohumlar; beklenen değer "bilinen takılma sayısı" yerine 0. Dilim D2 bitmeden pending;
## D2 bu dosyayı yeşile çevirir ve eski karakterizasyonları (7/6/1 ve "hepsi takılır") tersine çevirir/siler
## (proje notu: kusuru düzelten faz karakterizasyonun tersine çevrilmesini kapsamına alır).
## Bot hareketi bu senaryoların dışında: yalnız düşman dolanması ölçülür.

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


const SLICE := "D2"


func test_hedef_f021_single_enemy_never_stuck_at_real_concave_ruins() -> void:
	if V11Slice.require(self, SLICE):
		return
	var tot := {"cases": 0, "stuck": 0, "camp": 0, "flips": 0, "rev": 0}
	for s in SEEDS:
		for off in [0.0, 0.6, -0.6]:
			var r := _real_cases(s, 1, off, 30)
			for k in ["cases", "stuck", "camp"]:
				tot[k] += r[k]
			tot["flips"] = maxi(tot["flips"], r["flips"])
			tot["rev"] = maxi(tot["rev"], r["rev"])
	gut.p("TEK (hedef): %s" % str(tot))
	assert_gt(tot["cases"], 40, "kapsam: yeterli durum")
	assert_eq(tot["stuck"], 0, "F-021: tek düşman hiçbir içbükey yapıda takılmaz")
	assert_eq(tot["camp"], 0, "F-021: yüzeye yapışıp kalan yok")


func test_hedef_f021_group_of_8_never_stacks_at_real_concave_ruins() -> void:
	if V11Slice.require(self, SLICE):
		return
	var tot := {"cases": 0, "stuck": 0, "camp": 0, "flips": 0, "rev": 0}
	for s in SEEDS:
		for off in [0.0, 0.6]:
			var r := _real_cases(s, 8, off, 35)
			for k in ["cases", "stuck", "camp"]:
				tot[k] += r[k]
			tot["flips"] = maxi(tot["flips"], r["flips"])
			tot["rev"] = maxi(tot["rev"], r["rev"])
	gut.p("GRUP 8 (hedef): %s" % str(tot))
	assert_gt(tot["cases"], 30)
	assert_eq(tot["stuck"], 0, "F-021: 8'li grup takılmaz")
	assert_eq(tot["camp"], 0, "F-021: yığılan düşman yok")


func test_hedef_f021_camping_player_does_not_lock_group_at_concave_ruins() -> void:
	if V11Slice.require(self, SLICE):
		return
	var tot := {"cases": 0, "stuck": 0, "camp": 0, "flips": 0, "rev": 0}
	for s in [4, 5, 6]:
		var r := _real_cases(s, 8, 0.0, 60)
		for k in ["cases", "stuck", "camp"]:
			tot[k] += r[k]
		tot["flips"] = maxi(tot["flips"], r["flips"])
	gut.p("KAMP 60sn (hedef): %s" % str(tot))
	assert_gt(tot["cases"], 10)
	assert_eq(tot["stuck"], 0, "F-021: kamp yapan oyuncuya 60 sn sonra herkes ulaşır")
	assert_eq(tot["camp"], 0)


func test_hedef_f021_u_cup_enemy_escapes_the_pocket() -> void:
	if V11Slice.require(self, SLICE):
		return
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
	assert_eq(
		stuck,
		0,
		(
			"F-021: kap tuzağı - kabın içindeki düşman yan duvarın ucunu geçip oyuncuya ulaşır (%d/%d)"
			% [stuck, cases]
		)
	)


func test_hedef_f021_l_corner_enemy_reaches_the_player() -> void:
	if V11Slice.require(self, SLICE):
		return
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
	assert_eq(
		stuck,
		0,
		"F-021: L köşe - iç köşedeki düşman dışarı çıkıp oyuncuya ulaşır (%d/%d)" % [stuck, cases]
	)


func test_hedef_f021_fix_keeps_exempt_kinds_and_determinism() -> void:
	if V11Slice.require(self, SLICE):
		return
	var hashes: Array[int] = []
	for _k in 2:
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
	assert_eq(hashes[0], hashes[1], "düzeltme sonrası dolanma deterministik")
	# Muaf türler (elit/Lord/uçan/hayalet) harabeden etkilenmeden geçmeye devam eder.
	var walls: Array = _wall(Vector2(-600, 0), Vector2(600, 0))
	for kind in [&"elit_piyade", &"elit_sovalye", &"les_kargasi", &"sovalye_hayaleti"]:
		var sim2 := _synthetic(walls, Vector2(0, 400), 2)
		var id := SimKit.add_enemy(sim2, kind, Vector2(0, -400))
		sim2.enemies.hp[EnemyPool.index_of(id)] = 1.0e9
		var crossed := false
		for _s in HZ * 12:
			sim2.step(Vector2.ZERO)
			if sim2.enemies.pos[EnemyPool.index_of(id)].y > 40.0:
				crossed = true
				break
		assert_true(crossed, "%s muaf: harabeden geçer" % kind)
