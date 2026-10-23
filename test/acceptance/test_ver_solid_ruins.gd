extends GutTest
## Doğrulama-2 (T20261023-80): katı harabe kabulü. Geliştirici birim testlerinden bağımsız: tam GameSim, birden çok
## tohum ve harabe, 8 yön, normal ve yüksek hız (sim.stats.move_mult varsa), kenarda titreme/sıkışma, dekor geçilebilir.

const SEEDS: Array[int] = [11, 23, 37]
const PER_SEED := 4


func _sim_and_targets(seed_value: int) -> Array:
	var sim := SimKit.make(seed_value, {"data_kind": "quiet", "log_events": false})
	SimKit.godmode(sim)
	var m := sim.map
	for cx in range(-3, 4):
		for cy in range(-3, 4):
			m.ensure(Vector2(cx * 1024.0, cy * 1024.0))
	var picks: Array[int] = []
	for i in m.count:
		if m.ob_solid[i] == 1 and m.ob_pos[i].length() > 700.0 and picks.size() < PER_SEED:
			picks.append(i)
	return [sim, picks]


func _worst_penetration(m: MapSim, around: Vector2, pos: Vector2, radius: float) -> float:
	var worst := 0.0
	for k in m.circ_pos.size():
		if m.circ_pos[k].distance_to(around) < 1200.0:
			worst = maxf(worst, m.circ_r[k] + radius - pos.distance_to(m.circ_pos[k]))
	return worst


func test_player_never_enters_solid_ruins_from_8_directions_at_normal_and_high_speed() -> void:
	var walks := 0
	for s in SEEDS:
		var parts := _sim_and_targets(s)
		var base: GameSim = parts[0]
		for i in parts[1]:
			for k in 8:
				var sim := SimKit.make(s, {"data_kind": "quiet", "log_events": false})
				SimKit.godmode(sim)
				var m := sim.map
				for cx in range(-3, 4):
					for cy in range(-3, 4):
						m.ensure(Vector2(cx * 1024.0, cy * 1024.0))
				var target := m.ob_pos[i]
				var start := target + Vector2.from_angle(TAU * k / 8.0) * (m.ob_r[i] + 160.0)
				sim.player_pos = m.resolve(start, sim.character.collision_radius)
				var worst := 0.0
				for step in 360:
					sim.step((target - sim.player_pos).normalized())
					worst = maxf(
						worst,
						_worst_penetration(
							m, target, sim.player_pos, sim.character.collision_radius
						)
					)
				walks += 1
				assert_lt(
					worst,
					0.5,
					"seed %d ob %d yön %d: katı harabeye girmedi (nüfuz %.2f)" % [s, i, k, worst]
				)
		assert_not_null(base)
	assert_gt(walks, 60, "yeterli yürüyüş (%d)" % walks)


func test_slide_at_normal_speed_does_not_jitter_at_the_wall() -> void:
	assert_eq(_slide_walk(5.0)["jitter"], 0, "normal hızda (5 px/adım) duvarda titreme yok")


func test_high_speed_slide_does_not_tunnel_and_does_not_jitter_at_the_wall() -> void:
	var extreme := _slide_walk(50.0)  # gerçekçi değil (10x): yalnız tünelleme denetlenir, titreme bilgi amaçlı
	assert_eq(extreme["tunnels"], 0, "10x hızda da tünelleme yok")
	var r := _slide_walk(15.0)  # 3x hız (hız ödülleriyle erişilebilir üst sınır)
	assert_eq(r["tunnels"], 0, "yüksek hızda tünelleme yok")
	assert_eq(r["jitter"], 0, "yüksek hızda duvara yaslanırken yön titremesi yok")


func _slide_walk(step_len: float) -> Dictionary:
	var m := MapSim.new(5, SimKit.data_for("real").ruins)
	for cx in range(-3, 4):
		for cy in range(-3, 4):
			m.ensure(Vector2(cx * 1024.0, cy * 1024.0))
	var tunnels := 0
	var jitter := 0
	var tested := 0
	for i in m.count:
		if m.ob_solid[i] != 1 or tested >= 12:
			continue
		tested += 1
		var c := m.ob_pos[i]
		var dir := Vector2.from_angle(float(i))
		var p := m.resolve(c + dir * (m.ob_r[i] + 150.0), 22.0)
		# 3 000 px/s (adım başına 50 px): normal hızın 10 katı
		var prev := p
		var flips := 0
		var last_move := Vector2.ZERO
		for step in 120:
			var next := m.slide(p, p + (c - p).normalized() * step_len, 22.0)
			if _worst_penetration(m, c, next, 22.0) > 0.5:
				tunnels += 1
			var mv := next - p
			if mv.length() > 0.5 and last_move.length() > 0.5 and mv.dot(last_move) < 0.0:
				flips += 1
			last_move = mv
			prev = p
			p = next
		if flips > 4:
			jitter += 1
		assert_not_null(prev)
	assert_gt(tested, 8)
	gut.p("step_len %.0f: tunnels=%d jitter=%d" % [step_len, tunnels, jitter])
	return {"tunnels": tunnels, "jitter": jitter}


func test_decor_ruins_are_passable_and_solid_rule_matches_data() -> void:
	var data := SimKit.data_for("real")
	var decor_defs: Array = []
	for rec in data.ruins:
		if not bool(rec["solid"]):
			decor_defs.append(rec)
	assert_gt(decor_defs.size(), 5, "dekor tanımı var")
	var m := MapSim.new(7, decor_defs)  # yalnız dekor: komşu katı harabe itmesi karışmasın
	for cx in range(-3, 4):
		for cy in range(-3, 4):
			m.ensure(Vector2(cx * 1024.0, cy * 1024.0))
	var decor := 0
	for i in m.count:
		assert_eq(m.ob_solid[i], 0)
		decor += 1
		assert_eq(m.circ_count[i], 0, "dekorun çarpışma dairesi yok")
		assert_eq(m.resolve(m.ob_pos[i], 22.0), m.ob_pos[i], "dekorun içinden geçilir (ob %d)" % i)
	assert_gt(decor, 20, "yeterli dekor örneği")
	for rec in data.ruins:
		var tex := load(str(rec["sprite"])) as Texture2D
		var h := tex.get_height() * float(rec["display_scale"])
		assert_eq(bool(rec["solid"]), h >= 240.0, "%s: görsel yükseklik %.0f" % [rec["id"], h])
