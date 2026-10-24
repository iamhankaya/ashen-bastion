extends GutTest
## Piyade kare modu (D4-3): 6 kareli şerit ⇒ atlas 3×4 (11 hücre), mesafe tabanlı kare, elit hücre paylaşımı,
## A19 (yerinde duran ilerlemez, ışınlanma sıçratmaz), iş sayacı. Şerit ve manifest çalışma anında user://'a yazılır.

const STRIP := "user://test_infantry_strip.png"
const MANIFEST := "user://test_enemy_manifest.json"
const FRAMES := 6
const IDS := [&"curumus_piyade", &"elit_piyade"]

var _sprites: Dictionary = {}
var _sim: GameSim


func before_each() -> void:
	var img := Image.create(60 * FRAMES, 100, false, Image.FORMAT_RGBA8)
	for f in FRAMES:
		img.fill_rect(Rect2i(f * 60, 0, 60, 100), Color(0.1 * f + 0.1, 0.5, 0.3, 1.0))
	img.save_png(STRIP)
	var man := {
		"version": 1,
		"files": {STRIP: {"frames": FRAMES}, "assets/gfx/enemies/les_kargasi.png": {"frames": 3}}
	}
	var f := FileAccess.open(MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify(man))
	f.close()
	EnemyAtlas.manifest_path = MANIFEST
	_sim = GameSim.new(11, &"gunslinger", {"end_mode": "lord"})
	for id in IDS:  # GameData önbelleği paylaşımlıdır: işin sonunda geri al
		var def: EnemyDef = _sim.data.get_enemy(id)
		_sprites[id] = def.sprite
		def.sprite = STRIP


func after_each() -> void:
	for id in IDS:
		(_sim.data.get_enemy(id) as EnemyDef).sprite = _sprites[id]
	EnemyAtlas.manifest_path = EnemyAtlas.MANIFEST
	DirAccess.remove_absolute(STRIP)
	DirAccess.remove_absolute(MANIFEST)


func _renderer() -> EnemyRenderer:
	var r := EnemyRenderer.new()
	add_child_autofree(r)
	var sh := EnemyShadowLayer.new()
	add_child_autofree(sh)
	r.shadows = sh
	r.bind(_sim)
	return r


func _paths() -> Array[String]:
	var out: Array[String] = []
	for id in _sim.data.enemy_ids:
		var sp := _sim.data.get_enemy(id).sprite
		if not out.has(sp):
			out.append(sp)
	return out


func _cell_of_slot(r: EnemyRenderer, k: int) -> int:
	return roundi(r.multimesh.buffer[k * EnemyRenderer.STRIDE + 13])


func _spawn(id: StringName, p: Vector2) -> int:
	return EnemyPool.index_of(_sim.spawn_enemy(id, _sim.player_pos + p))


func test_six_frame_infantry_atlas_is_3x4_11_cells_and_about_8_3_mb() -> void:
	var atlas := EnemyAtlas.new().build(_paths())
	var used := 0
	for p in atlas.cells.values():
		used += int(p["frames"])
	assert_eq(used, 11, "6 piyade + 3 karga + Lord + şövalye")
	assert_eq(atlas.rows, 4)
	assert_eq(atlas.texture.get_width(), 1248)
	assert_eq(atlas.texture.get_height(), 1664)
	var bytes := atlas.texture.get_width() * atlas.texture.get_height() * 4
	assert_almost_eq(float(bytes) / 1.0e6, 8.3, 0.05, "≈8,3 MB (şimdi ≈4,1 MB)")
	assert_lte(used, 16, "cell_rect[16] yeter")
	assert_eq(int(atlas.cells[STRIP]["frames"]), FRAMES)
	assert_eq(atlas.cells[STRIP]["size"], Vector2(60, 100), "kare tek hücre boyutu")


func test_atlas_frames_land_in_separate_cells_without_bleeding() -> void:
	var atlas := EnemyAtlas.new().build(_paths())
	var base: int = atlas.cells[STRIP]["cell"]
	var img := atlas.texture.get_image()
	for f in FRAMES:
		var c := base + f
		var cx := c % EnemyAtlas.COLS
		var cy := c / EnemyAtlas.COLS
		var px := img.get_pixel(
			cx * EnemyAtlas.CELL + EnemyAtlas.CELL / 2, cy * EnemyAtlas.CELL + EnemyAtlas.CELL / 2
		)
		assert_almost_eq(px.r, 0.1 * f + 0.1, 0.01, "kare %d kendi hücresinde" % f)
		assert_eq(
			img.get_pixel(cx * EnemyAtlas.CELL, cy * EnemyAtlas.CELL).a, 0.0, "hücre köşesi saydam"
		)


func test_elite_infantry_shares_the_cells_of_the_infantry_but_keeps_its_own_cycle() -> void:
	var r := _renderer()
	var t1: int = _sim.data.enemy_ids.find(&"curumus_piyade")
	var t2: int = _sim.data.enemy_ids.find(&"elit_piyade")
	assert_eq(r.cell_of(t1), r.cell_of(t2), "aynı hücreler (ek bellek yok)")
	assert_eq(r.atlas.cells.size(), _paths().size())
	assert_ne(r.anim.cycle_t[t1], r.anim.cycle_t[t2], "adım uzunluğu türe göre")


func test_walking_infantry_cycles_through_all_six_cells_by_distance() -> void:
	var r := _renderer()
	var i := _spawn(&"curumus_piyade", Vector2(-600.0, 0.0))
	r.refresh()
	var base := r.cell_of(_sim.enemies.type_idx[i])
	var cycle := r.anim.cycle_t[_sim.enemies.type_idx[i]]
	var seen := {}
	for k in 80:
		_sim.enemies.pos[i] += Vector2(cycle / 60.0 * 2.0, 0.0)  # 2 çevrim / 60 kare
		r.refresh()
		seen[_cell_of_slot(r, 0) - base] = true
	assert_eq(seen.size(), FRAMES, "A19: yürürken 6 hücrenin hepsi")
	for f in seen:
		assert_between(f, 0, FRAMES - 1)
	assert_gt(r.last_frame_selects, 0)


func test_stationary_infantry_never_changes_cell_and_pose_is_frame_carried() -> void:
	var r := _renderer()
	var i := _spawn(&"curumus_piyade", Vector2(-600.0, 0.0))
	r.refresh()
	var c0 := _cell_of_slot(r, 0)
	var origin0 := Vector2(r.multimesh.buffer[3], r.multimesh.buffer[7])
	for k in 120:
		_sim.time += 1.0 / 60.0
		r.refresh()
		assert_eq(_cell_of_slot(r, 0), c0, "A19: konumu değişmeyen düşmanın karesi/fazı ilerlemez")
	var origin1 := Vector2(r.multimesh.buffer[3], r.multimesh.buffer[7])
	assert_eq(origin0, origin1, "kare modunda bob/θ/squash 0: ayak noktası oynamaz")
	assert_eq(_sim.enemies.alive[i], 1)


func test_teleport_over_60px_does_not_jump_more_than_the_clamp() -> void:
	var r := _renderer()
	var i := _spawn(&"curumus_piyade", Vector2(-600.0, 0.0))
	r.refresh()
	var t: int = _sim.enemies.type_idx[i]
	var w0: float = r.anim.walk[i]
	_sim.enemies.pos[i] += Vector2(5000.0, 0.0)
	r.refresh()
	assert_almost_eq(
		r.anim.walk[i] - w0, 60.0 / r.anim.cycle_t[t], 1e-4, "ışınlanma 60 px'e kenetlenir"
	)


func test_elite_advances_slower_per_pixel_than_the_infantry() -> void:
	var r := _renderer()
	var a := _spawn(&"curumus_piyade", Vector2(-600.0, 0.0))
	var b := _spawn(&"elit_piyade", Vector2(-600.0, 300.0))
	r.refresh()
	var wa: float = r.anim.walk[a]
	var wb: float = r.anim.walk[b]
	_sim.enemies.pos[a] += Vector2(40.0, 0.0)
	_sim.enemies.pos[b] += Vector2(40.0, 0.0)
	r.refresh()
	var da: float = r.anim.walk[a] - wa
	var db: float = r.anim.walk[b] - wb
	assert_gt(da, db, "elit adımı uzun (cycle 160 > 72)")


func test_work_counter_counts_frame_selects_for_400_walking_infantry() -> void:
	var r := _renderer()
	_sim.debug_fill(&"curumus_piyade", 400, 500.0)
	r.refresh()
	assert_eq(_sim.enemies.count, 400)
	assert_lte(r.last_frame_selects, _sim.enemies.count, "A23")
	assert_eq(r.last_frame_selects, 400, "her piyade bir kare seçimi")
	assert_eq(r.last_shadow_instances, 400)
