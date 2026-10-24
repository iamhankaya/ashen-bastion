extends GutTest
## F-ashen-bastion-021: içbükey cepte yer düşmanı çıkmaz tespiti + kısa kaçış modu (EnemyEscape).

const WALL_R := 90.0


func after_each() -> void:
	EnemyEscape.enabled = true


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


func _wall(a: Vector2, b: Vector2) -> Array:
	var out: Array = []
	var n := maxi(1, ceili(a.distance_to(b) / 100.0))
	for k in n + 1:
		var p := a.lerp(b, float(k) / float(n))
		out.append(Vector3(p.x, p.y, WALL_R))
	return out


func _l_corner() -> Array:
	return _wall(Vector2(0, 0), Vector2(700, 0)) + _wall(Vector2(0, 0), Vector2(0, 700))


func _cup() -> Array:
	return (
		_wall(Vector2(-350, 0), Vector2(350, 0))
		+ _wall(Vector2(-350, 0), Vector2(-350, -500))
		+ _wall(Vector2(350, 0), Vector2(350, -500))
	)


func _foe(sim: GameSim, at: Vector2) -> int:
	var id := SimKit.add_enemy(sim, &"curumus_piyade", at)
	sim.enemies.hp[EnemyPool.index_of(id)] = 1.0e9
	return EnemyPool.index_of(id)


## Oyuncuya (70 px) ulaşana dek adımlar; ulaşılan adım ya da -1. `max_esc` ile en uzun kaçış süresini döndürür.
func _run(sim: GameSim, i: int, seconds: int) -> Dictionary:
	var reached := -1
	var begun := false
	var aux_flips := 0
	var last_side := 0.0
	for s in 60 * seconds:
		sim.step(Vector2.ZERO)
		if sim.enemies.esc_left[i] > 0.0:
			begun = true
		var side := sim.enemies.ai_aux[i]
		if side != 0.0 and last_side != 0.0 and side != last_side:
			aux_flips += 1
		if side != 0.0:
			last_side = side
		if sim.enemies.pos[i].distance_to(sim.player_pos) < 70.0:
			reached = s
			break
	return {"reached": reached, "begun": begun, "flips": aux_flips}


func test_l_corner_enemy_enters_escape_and_reaches_player() -> void:
	var sim := _synthetic(_l_corner(), Vector2(-300, -300))
	var i := _foe(sim, Vector2(260, 260))
	var r := _run(sim, i, 60)
	assert_true(r["begun"], "çıkmaz tespit edildi, kaçışa girildi")
	assert_gt(r["reached"], 0, "oyuncuya ulaştı")


func test_cup_enemy_escapes_the_pocket_for_both_player_offsets() -> void:
	for px in [0.0, 200.0, -200.0]:
		var sim := _synthetic(_cup(), Vector2(px, 450), 5)
		var i := _foe(sim, Vector2(0, -250))
		var r := _run(sim, i, 60)
		assert_gt(r["reached"], 0, "kap oyuncu_x=%d" % px)


func test_without_the_fix_the_same_pocket_traps_the_enemy() -> void:
	# Bayrak KAPALI: F-020 dolanması tek başına çıkamaz (karşılaştırma bayrağının işe yaradığını sınar).
	EnemyEscape.enabled = false
	var sim := _synthetic(_l_corner(), Vector2(-300, -300))
	var i := _foe(sim, Vector2(260, 260))
	var r := _run(sim, i, 60)
	assert_false(r["begun"])
	assert_eq(r["reached"], -1, "düzeltme kapalı: takılı kalır")


func test_escape_does_not_flip_the_detour_side_beyond_the_f020_rule() -> void:
	var sim := _synthetic(_cup(), Vector2(0, 450), 5)
	var i := _foe(sim, Vector2(0, -250))
	var r := _run(sim, i, 60)
	assert_lte(r["flips"], 4, "kaçış taraf kararını (esc_side) ayrı tutar, ai_aux'u salındırmaz")


func test_free_walk_never_triggers_escape() -> void:
	var sim := SimKit.make(1, {"data_kind": "quiet", "log_events": false})
	SimKit.godmode(sim)
	sim.player_pos = Vector2.ZERO
	var i := _foe(sim, Vector2(0, -600))
	for _s in 60 * 8:
		sim.step(Vector2.ZERO)
		assert_eq(sim.enemies.esc_left[i], 0.0)
		assert_eq(sim.enemies.stuck_n[i], 0)


func test_single_ruin_detour_does_not_escape() -> void:
	# Tek dairenin arkası (içbükey değil): F-020 dolanması yeter, çıkmaz sayılmaz.
	var sim := _synthetic([Vector3(0, 0, 200)], Vector2(0, 600))
	var i := _foe(sim, Vector2(0, -600))
	var r := _run(sim, i, 40)
	assert_gt(r["reached"], 0)
	assert_false(r["begun"])


func test_blocked_and_path_clear_follow_the_map() -> void:
	var sim := _synthetic([Vector3(0, 0, 100)], Vector2(0, 600))
	var i := _foe(sim, Vector2(0, -300))
	assert_true(EnemyEscape.blocked(sim, Vector2(0, 0), 20.0))
	assert_false(EnemyEscape.blocked(sim, Vector2(0, 300), 20.0))
	assert_false(EnemyEscape.path_clear(sim, i, Vector2(0, 900)), "yol dairenin içinden geçer")
	assert_true(EnemyEscape.path_clear(sim, i, Vector2(900, 0)), "yatay yol açık")
	assert_true(EnemyEscape.path_clear(sim, i, Vector2.ZERO))


func test_begin_prefers_the_unblocked_tangent_side() -> void:
	# Duvar x=100'de dikey (yüzey normali -x). Teğet y ekseni; +y yönünün önü kapalı bir daire.
	var sim := _synthetic([Vector3(100, 0, 60), Vector3(0, 90, 40)], Vector2(500, 0))
	var i := _foe(sim, Vector2(0, 0))
	sim.enemies.push_n[i] = Vector2(-1, 0)
	# tang = (-n.y, n.x) = (0, -1): -y serbest, +y (0, +40) daire içinde → taraf +1 (tang yönü, serbest)
	EnemyEscape.begin(sim, i, Vector2(500, 0))
	assert_eq(sim.enemies.esc_side[i], 1.0)
	assert_eq(sim.enemies.esc_left[i], EnemyEscape.ESC_MAX)


func test_escape_state_is_part_of_the_state_hash_and_runs_are_deterministic() -> void:
	var hashes: Array[int] = []
	for _k in 2:
		var sim := _synthetic(_cup(), Vector2(0, 450), 5)
		var i := _foe(sim, Vector2(0, -250))
		for _s in 60 * 12:
			sim.step(Vector2.ZERO)
		hashes.append(sim.state_hash())
		var before := sim.state_hash()
		sim.enemies.esc_left[i] += 1.0
		assert_ne(sim.state_hash(), before, "esc_left hash'e girer")
	assert_eq(hashes[0], hashes[1])


func test_recycled_or_respawned_slot_starts_clean() -> void:
	var sim := _synthetic(_cup(), Vector2(0, 450), 5)
	var i := _foe(sim, Vector2(0, -250))
	sim.enemies.esc_left[i] = 5.0
	sim.enemies.stuck_n[i] = 3
	sim.enemies.push_n[i] = Vector2.RIGHT
	sim.enemies.kill(sim.enemies.make_id(sim.enemies.gen[i], i))
	var j := _foe(sim, Vector2(10, -250))
	assert_eq(j, i, "aynı yuva yeniden kullanıldı")
	assert_eq(sim.enemies.esc_left[j], 0.0)
	assert_eq(sim.enemies.stuck_n[j], 0)
	assert_eq(sim.enemies.push_n[j], Vector2.ZERO)


func test_escaping_count_counts_only_live_escapers() -> void:
	var sim := _synthetic(_cup(), Vector2(0, 450), 5)
	var i := _foe(sim, Vector2(0, -250))
	assert_eq(EnemyEscape.escaping_count(sim), 0)
	sim.enemies.esc_left[i] = 3.0
	assert_eq(EnemyEscape.escaping_count(sim), 1)
