extends GutTest
## Kabul (v1.1 D1/D4): düşman animasyonu - faz çeşitliliği, poz uyumu, vurulma itmesi, gölge, hayalet, karga kareleri,
## Lord özel durumları, görünüm-sim ayrımı, iş sayaçları (A13-A23). Dilim D1 (D4: mesafe tabanlı piyade karesi).
## Ölçüm EnemyRenderer çok-örnek tamponundan yapılır (STRIDE 16: dönüşüm 8, renk 4, INSTANCE_CUSTOM 4); iç faz
## dizilerine bakılmaz. Düşmanlar sabit (hız 0) ve sim.time elle ayarlanır: gerçek zaman yok.

const STRIDE := EnemyRenderer.STRIDE
const SHADOW_STRIDE := 12
const PIYADE := &"curumus_piyade"


class World:
	extends RefCounted
	var sim: GameSim
	var r: EnemyRenderer


func _world(seed_value: int = 1, extra: Dictionary = {}) -> World:
	var w := World.new()
	var o := {"data_kind": "quiet", "pickups": false, "log_events": false}
	o.merge(extra, true)
	w.sim = SimKit.make(seed_value, o)
	w.sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	w.r = EnemyRenderer.new()
	add_child_autofree(w.r)
	# Gölge katmanını denetleyici kurar (GameController._v11_build_world); burada aynı bağlantı elle yapılır.
	w.r.shadows = EnemyShadowLayer.new()
	add_child_autofree(w.r.shadows)
	w.r.bind(w.sim)
	return w


func _spawn(w: World, type_id: StringName, pos: Vector2) -> int:
	var id := w.sim.debug_spawn(type_id, pos)
	assert_gte(id, 0, "%s doğdu" % type_id)
	if id >= 0:
		var i := EnemyPool.index_of(id)
		w.sim.enemies.speed[i] = 0.0
		w.sim.enemies.hp[i] = 1.0e9
	return id


## Canlı düşmanların havuz indeksleri, artan (tampon sırası).
func _alive_idx(w: World) -> Array[int]:
	var out: Array[int] = []
	for i in EnemyPool.CAP:
		if w.sim.enemies.alive[i] == 1:
			out.append(i)
	return out


## Tamponda n. canlı örneğin alanları: x/y tabanı, kaynak, renk, özel veri.
func _inst(w: World, n: int) -> Dictionary:
	var b := w.r.multimesh.buffer
	var o := n * STRIDE
	return {
		"x": Vector2(b[o], b[o + 4]),
		"y": Vector2(b[o + 1], b[o + 5]),
		"origin": Vector2(b[o + 3], b[o + 7]),
		"flash": b[o + 12],
		"cell": b[o + 13],
	}


## v1 quad boyutu (EnemyRenderer.bind ile aynı formül): (sprite + 2 MARGIN) × world_per_texel.
func _quad(w: World, type_id: StringName) -> Vector2:
	var def: EnemyDef = w.sim.data.get_enemy(type_id)
	var h := maxf(def.display_height, def.radius * 2.2)
	var info: Dictionary = w.r.atlas.cells[def.sprite]
	var sz: Vector2 = info["size"]
	var wpt := h / maxf(sz.y, 1.0)
	return (sz + Vector2(2 * EnemyAtlas.MARGIN, 2 * EnemyAtlas.MARGIN)) * wpt


func _sprite_world_w(w: World, type_id: StringName) -> float:
	var def: EnemyDef = w.sim.data.get_enemy(type_id)
	var h := maxf(def.display_height, def.radius * 2.2)
	var info: Dictionary = w.r.atlas.cells[def.sprite]
	var sz: Vector2 = info["size"]
	return sz.x * h / maxf(sz.y, 1.0)


func _std(v: Array[float]) -> float:
	var m := 0.0
	for x in v:
		m += x
	m /= v.size()
	var s := 0.0
	for x in v:
		s += (x - m) * (x - m)
	return sqrt(s / v.size())


# --- A13 ------------------------------------------------------------------------------------------------------


func test_a13_hundred_grunts_do_not_bob_in_sync() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(1)
	w.sim.time = 12.34
	for k in 100:
		_spawn(w, PIYADE, Vector2.from_angle(TAU * k / 100.0) * (600.0 + 5.0 * k))
	w.r.refresh()
	var dys: Array[float] = []
	var idx := _alive_idx(w)
	for n in idx.size():
		dys.append(_inst(w, n)["origin"].y - w.sim.enemies.pos[idx[n]].y)
	assert_eq(dys.size(), 100)
	assert_gt(_std(dys), 0.5, "fazlar farklı: dikey sapma yayılımı (σ=%.2f px)" % _std(dys))
	assert_gt(dys.max() - dys.min(), 2.5, "bob genliğinin yarısından fazla yayılım")
	var distinct := {}
	for d in dys:
		distinct[snappedf(d, 0.05)] = true
	assert_gte(distinct.size(), 20, "özdeş poz yok (>= 20 ayrı değer)")


func test_a13_slot_reuse_gets_a_fresh_phase() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(2)
	w.sim.time = 7.77
	var differ := 0
	var tried := 0
	for k in 8:
		var pos := Vector2(500.0 + 90.0 * k, 0.0)
		var id := _spawn(w, PIYADE, pos)
		w.r.refresh()
		var idx := EnemyPool.index_of(id)
		var order := _alive_idx(w).find(idx)
		var before: float = _inst(w, order)["origin"].y - pos.y
		w.sim.damage_enemy(id, 1.0e12, &"bullet")
		var id2 := _spawn(w, PIYADE, pos)
		w.r.refresh()
		if EnemyPool.index_of(id2) != idx:
			continue
		tried += 1
		var after: float = _inst(w, _alive_idx(w).find(idx))["origin"].y - pos.y
		if absf(after - before) > 0.05:
			differ += 1
	assert_gte(tried, 4, "aynı yuva yeniden kullanıldı")
	assert_gte(differ, tried - 2, "yeniden kullanılan yuva yeni faz alır (%d/%d)" % [differ, tried])


# --- A14 ------------------------------------------------------------------------------------------------------


func test_a14_pose_of_invariants_volume_angle_bob_periodicity() -> void:
	if V11Slice.require(self, "D1"):
		return
	var specs := {
		EnemyAnim.Kind.CRAWL: [1.1, 5.0, 5.0, 0.05],
		EnemyAnim.Kind.FLAP: [3.0, 7.0, 12.0, 0.10],
		EnemyAnim.Kind.FLOAT: [0.7, 6.0, 2.5, 0.03],
		EnemyAnim.Kind.STOMP: [0.55, 6.0, 2.5, 0.0],
	}
	for kind in specs:
		var hz: float = specs[kind][0]
		var bob: float = specs[kind][1]
		var rot := deg_to_rad(float(specs[kind][2]))
		var sq: float = specs[kind][3]
		var bad := PackedStringArray()
		for k in 240:
			var t := 0.037 * k
			var p := float(k % 17) / 17.0
			var v := EnemyAnim.pose_of(kind, hz, bob, rot, sq, t, p)
			var vol := v.y * v.z
			if absf(v.x) > rot + 0.002:
				bad.append("kind %d: θ aşıyor %.4f" % [kind, v.x])
			if vol < 0.98 or vol > 1.02:
				bad.append("kind %d: hacim %.4f" % [kind, vol])
			var bob_lo := (
				0.0 if kind == EnemyAnim.Kind.CRAWL or kind == EnemyAnim.Kind.STOMP else -bob
			)
			if v.w < bob_lo - 0.01 or v.w > bob + 0.01:
				bad.append("kind %d: bob %.3f" % [kind, v.w])
			var nxt := EnemyAnim.pose_of(kind, hz, bob, rot, sq, t + 1.0 / 240.0, p)
			if (nxt - v).length() > 1.0:
				bad.append("kind %d: poz sıçraması" % kind)
			if (v - EnemyAnim.pose_of(kind, hz, bob, rot, sq, t, p)).length() > 0.0:
				bad.append("kind %d: deterministik değil" % kind)
		assert_eq(bad.size(), 0, "kind %d: %s" % [kind, str(bad.slice(0, 3))])
	# Hız çarpanı phase0'dan ±%15 (plan A3): crawl bob ritmi nominal hz'nin 2x'i (|sin|) ±%15 içinde kalır.
	var rot := deg_to_rad(5.0)
	for p0 in [0.0, 0.25, 0.5, 0.75, 0.95]:
		var edges := 0
		var prev := 0.0
		for k in 4800:  # 20 sn @240 Hz
			var b := EnemyAnim.pose_of(EnemyAnim.Kind.CRAWL, 1.1, 5.0, rot, 0.05, k / 240.0, p0).w
			if prev < 2.5 and b >= 2.5:
				edges += 1
			prev = b
		var ratio := float(edges) / (2.0 * 1.1 * 20.0)
		assert_between(
			ratio, 0.84, 1.16, "phase0=%.2f: crawl ritmi hz'nin ±%%15'i içinde (%.2f)" % [p0, ratio]
		)
	var spread := {}
	for p0 in [0.0, 0.2, 0.4, 0.6, 0.8]:
		spread[snappedf(EnemyAnim.pose_of(EnemyAnim.Kind.CRAWL, 1.1, 5.0, rot, 0.05, 3.3, p0).w, 0.01)] = true
	assert_gte(spread.size(), 4, "phase0 farklı poz üretir")
	var none := EnemyAnim.pose_of(EnemyAnim.Kind.NONE, 1.0, 5.0, 0.1, 0.1, 3.3, 0.4)
	assert_eq(none, Vector4(0.0, 1.0, 1.0, 0.0), "none: kimlik poz")


func test_a14_renderer_buffer_keeps_squash_volume_and_tilt_within_data_limits() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(3)
	w.sim.time = 5.55
	for k in 60:
		_spawn(w, PIYADE, Vector2.from_angle(TAU * k / 60.0) * 700.0)
	w.r.refresh()
	var q := _quad(w, PIYADE)
	var bad := PackedStringArray()
	for n in _alive_idx(w).size():
		var d := _inst(w, n)
		var sxp: float = d["x"].length() / q.x
		var syp: float = d["y"].length() / q.y
		var theta := atan2(-d["y"].x, d["y"].y)
		if sxp * syp < 0.98 or sxp * syp > 1.02:
			bad.append("örnek %d: hacim %.3f" % [n, sxp * syp])
		if absf(theta) > deg_to_rad(9.5):
			bad.append("örnek %d: eğim %.1f°" % [n, rad_to_deg(theta)])
	assert_eq(bad.size(), 0, str(bad.slice(0, 4)))


# --- A15 ------------------------------------------------------------------------------------------------------


func _knock_dx(type_id: StringName, flash: float) -> float:
	var w := _world(4)
	w.sim.time = 3.0
	_spawn(w, type_id, Vector2(400, 0))
	w.r.refresh()
	var o0: Vector2 = _inst(w, 0)["origin"]
	w.sim.enemies.flash[_alive_idx(w)[0]] = flash
	w.r.refresh()
	var o1: Vector2 = _inst(w, 0)["origin"]
	return o1.x - o0.x


func test_a15_hit_knock_pushes_grunt_10_px_at_full_flash_and_quarter_at_half() -> void:
	if V11Slice.require(self, "D1"):
		return
	assert_almost_eq(_knock_dx(PIYADE, 1.0), 10.0, 1.2, "flash=1: dışa 10 px")
	assert_almost_eq(_knock_dx(PIYADE, 0.5), 2.5, 0.8, "flash=0,5: 2,5 px (flash²)")
	assert_almost_eq(_knock_dx(PIYADE, 0.0), 0.0, 0.05)


func test_a15_elite_knock_is_2_px_and_lord_does_not_move() -> void:
	if V11Slice.require(self, "D1"):
		return
	assert_almost_eq(_knock_dx(&"elit_piyade", 1.0), 2.0, 0.8, "elit 2 px")
	assert_almost_eq(_knock_dx(&"kale_lordu", 1.0), 0.0, 0.5, "Lord 0 px")


func test_a15_knock_direction_is_away_from_the_player() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(5)
	w.sim.time = 3.0
	_spawn(w, PIYADE, Vector2(-400, 0))
	w.r.refresh()
	var o0: Vector2 = _inst(w, 0)["origin"]
	w.sim.enemies.flash[_alive_idx(w)[0]] = 1.0
	w.r.refresh()
	var o1: Vector2 = _inst(w, 0)["origin"]
	assert_almost_eq(o1.x - o0.x, -10.0, 1.2, "oyuncunun solundaki düşman sola itilir")


# --- A16 ------------------------------------------------------------------------------------------------------


func _shadow(w: World, n: int) -> Dictionary:
	var b := w.r.shadows.multimesh.buffer
	var o := n * SHADOW_STRIDE
	var mesh_w := w.r.shadows.multimesh.mesh.get_aabb().size.x
	return {
		"w": absf(b[o]) * mesh_w,
		"h": absf(b[o + 5]) * w.r.shadows.multimesh.mesh.get_aabb().size.y,
		"alpha": b[o + 11],
		"origin": Vector2(b[o + 3], b[o + 7]),
	}


func test_a16_shadow_count_equals_alive_and_ground_shadow_geometry() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(6)
	for k in 25:
		_spawn(w, PIYADE, Vector2.from_angle(TAU * k / 25.0) * 600.0)
	w.r.refresh()
	assert_not_null(w.r.shadows, "gölge katmanı")
	if w.r.shadows == null:
		return
	assert_eq(w.r.last_shadow_instances, 25, "gölge sayısı = canlı")
	assert_eq(w.r.shadows.multimesh.visible_instance_count, 25)
	var sw := _sprite_world_w(w, PIYADE)
	var bad := PackedStringArray()
	for n in 25:
		var s := _shadow(w, n)
		if absf(s["w"] - 0.8 * sw) > 0.03 * 0.8 * sw:
			bad.append("örnek %d: genişlik %.1f (beklenen %.1f)" % [n, s["w"], 0.8 * sw])
		if absf(s["h"] - 0.2 * s["w"]) > 0.03 * s["w"]:
			bad.append("örnek %d: yükseklik %.1f" % [n, s["h"]])
		if absf(s["alpha"] - 0.38) > 0.01:
			bad.append("örnek %d: alfa %.3f" % [n, s["alpha"]])
	assert_eq(bad.size(), 0, str(bad.slice(0, 4)))


func test_a16_flying_shadow_shrinks_and_fades_with_height_but_stays_bounded() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(7)
	_spawn(w, &"sovalye_hayaleti", Vector2(500, 0))
	assert_not_null(w.r.shadows, "gölge katmanı")
	if w.r.shadows == null:
		return
	var sw := _sprite_world_w(w, &"sovalye_hayaleti")
	var a_lo := 10.0
	var a_hi := 0.0
	var w_lo := 1.0e9
	var w_hi := 0.0
	var ground_y := 0.0
	for k in 60:
		w.sim.time = 0.05 * k
		w.r.refresh()
		var s := _shadow(w, 0)
		a_lo = minf(a_lo, s["alpha"])
		a_hi = maxf(a_hi, s["alpha"])
		w_lo = minf(w_lo, s["w"])
		w_hi = maxf(w_hi, s["w"])
		if k == 0:
			ground_y = s["origin"].y
		assert_almost_eq(s["origin"].y, ground_y, 0.5, "gölge sabit zeminde (kare %d)" % k)
	assert_lte(a_hi, 0.38 + 0.01)
	assert_gte(a_lo, 0.38 * 0.7 - 0.01, "alfa en çok %30 düşer")
	assert_gt(a_hi - a_lo, 0.004, "yükseklikle alfa değişir")
	assert_lte(w_hi, 0.8 * sw * 1.03)
	assert_gte(w_lo, 0.8 * sw * 0.85 * 0.97, "genişlik en çok %15 küçülür")
	assert_gt(w_hi - w_lo, 0.5, "yükseklikle genişlik değişir")


# --- A17 ------------------------------------------------------------------------------------------------------


func _ghosts(w: World) -> AshGhostRenderer:
	var g := AshGhostRenderer.new()
	add_child_autofree(g)
	g.bind(w.sim, w.r)
	return g


func _kill(w: World, id: int) -> void:
	w.sim.damage_enemy(id, 1.0e12, &"bullet")


func test_a17_each_kill_adds_a_ghost_that_lives_the_per_type_duration() -> void:
	if V11Slice.require(self, "D1"):
		return
	var cases := {PIYADE: 420, &"les_kargasi": 420, &"sovalye_hayaleti": 700, &"elit_piyade": 900}
	for type_id in cases:
		var w := _world(8)
		var g := _ghosts(w)
		_kill(w, _spawn(w, type_id, Vector2(500, 0)))
		assert_eq(g.ghost_count(), 1, "%s: ölüm hayalet +1" % type_id)
		var life := float(cases[type_id]) / 1000.0
		g.update_ghosts(life - 0.03)
		assert_eq(g.ghost_count(), 1, "%s: %d ms dolmadan sürer" % [type_id, cases[type_id]])
		g.update_ghosts(0.06)
		assert_eq(g.ghost_count(), 0, "%s: %d ms sonra biter" % [type_id, cases[type_id]])


func test_a17_ring_buffer_holds_64_and_replaces_the_oldest() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(9)
	var g := _ghosts(w)
	for k in 70:
		_kill(w, _spawn(w, PIYADE, Vector2(300.0 + 12.0 * (k % 30), 40.0 * (k / 30))))
	assert_eq(g.ghost_count(), AshGhostRenderer.CAP, "tampon 64 ile sınırlı")
	g.update_ghosts(0.2)
	for k in 3:
		_kill(w, _spawn(w, PIYADE, Vector2(900.0 + 12.0 * k, 0)))
	assert_eq(g.ghost_count(), AshGhostRenderer.CAP, "taşınca en eski değişir (64 kalır)")
	g.update_ghosts(0.3)  # ilk 64: 0,5 sn (söndü); son 3: 0,3 sn (sürüyor)
	assert_lt(g.ghost_count(), AshGhostRenderer.CAP, "eskiler sönmüş, yeniler sürüyor")
	assert_eq(g.ghost_count(), 3, "yalnız son 3 ölüm")


func test_a17_lod_above_150_alive_uses_150_ms_flat_fade() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(10)
	var g := _ghosts(w)
	assert_gt(
		w.sim.debug_fill(PIYADE, AshGhostRenderer.LOD_ALIVE + 20, 900.0), AshGhostRenderer.LOD_ALIVE
	)
	var victim := w.sim.alive_ids()[0]
	_kill(w, victim)
	assert_eq(g.ghost_count(), 1)
	g.update_ghosts(0.12)
	assert_eq(g.ghost_count(), 1, "120 ms: sürüyor")
	g.update_ghosts(0.06)
	assert_eq(g.ghost_count(), 0, "LOD: 150 ms'de bitti (420 ms değil)")


# --- A18 ------------------------------------------------------------------------------------------------------


func test_a18_crow_frames_ping_pong_0_1_2_1_at_12_fps() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(11)
	_spawn(w, &"les_kargasi", Vector2(500, 0))
	var base := float(w.r.atlas.cells[w.sim.data.get_enemy(&"les_kargasi").sprite]["cell"])
	var pattern: Array[int] = [0, 1, 2, 1]
	var seq: Array[int] = []
	for k in 16:
		w.sim.time = (float(k) + 0.25) / 12.0
		w.r.refresh()
		seq.append(int(round(_inst(w, 0)["cell"] - base)))
	var ok_shift := -1
	for s in 4:
		var match_all := true
		for k in seq.size():
			if seq[k] != pattern[(k + s) % 4]:
				match_all = false
				break
		if match_all:
			ok_shift = s
			break
	assert_ne(ok_shift, -1, "kare dizisi [0,1,2,1] ping-pong @12 kare/sn: %s" % str(seq))
	w.sim.time = 1.0 / 12.0 + 0.01
	w.r.refresh()
	var f1: float = _inst(w, 0)["cell"]
	w.sim.time = 1.0 / 12.0 + 0.07
	w.r.refresh()
	assert_eq(_inst(w, 0)["cell"], f1, "bir kare 83 ms sürer")


func test_a18_crows_of_different_slots_are_offset_from_each_other() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(12)
	for k in 8:
		_spawn(w, &"les_kargasi", Vector2(500.0 + 70.0 * k, 0))
	w.sim.time = 2.0
	w.r.refresh()
	var seen := {}
	for n in 8:
		seen[_inst(w, n)["cell"]] = true
	assert_gte(seen.size(), 2, "yuva ofseti: kargalar aynı karede değil")


# --- A19 (D4: mesafe tabanlı piyade karesi) -------------------------------------------------------------------


func test_a19_crawl_frame_follows_distance_stationary_holds_teleport_is_clamped() -> void:
	if V11Slice.require(self, "D1") or V11Slice.require(self, "D4"):
		return
	var w := _world(13)
	var info: Dictionary = w.r.atlas.cells[w.sim.data.get_enemy(PIYADE).sprite]
	if int(info["frames"]) <= 1:
		pending(
			"piyade atlasında kare yok (yedek kapanış: frames=1); kare modu birim testleri D4'te"
		)
		return
	var frames := int(info["frames"])
	var base := float(info["cell"])
	var id := _spawn(w, PIYADE, Vector2(600, 0))
	var i := EnemyPool.index_of(id)
	w.r.refresh()
	var f0: float = _inst(w, 0)["cell"]
	for k in 20:
		w.sim.time += 0.1
		w.r.refresh()
		assert_eq(_inst(w, 0)["cell"], f0, "konum değişmeyen düşman: faz ilerlemez")
	var cycle := 72.0
	var steps := 0
	var last_frame := int(f0 - base)
	var advanced := 0
	for k in 30:
		w.sim.enemies.pos[i] += Vector2(cycle / float(frames), 0.0)  # tam bir kare mesafesi
		w.r.refresh()
		var f := int(_inst(w, 0)["cell"] - base)
		advanced += (f - last_frame + frames) % frames
		last_frame = f
		steps += 1
	assert_almost_eq(
		float(advanced) / float(steps), 1.0, 0.1, "bir kare mesafe = bir kare ilerleme"
	)
	var before := last_frame
	w.sim.enemies.pos[i] += Vector2(500, 0)  # ışınlanma
	w.r.refresh()
	var jump := (int(_inst(w, 0)["cell"] - base) - before + frames) % frames
	var clamp_frames := ceili(60.0 / cycle * float(frames))
	assert_lte(jump, clamp_frames, "ışınlanma 60 px üst sınırından fazla ilerletmez")


# --- A20 ------------------------------------------------------------------------------------------------------


class DustSpy:
	extends FxRenderer
	var dust: int = 0

	func add_particle(kind: StringName, pos: Vector2, vel: Vector2, life: float) -> void:
		if kind == &"dust":
			dust += 1
		super(kind, pos, vel, life)


func test_a20_elite_step_dust_is_at_most_4_per_second() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(14)
	var spy := DustSpy.new()
	add_child_autofree(spy)
	spy.bind(w.sim)
	var cam := CameraRig.new()
	add_child_autofree(cam)
	w.r.set_effects(spy, cam)
	var id := _spawn(w, &"elit_piyade", Vector2(300, 0))
	var i := EnemyPool.index_of(id)
	for k in 600:
		w.sim.time += 1.0 / 60.0
		w.sim.enemies.pos[i] += Vector2(-110.0 / 60.0, 0.0)
		w.r.refresh()
		spy.update_fx(1.0 / 60.0)
	assert_gt(spy.dust, 0, "elit yürürken adım tozu verir")
	assert_lte(spy.dust, 4 * 10 + 1, "10 sn'de en çok 40 toz (global <= 4/sn)")
	var many := _world(15)
	var spy2 := DustSpy.new()
	add_child_autofree(spy2)
	spy2.bind(many.sim)
	var cam2 := CameraRig.new()
	add_child_autofree(cam2)
	many.r.set_effects(spy2, cam2)
	var ids: Array[int] = []
	for k in 6:
		ids.append(_spawn(many, &"elit_piyade", Vector2(300.0 + 120.0 * k, 0)))
	for k in 300:
		many.sim.time += 1.0 / 60.0
		for id2 in ids:
			many.sim.enemies.pos[EnemyPool.index_of(id2)] += Vector2(-110.0 / 60.0, 0.0)
		many.r.refresh()
	assert_lte(spy2.dust, 4 * 5 + 1, "6 elit birlikte: global üst sınır 4/sn")


# --- A21 ------------------------------------------------------------------------------------------------------


func _sy(w: World, n: int, type_id: StringName) -> float:
	return _inst(w, n)["y"].length() / _quad(w, type_id).y


func test_a21_lord_summon_telegraph_raises_sy_to_1_10_below_0_6_s() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(16)
	var id := _spawn(w, &"kale_lordu", Vector2(500, 0))
	var i := EnemyPool.index_of(id)
	w.sim.time = 20.0
	w.sim.enemies.ai_timer[i] = 5.0
	w.r.refresh()
	assert_almost_eq(_sy(w, 0, &"kale_lordu"), 1.0, 0.03, "çağırma yokken sy ~1")
	w.sim.enemies.ai_timer[i] = 0.5
	w.r.refresh()
	assert_almost_eq(_sy(w, 0, &"kale_lordu"), 1.10, 0.03, "ai_timer < 0,6: sy 1,10")


func test_a21_lord_rage_sequence_plays_once_when_ai_aux_first_seen() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(17)
	var id := _spawn(w, &"kale_lordu", Vector2(500, 0))
	var i := EnemyPool.index_of(id)
	w.sim.time = 30.0
	w.sim.enemies.ai_timer[i] = 9.0
	w.r.refresh()
	w.sim.enemies.ai_aux[i] = 1.0
	var early := 0.0
	var late := 0.0
	for k in 80:
		w.r.refresh()
		var s := _sy(w, 0, &"kale_lordu")
		if k * 0.05 <= 0.9:
			early = maxf(early, s)
		elif k * 0.05 >= 1.1:
			late = maxf(late, s)
		w.sim.time += 0.05
	assert_gte(early, 1.12, "öfke dizisi 900 ms içinde sy ~1,15 nabzı")
	assert_lte(late, 1.05, "dizi bir kez oynar (ai_aux kalıcı olsa da tekrar etmez)")


# --- A22 / A23 ------------------------------------------------------------------------------------------------


func test_a22_view_refresh_never_changes_sim_state() -> void:
	if V11Slice.require(self, "D1"):
		return
	var plain := SimKit.make(21, {"data_kind": "real", "log_events": false, "pickups": false})
	var viewed := SimKit.make(21, {"data_kind": "real", "log_events": false, "pickups": false})
	SimKit.godmode(plain)
	SimKit.godmode(viewed)
	var r := EnemyRenderer.new()
	add_child_autofree(r)
	r.bind(viewed)
	var g := AshGhostRenderer.new()
	add_child_autofree(g)
	g.bind(viewed, r)
	var pv := PlayerView.new()
	add_child_autofree(pv)
	pv.bind(viewed)
	var rng_a := Bots.make_rng(21)
	var rng_b := Bots.make_rng(21)
	var mismatches := 0
	for seg in 6:
		Bots.play(plain, Bots.KITE, 100, rng_a)
		for i in 100:
			if viewed.state == GameSim.State.LEVEL_UP:
				Bots.choose(viewed, rng_b)
			viewed.step(Bots.move(Bots.KITE, viewed))
			r.refresh()
			g.update_ghosts(1.0 / 60.0)
			pv.update_view(1.0 / 60.0)
		if viewed.state == GameSim.State.LEVEL_UP:
			Bots.choose(viewed, rng_b)
		if plain.step_count == viewed.step_count and plain.state_hash() != viewed.state_hash():
			mismatches += 1
	assert_eq(mismatches, 0, "görünüm yenilemesi sim state_hash'ini değiştirmez")
	assert_eq(plain.enemies.flash, viewed.enemies.flash, "flash dizisi aynı")
	assert_eq(plain.enemies.ai_timer, viewed.enemies.ai_timer)
	assert_eq(plain.enemies.ai_aux, viewed.enemies.ai_aux)


func test_a23_work_counters_stay_within_alive_count_for_400_enemies() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(22)
	var made := w.sim.debug_fill(PIYADE, 400, 900.0)
	assert_eq(made, 400)
	w.sim.time = 9.0
	w.r.refresh()
	var alive := _alive_idx(w).size()
	assert_eq(alive, 400)
	assert_lte(w.r.last_anim_instances, alive, "last_anim_instances <= canlı")
	assert_lte(w.r.last_frame_selects, alive, "last_frame_selects <= canlı")
	assert_eq(w.r.last_shadow_instances, alive, "last_shadow_instances == canlı")
	assert_gt(w.r.last_anim_instances, 0, "animasyon gerçekten çalıştı")
	assert_eq(w.r.multimesh.visible_instance_count, alive)


func test_a23_counters_reset_each_refresh_and_follow_alive() -> void:
	if V11Slice.require(self, "D1"):
		return
	var w := _world(23)
	w.sim.debug_fill(PIYADE, 50, 800.0)
	w.r.refresh()
	assert_eq(w.r.last_shadow_instances, 50)
	for id in w.sim.alive_ids().slice(0, 20):
		w.sim.damage_enemy(id, 1.0e12, &"bullet")
	w.r.refresh()
	assert_eq(w.r.last_shadow_instances, 30)
	assert_lte(w.r.last_anim_instances, 30)
