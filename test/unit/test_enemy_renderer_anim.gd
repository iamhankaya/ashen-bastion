extends GutTest
## EnemyRenderer (D1-2): dönüşüm yazımı (EnemyAnim.pose_of ile uyum), vurulma itmesi, gölge tamponu, iş sayaçları,
## kare seçimi ve elit/Lord özel durumları. Tamponlar: dönüşüm [x.x, y.x, 0, ox, x.y, y.y, 0, oy], renk 4, custom 4.

const S := EnemyRenderer.STRIDE


func _sim() -> GameSim:
	return GameSim.new(11, &"gunslinger", {"end_mode": "lord"})


func _renderer(sim: GameSim) -> EnemyRenderer:
	var r := EnemyRenderer.new()
	add_child_autofree(r)
	var sh := EnemyShadowLayer.new()
	add_child_autofree(sh)
	r.shadows = sh
	r.bind(sim)
	return r


func _spawn(sim: GameSim, id: StringName, p: Vector2) -> int:
	return EnemyPool.index_of(sim.spawn_enemy(id, sim.player_pos + p))


func _origin(r: EnemyRenderer, k: int = 0) -> Vector2:
	var b := r.multimesh.buffer
	return Vector2(b[k * S + 3], b[k * S + 7])


func test_transform_matches_pose_of_for_each_type() -> void:
	for id in [&"curumus_piyade", &"les_kargasi", &"sovalye_hayaleti", &"kale_lordu"]:
		var sim := _sim()
		var r := _renderer(sim)
		var i := _spawn(sim, id, Vector2(-500.0, 0.0))  # oyuncunun solunda: sağa bakar
		sim.time = 7.31
		r.refresh()
		var t := sim.enemies.type_idx[i]
		var an := r.anim
		var pose := EnemyAnim.pose_of(
			an.kind_of(t), an.hz_t[t], an.bob_t[t], an.rot_t[t], an.sq_t[t], sim.time, an.phase0[i]
		)
		var q := r.quad_size(t)
		var foot := q.y * 0.5
		var lean := an.lean_t[t]  # sağa bakış: +
		var th := pose.x + lean
		var p := sim.enemies.pos[i]
		var want := Vector2(
			p.x + foot * pose.z * sin(th), p.y + foot - foot * pose.z * cos(th) - pose.w
		)
		assert_lt(_origin(r).distance_to(want), 0.01 + 0.0, "%s merkez" % id)
		var b := r.multimesh.buffer
		assert_almost_eq(b[0], q.x * pose.y * cos(th), 0.01 * q.x, "%s x.x" % id)
		assert_almost_eq(b[5], q.y * pose.z * cos(th), 0.01 * q.y, "%s y.y" % id)


func test_idle_pose_at_time_zero_stays_within_bob_of_position() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	sim.debug_fill(&"curumus_piyade", 25, 400.0)
	r.refresh()
	var first := EnemyPool.index_of(sim.alive_ids()[0])
	assert_lt(_origin(r).distance_to(sim.enemies.pos[first]), 16.0, "bob/itme payı ±16 px")


func test_mirror_follows_the_player_side() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	_spawn(sim, &"curumus_piyade", Vector2(300.0, 0.0))  # sağda: sola bakar
	r.refresh()
	assert_lt(r.multimesh.buffer[0], 0.0)
	var sim2 := _sim()
	var r2 := _renderer(sim2)
	_spawn(sim2, &"curumus_piyade", Vector2(-300.0, 0.0))
	r2.refresh()
	assert_gt(r2.multimesh.buffer[0], 0.0)


func _axes(r: EnemyRenderer, k: int = 0) -> Vector2:
	## (|x ekseni|, |y ekseni|) = (q.x·sx, q.y·sy): dönmeden bağımsız ölçek.
	var b := r.multimesh.buffer
	return Vector2(
		Vector2(b[k * S], b[k * S + 4]).length(), Vector2(b[k * S + 1], b[k * S + 5]).length()
	)


func test_hit_knock_pushes_away_from_the_player_quadratically() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := _spawn(sim, &"curumus_piyade", Vector2(400.0, 0.0))
	sim.time = 2.0
	r.refresh()
	var base := _origin(r)
	sim.enemies.flash[i] = 1.0
	r.refresh()
	assert_almost_eq(_origin(r).x - base.x, 10.0, 0.01, "flash=1: piyade dışa 10 px")
	sim.enemies.flash[i] = 0.5
	r.refresh()
	assert_almost_eq(_origin(r).x - base.x, 2.5, 0.01, "flash=0,5: 2,5 px")
	sim.enemies.flash[i] = 0.0
	r.refresh()
	assert_almost_eq(_origin(r).x - base.x, 0.0, 1e-4)


func test_lord_is_not_knocked_back_and_hit_squash_keeps_volume() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := _spawn(sim, &"kale_lordu", Vector2(500.0, 0.0))
	sim.time = 2.0
	r.refresh()
	var base := _origin(r)
	var b0 := r.multimesh.buffer.duplicate()
	sim.enemies.flash[i] = 1.0
	r.refresh()
	assert_almost_eq(_origin(r).x, base.x, 0.01, "Lord itilmez")
	var b1 := r.multimesh.buffer
	var sx_ratio := absf(b1[0]) / absf(b0[0])
	var sy_ratio := b1[5] / b0[5]
	assert_between(sx_ratio * sy_ratio, 0.98, 1.02, "squash hacmi korur")
	assert_almost_eq(sy_ratio, 1.0 / (1.0 + 0.015), 0.003)
	# piyade: sx·sy ≈ 1
	var j := _spawn(sim, &"curumus_piyade", Vector2(-400.0, 0.0))
	r.refresh()
	var bp0 := r.multimesh.buffer.duplicate()
	sim.enemies.flash[j] = 1.0
	r.refresh()
	var k := _slot_of(r, j)
	var ratio := (
		(absf(r.multimesh.buffer[k * S]) / absf(bp0[k * S]))
		* (r.multimesh.buffer[k * S + 5] / bp0[k * S + 5])
	)
	assert_between(ratio, 0.98, 1.02)


## Tamponda i. havuz yuvasının sırası (canlılar indeks sırasıyla yazılır).
func _slot_of(r: EnemyRenderer, pool_idx: int) -> int:
	var k := 0
	for i in pool_idx:
		if r._sim.enemies.alive[i] == 1:
			k += 1
	return k


func test_work_counters_and_shadow_count_match_alive() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	r.refresh()
	assert_eq(r.last_anim_instances, 0)
	assert_eq(r.last_shadow_instances, 0)
	var n := sim.debug_fill(&"curumus_piyade", 150, 500.0)
	n += sim.debug_fill(&"les_kargasi", 150, 700.0)
	n += sim.debug_fill(&"sovalye_hayaleti", 100, 800.0)
	assert_gt(n, 300)
	r.refresh()
	assert_eq(r.visible_count(), sim.enemies.count)
	assert_lte(r.last_anim_instances, sim.enemies.count)
	assert_lte(r.last_frame_selects, sim.enemies.count)
	assert_eq(r.last_shadow_instances, sim.enemies.count, "gölge sayısı = canlı")
	assert_eq(r.shadows.multimesh.visible_instance_count, sim.enemies.count)
	assert_gt(r.last_frame_selects, 0, "karga kareleri seçilir")


func test_shadow_width_alpha_and_ground_anchor() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := _spawn(sim, &"curumus_piyade", Vector2(-400.0, 0.0))
	sim.time = 1.0
	r.refresh()
	var t := sim.enemies.type_idx[i]
	var sb := r.shadows.multimesh.buffer
	var sprite_w := r.sprite_world_width(t)
	assert_almost_eq(sb[0], 0.8 * sprite_w, 0.5, "genişlik = 0,8 × sprite")
	assert_almost_eq(sb[5], 0.2 * 0.8 * sprite_w, 0.5, "yükseklik = 0,2 × genişlik")
	assert_almost_eq(sb[11], 0.38, 1e-3, "α 0,38")
	assert_eq(sb[8], 0.0)
	var foot := r.quad_size(t).y * 0.5
	var p := sim.enemies.pos[i]
	assert_almost_eq(sb[3], p.x, 0.01)
	assert_almost_eq(sb[7], p.y + foot, 1.0, "yerde: ayak noktası")


func test_flying_shadow_shrinks_and_fades_with_height() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := _spawn(sim, &"sovalye_hayaleti", Vector2(-400.0, 0.0))
	var t := sim.enemies.type_idx[i]
	var ws := PackedFloat32Array()
	var al := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for k in 200:
		sim.time = float(k) * 0.05
		r.refresh()
		ws.append(r.shadows.multimesh.buffer[0])
		al.append(r.shadows.multimesh.buffer[11])
		ys.append(r.shadows.multimesh.buffer[7])
	var wmin := 99999.0
	var wmax := 0.0
	var amin := 9.0
	var amax := 0.0
	for k in 200:
		wmin = minf(wmin, ws[k])
		wmax = maxf(wmax, ws[k])
		amin = minf(amin, al[k])
		amax = maxf(amax, al[k])
	assert_gt(wmax, wmin * 1.1, "yükseldikçe küçülür (%15'e kadar)")
	assert_lte(wmin, wmax * 0.97)
	assert_gte(wmin, wmax * 0.84)
	assert_lte(amax, 0.38 + 1e-3)
	assert_gte(amin, 0.38 * 0.69)
	assert_lt(amin, amax)
	var foot := r.quad_size(t).y * 0.5
	assert_almost_eq(
		ys[0], sim.enemies.pos[i].y + foot + r.anim.hover_of(t), 1.0, "gölge hover kadar aşağıda"
	)


func test_flap_cell_follows_ping_pong_sequence() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := _spawn(sim, &"les_kargasi", Vector2(-400.0, 0.0))
	var t := sim.enemies.type_idx[i]
	var base := r._cell_by_type[t]
	var seen := {}
	for k in 48:
		sim.time = float(k) / 12.0 + 0.001
		r.refresh()
		var cell := int(round(r.multimesh.buffer[13]))
		assert_between(cell, base, base + 2)
		seen[cell - base] = true
		var want := EnemyAnim.flap_frame(3, sim.time, r.anim.phase0[i])
		assert_eq(cell - base, want)
	assert_eq(seen.size(), 3)


func test_crawl_without_frames_keeps_single_cell_and_no_frame_select() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := _spawn(sim, &"curumus_piyade", Vector2(-400.0, 0.0))
	var t := sim.enemies.type_idx[i]
	r.refresh()
	assert_eq(int(round(r.multimesh.buffer[13])), r._cell_by_type[t])
	assert_eq(r.last_frame_selects, 0)


func test_slot_reuse_reseeds_the_phase() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var id1 := sim.spawn_enemy(&"curumus_piyade", sim.player_pos + Vector2(400, 0))
	var i := EnemyPool.index_of(id1)
	r.refresh()
	var p1 := r.anim.phase0[i]
	sim.enemies.kill(id1)
	var id2 := sim.spawn_enemy(&"curumus_piyade", sim.player_pos + Vector2(400, 0))
	assert_eq(EnemyPool.index_of(id2), i, "aynı yuva yeniden kullanılır")
	r.refresh()
	assert_ne(r.anim.phase0[i], p1)


func test_lord_telegraph_stretches_and_enrage_signals_once() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := _spawn(sim, &"kale_lordu", Vector2(-600.0, 0.0))
	sim.time = 3.0
	sim.enemies.ai_timer[i] = 5.0
	r.refresh()
	var calm := _axes(r).y
	sim.enemies.ai_timer[i] = 0.5
	r.refresh()
	assert_almost_eq(_axes(r).y / calm, 1.10, 0.005, "ai_timer<0,6: sy 1,10")
	sim.enemies.ai_timer[i] = 5.0
	var hits: Array[Vector2] = []
	r.lord_enraged.connect(func(p: Vector2) -> void: hits.append(p))
	r.refresh()
	assert_eq(hits.size(), 0)
	sim.enemies.ai_aux[i] = 1.0
	r.refresh()
	r.refresh()
	sim.time += 0.3
	r.refresh()
	assert_eq(hits.size(), 1, "öfke dizisi bir kez")
	assert_eq(hits[0], sim.enemies.pos[i])
	# 900 ms sonra kalıcı ton: renk kırmızıya kayar
	sim.time += 2.0
	r.refresh()
	assert_gt(r.multimesh.buffer[8], 0.8)
	assert_lt(r.multimesh.buffer[10], 0.5)


func test_lord_summon_slam_squashes_for_120ms_and_signals_once() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := _spawn(sim, &"kale_lordu", Vector2(-600.0, 0.0))
	var slams: Array[Vector2] = []
	r.lord_slammed.connect(func(p: Vector2) -> void: slams.append(p))
	sim.time = 5.0
	sim.enemies.ai_timer[i] = 0.3
	r.refresh()
	var calm := _axes(r).y
	var calm_x := _axes(r).x
	assert_eq(slams.size(), 0)
	sim.time = 5.05
	sim.enemies.ai_timer[i] = 7.9  # çağırma yapıldı, sayaç yeniden kuruldu
	r.refresh()
	assert_eq(slams.size(), 1)
	assert_almost_eq(_axes(r).y / calm, 0.88 / 1.10, 0.005, "vuruş: sy 0,88 (hazırlık 1,10'dan)")
	assert_almost_eq(_axes(r).x / calm_x, 1.10, 0.005, "sx 1,10")
	sim.time = 5.30
	sim.enemies.ai_timer[i] = 7.5
	r.refresh()
	assert_eq(slams.size(), 1, "sayaç normal akarken tekrar tetiklenmez")
	assert_almost_eq(_axes(r).x / calm_x, 1.0, 0.005, "120 ms sonra normal")


func test_charger_telegraph_narrows_then_charge_widens() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var i := _spawn(sim, &"elit_karga", Vector2(-600.0, 0.0))
	sim.time = 4.0
	sim.enemies.ai_timer[i] = 3.0
	r.refresh()
	var calm := _axes(r).x
	var calm_col := r.multimesh.buffer[8]
	sim.enemies.ai_timer[i] = 0.2
	r.refresh()
	assert_almost_eq(_axes(r).x / calm, 0.9, 0.005, "hazırlık: sx 0,9")
	assert_gt(r.multimesh.buffer[8], calm_col, "göz nabzı: ton x1,3")
	sim.enemies.ai_timer[i] = 3.0
	sim.enemies.ai_aux[i] = 0.5
	r.refresh()
	assert_almost_eq(_axes(r).x / calm, 1.25, 0.005, "şarj: sx 1,25")


func test_elite_steps_make_dust_at_most_four_per_second_and_shake_when_close() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	var fx := FxRenderer.new()
	add_child_autofree(fx)
	var cam := CameraRig.new()
	add_child_autofree(cam)
	r.set_effects(fx, cam)
	var i := _spawn(sim, &"elit_piyade", Vector2(-300.0, 0.0))
	assert_gte(i, 0)
	var dust := 0
	var base := fx.particle_count()
	for k in 600:  # 10 sn
		sim.time = float(k) / 60.0
		r.refresh()
		dust = fx.particle_count() - base
	assert_lte(dust, 40 + 1, "<=4/sn")
	assert_gt(dust, 3, "adım toz verir")
	assert_gt(cam._shake, 0.0, "yakında kamera titreşir")
	# uzak elit: sarsıntı yok
	var far := _renderer(_sim())
	var cam2 := CameraRig.new()
	add_child_autofree(cam2)
	var fx2 := FxRenderer.new()
	add_child_autofree(fx2)
	far.set_effects(fx2, cam2)
	_spawn(far._sim, &"elit_piyade", Vector2(-900.0, 0.0))
	for k in 300:
		far._sim.time = float(k) / 60.0
		far.refresh()
	assert_eq(cam2._shake, 0.0, "400 px üstü: sarsıntı yok")


func test_refresh_never_touches_sim_state() -> void:
	var sim := _sim()
	var r := _renderer(sim)
	sim.debug_fill(&"curumus_piyade", 80, 500.0)
	sim.debug_fill(&"les_kargasi", 40, 600.0)
	for k in 30:
		sim.step(Vector2.ZERO)
	var h0 := sim.state_hash()
	for k in 5:
		sim.time += 0.1
		r.refresh()
	assert_eq(sim.state_hash(), h0, "A22: görünüm yenilemesi state_hash'i değiştirmez")


func test_unbound_or_empty_is_safe() -> void:
	var r := EnemyRenderer.new()
	add_child_autofree(r)
	r.refresh()
	assert_eq(r.visible_count(), 0)
	r.bind(null)
	r.refresh()
	assert_eq(r.last_shadow_instances, 0)
