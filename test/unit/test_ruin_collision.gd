extends GutTest
## Katı harabe çarpışması (T20261023-79): taban izine uyan daire zinciri, kenar boyunca kayma, tünelleme yok,
## komşu chunk'larla çakışma yok (üretim sırasından bağımsız), katı/dekor kuralı, düşman etkileşimi.

const SEEDS := 40
const PLAYER_R := 22.0
const SOLID_MIN_HEIGHT := 240.0


func _data() -> GameData:
	return SimKit.data_for("real")


func _world_map(seed_value: int) -> MapSim:
	var m := MapSim.new(seed_value, _data().ruins)
	for cx in range(-4, 5):
		for cy in range(-4, 5):
			m.ensure(Vector2(cx * 1024.0 + 512.0, cy * 1024.0 + 512.0))
	return m


func _solids(m: MapSim) -> Array[int]:
	var out: Array[int] = []
	for i in m.count:
		if m.ob_solid[i] == 1:
			out.append(i)
	return out


## `centre` çevresinde (900 px) kalan daire indeksleri: tüm haritayı her adımda taramamak için.
func _local(m: MapSim, centre: Vector2) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in m.circ_pos.size():
		if m.circ_pos[i].distance_to(centre) < 900.0:
			out.append(i)
	return out


func _penetration(m: MapSim, local: PackedInt32Array, pos: Vector2, radius: float) -> float:
	var worst := 0.0
	for i in local:
		worst = maxf(worst, m.circ_r[i] + radius - pos.distance_to(m.circ_pos[i]))
	return worst


func _inside_any(rec: Dictionary, p: Vector2) -> bool:
	for c in MapSim.circles_of_def(rec):
		if p.distance_to(Vector2(c.x, c.y)) <= c.z:
			return true
	return false


# --- veri: katı/dekor kuralı ve taban izi ------------------------------------------------------------------------


func test_solid_means_taller_than_the_player_and_decor_is_low() -> void:
	for rec in _data().ruins:
		var tex := load(str(rec["sprite"])) as Texture2D
		var h := tex.get_height() * float(rec["display_scale"])
		assert_eq(
			bool(rec["solid"]),
			h >= SOLID_MIN_HEIGHT,
			"%s: görsel yükseklik %.0f px → katı olmalı=%s" % [rec["id"], h, h >= SOLID_MIN_HEIGHT]
		)
		assert_eq(
			rec.has("collision"), bool(rec["solid"]), "%s: yalnız katıda collision" % rec["id"]
		)


func test_every_solid_ruin_circle_chain_covers_its_visible_base() -> void:
	for rec in _data().ruins:
		if not rec["solid"] or str(rec["id"]) in ["ruin_08", "ruin_09", "ruin_23"]:
			continue  # ince direkli yapılar: yalnız direk tabanı (kumaş ucu taban değildir)
		var img := Image.load_from_file(ProjectSettings.globalize_path(str(rec["sprite"])))
		var k := float(rec["display_scale"])
		var foot := Vector2(
			float(rec["foot"][0]) * img.get_width(), float(rec["foot"][1]) * img.get_height()
		)
		var cols := 0
		var covered := 0
		for x in range(0, img.get_width(), 3):
			var yb := -1
			for y in range(img.get_height() - 1, -1, -1):
				if img.get_pixel(x, y).a > 0.16:
					yb = y
					break
			if yb < 0:
				continue
			cols += 1
			var p := (Vector2(x, yb) - foot) * k + Vector2(0, -10.0)  # taban kenarının 10 px üstü
			if _inside_any(rec, p):
				covered += 1
		assert_gte(
			float(covered) / float(cols),
			0.85,
			"%s: taban kenarının %%85'ı dairelerle kaplı" % rec["id"]
		)


func test_collision_circles_stay_in_the_sprite_neighbourhood() -> void:
	for rec in _data().ruins:
		if not rec["solid"]:
			continue
		var tex := load(str(rec["sprite"])) as Texture2D
		var k := float(rec["display_scale"])
		var size := tex.get_size() * k
		var foot := Vector2(float(rec["foot"][0]), float(rec["foot"][1])) * size
		for c in MapSim.circles_of_def(rec):
			var w := Vector2(c.x, c.y) + foot  # sprite sol-üstüne göre
			assert_gte(w.x - c.z, -c.z * 0.5, "%s: daire sprite'ın solundan taşmıyor" % rec["id"])
			assert_lte(w.x + c.z, size.x + c.z * 0.5, "%s: ... sağından" % rec["id"])
			assert_lte(w.y, size.y, "%s: daire merkezi sprite içinde (taban üstü)" % rec["id"])


# --- yerleşim: komşu chunk'larla çakışma yok (F-ver-002) --------------------------------------------------------


func test_no_two_solid_ruins_overlap_including_across_chunks() -> void:
	var near_chunk_edge := 0
	var min_slack := 1.0e9
	var min_edge_slack := 1.0e9
	for s in range(1, SEEDS + 1):
		var m := _world_map(s)
		var solid := _solids(m)
		for a in solid.size():
			for b in range(a + 1, solid.size()):
				var i := solid[a]
				var j := solid[b]
				var slack := (
					m.ob_pos[i].distance_to(m.ob_pos[j]) - (m.ob_r[i] + m.ob_r[j] + MapSim.MIN_GAP)
				)
				min_slack = minf(min_slack, slack)
		for i in solid:
			var c := MapSim.chunk_of(m.ob_pos[i])
			var local := m.ob_pos[i] - Vector2(c) * MapSim.CHUNK
			var edge := minf(
				minf(local.x, local.y), minf(MapSim.CHUNK - local.x, MapSim.CHUNK - local.y)
			)
			min_edge_slack = minf(min_edge_slack, edge - (m.ob_r[i] + MapSim.MIN_GAP * 0.5))
			near_chunk_edge += 1 if edge < 400.0 else 0
	assert_gte(
		min_slack, -0.01, "sarmalayan çemberler arası MIN_GAP korunur (komşu chunk dahil, 40 tohum)"
	)
	assert_gte(min_edge_slack, -0.01, "kenar şeridi yasağı")
	assert_gt(near_chunk_edge, 0, "yerleşim chunk merkezine kilitlenmiyor")


func test_every_circle_lies_inside_its_ruins_bounding_circle() -> void:
	var worst := -1.0e9
	for s in range(1, 13):
		var m := _world_map(s)
		for i in _solids(m):
			for k in range(m.circ_first[i], m.circ_first[i] + m.circ_count[i]):
				worst = maxf(
					worst, m.ob_pos[i].distance_to(m.circ_pos[k]) + m.circ_r[k] - m.ob_r[i]
				)
	assert_lte(worst, 0.01, "daireler sarmalayan çemberin içinde")


func test_chunk_content_does_not_depend_on_which_neighbours_exist() -> void:
	var data := _data()
	for s in 6:
		var alone := MapSim.new(s, data.ruins)
		alone.ensure(Vector2(3.5 * 1024.0, 3.5 * 1024.0))
		var full := _world_map(s)
		full.ensure(Vector2(3.5 * 1024.0, 3.5 * 1024.0))
		var c := Vector2i(3, 3)
		var pa := PackedVector2Array()
		for i in alone.chunk_obstacles(c):
			pa.append(alone.ob_foot[i])
		var pb := PackedVector2Array()
		for i in full.chunk_obstacles(c):
			pb.append(full.ob_foot[i])
		assert_eq(pa, pb, "tohum %d: chunk içeriği komşulara bağlı değil" % s)


# --- hareket: içeri girmez, kenar boyunca kayar, tünelleme yok ---------------------------------------------------


func test_resolve_checks_every_cell_the_entity_overlaps() -> void:
	var m := MapSim.new(1, _data().ruins)
	# elle daire: merkez x=300 (hücre 1), varlık x=250 (hücre 0) ama kapladığı alan hücre 1'e taşıyor
	m.circ_pos.append(Vector2(300, 100))
	m.circ_r.append(30.0)
	m._register_cell(0)
	var out := m.resolve(Vector2(250, 100), PLAYER_R)
	assert_almost_eq(
		out.distance_to(Vector2(300, 100)), 30.0 + PLAYER_R, 0.05, "komşu hücredeki daire görülür"
	)
	assert_eq(
		m.resolve(Vector2(200, 100), PLAYER_R), Vector2(200, 100), "dışarıdaki konum değişmez"
	)


func test_slide_does_not_tunnel_through_a_thin_obstacle_at_any_speed() -> void:
	var m := MapSim.new(1, _data().ruins)
	m.circ_pos.append(Vector2(0, 0))
	m.circ_r.append(24.0)
	m._register_cell(0)
	for dist in [20.0, 80.0, 400.0, 1500.0]:
		var out := m.slide(Vector2(-dist, 0.0), Vector2(dist, 0.0), PLAYER_R)
		assert_lt(out.x, 0.0, "dist %.0f: engelin öbür yanına geçemez" % dist)
		assert_gte(out.distance_to(Vector2.ZERO), 24.0 + PLAYER_R - 0.05)


func test_player_walks_into_each_solid_ruin_from_eight_directions_without_entering() -> void:
	var m := _world_map(7)
	var checked := 0
	for i in _solids(m):
		if checked >= 14:
			break
		checked += 1
		var target: Vector2 = m.ob_pos[i]
		var local := _local(m, target)
		for k in 8:
			var dir := Vector2.from_angle(TAU * float(k) / 8.0)
			var pos := target + dir * (m.ob_r[i] + 160.0)
			pos = m.resolve(pos, PLAYER_R)
			var worst := 0.0
			for step in 400:
				var to := (target - pos).normalized()
				pos = m.slide(pos, pos + to * 6.0, PLAYER_R)
				worst = maxf(worst, _penetration(m, local, pos, PLAYER_R))
			assert_lt(
				worst, 0.5, "ruin %s yön %d: içeri girdi (%.2f px)" % [m.def_of(i)["id"], k, worst]
			)
	assert_eq(checked, 14)


func test_player_slides_along_the_edge_instead_of_sticking() -> void:
	var m := _world_map(9)
	var checked := 0
	for i in _solids(m):
		if checked >= 10:
			break
		checked += 1
		var target: Vector2 = m.ob_pos[i]
		var local := _local(m, target)
		for k in 8:
			var dir := Vector2.from_angle(TAU * float(k) / 8.0)
			var pos := m.resolve(target + dir * (m.ob_r[i] + 160.0), PLAYER_R)
			for step in 300:  # kenara kadar düz yürü
				var to := (target - pos).normalized()
				pos = m.slide(pos, pos + to * 6.0, PLAYER_R)
			var touch := pos
			var worst := 0.0
			var in_dir := (target - pos).normalized().rotated(deg_to_rad(28.0))  # çapraz bas: teğet bileşen kalır
			for step in 12:
				pos = m.slide(pos, pos + in_dir * 6.0, PLAYER_R)
				worst = maxf(worst, _penetration(m, local, pos, PLAYER_R))
			assert_lt(worst, 0.5, "içeri girmez")
			var slid := touch.distance_to(pos)
			assert_gt(
				slid,
				12.0,
				"ruin %s yön %d: kenar boyunca kayıyor (%.1f px)" % [m.def_of(i)["id"], k, slid]
			)


func test_resolution_is_stable_no_jitter_when_pushing_straight_into_a_wall() -> void:
	var m := _world_map(5)
	var i := _solids(m)[0]
	var target: Vector2 = m.ob_pos[i]
	var pos := m.resolve(target + Vector2(m.ob_r[i] + 150.0, 0.0), PLAYER_R)
	for step in 300:
		pos = m.slide(pos, pos + (target - pos).normalized() * 6.0, PLAYER_R)
	var trace := PackedVector2Array()
	for step in 40:
		var before := pos
		pos = m.slide(pos, pos + (target - pos).normalized() * 6.0, PLAYER_R)
		trace.append(pos)
		assert_lt(pos.distance_to(before), 7.0, "adım başına hareket sınırlı (sıçrama yok)")
	# duvara itilirken konum salınmaz: ardışık adımlar arasında geri-ileri değişimi yok
	var flips := 0
	for s in range(2, trace.size()):
		var a := trace[s - 1] - trace[s - 2]
		var b := trace[s] - trace[s - 1]
		if a.length() > 0.2 and b.length() > 0.2 and a.dot(b) < 0.0:
			flips += 1
	assert_eq(flips, 0, "titreme yok")


func test_game_sim_player_cannot_enter_a_solid_ruin_from_any_direction() -> void:
	var probe := SimKit.make(31, {"log_events": false})
	var m := probe.map
	var pick := -1
	for cx in range(-2, 3):
		for cy in range(-2, 3):
			for i in m.chunk_obstacles(Vector2i(cx, cy)):
				if pick < 0 and m.ob_solid[i] == 1:
					pick = i
	assert_ne(pick, -1)
	for k in 8:
		var sim := SimKit.make(31, {"log_events": false})
		SimKit.godmode(sim)
		var target := sim.map.ob_pos[pick]
		var dir := Vector2.from_angle(TAU * float(k) / 8.0)
		sim.player_pos = sim.map.resolve(target + dir * (sim.map.ob_r[pick] + 200.0), PLAYER_R)
		var local := _local(sim.map, target)
		var worst := 0.0
		for step in 500:
			var to := target - sim.player_pos
			sim.step(to.normalized())
			worst = maxf(
				worst, _penetration(sim.map, local, sim.player_pos, sim.character.collision_radius)
			)
		assert_lt(worst, 0.5, "yön %d: oyuncu katı harabeye giremez" % k)


# --- düşmanlar (docs/dev/ruins.md): sıradan yer düşmanı itilir, elit/Lord muaf ------------------------------------


func test_ground_enemies_are_pushed_out_but_elites_pass_through() -> void:
	var sim := SimKit.make(31, {"log_events": false})
	SimKit.godmode(sim)
	var m := sim.map
	var pick := -1
	for cx in range(-2, 3):
		for cy in range(-2, 3):
			for i in m.chunk_obstacles(Vector2i(cx, cy)):
				if pick < 0 and m.ob_solid[i] == 1:
					pick = i
	var centre := m.circ_pos[m.circ_first[pick]]
	var grunt := SimKit.add_enemy(sim, &"curumus_piyade", centre)
	var elite := SimKit.add_enemy(sim, &"elit_piyade", centre)
	assert_gte(grunt, 0)
	assert_gte(elite, 0)
	sim.player_pos = centre + Vector2(0.0, 1500.0)  # uzak (geri dönüşüm eşiği 1900 altında)
	SimKit.run(sim, 4)
	var g_r := sim.enemies.radius[EnemyPool.index_of(grunt)] * 0.8
	var e_r := sim.enemies.radius[EnemyPool.index_of(elite)] * 0.8
	var gp := SimKit.enemy_pos(sim, grunt)
	var ep := SimKit.enemy_pos(sim, elite)
	var local := _local(m, centre)
	assert_lt(_penetration(m, local, gp, g_r), 0.5, "sıradan düşman harabeden itilir")
	assert_gt(_penetration(m, local, ep, e_r), 1.0, "elit muaf (bilinçli): harabenin içinden geçer")


# --- belirlenimlilik: akış tohumları (F-ver-001) -----------------------------------------------------------------


func test_stream_seeds_are_pinned_independent_of_variant_hash() -> void:
	var sim := SimKit.make(1)
	var seen := {}
	for stream in [&"map", &"spawn", &"choice", &"combat"]:
		var v := sim._stream_seed(stream)
		assert_false(seen.has(v), "akışlar farklı")
		seen[v] = true
		assert_gte(v, 0)
	# sabit değerler: elle yazılmış karıştırma motor sürümüyle değişmez (değişirse kayıtlı koşular/harita değişir)
	assert_eq(sim._stream_seed(&"map"), 4231776125065144723)
	assert_eq(sim._stream_seed(&"spawn"), 6950604273150918458)
	assert_ne(SimKit.make(2)._stream_seed(&"map"), sim._stream_seed(&"map"))
	assert_ne(SimKit.make(-1)._stream_seed(&"map"), SimKit.make(1)._stream_seed(&"map"))
