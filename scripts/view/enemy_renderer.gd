class_name EnemyRenderer
extends MultiMeshInstance2D
## Tüm düşmanlar için TEK MultiMeshInstance2D. Kare başına tek `multimesh.buffer` yazımı;
## kalıcı PackedFloat32Array'a doğrudan indeks yazılır; visible_instance_count = canlı sayı.
## Örnek düzeni (2B + renk + özel veri): 8 dönüşüm + 4 renk + 4 custom = 16 float.
## Vurulma parlaması INSTANCE_CUSTOM.r'de (shader: assets/shaders/enemy_flash.gdshader).

const STRIDE := 16
const SHADER_PATH := "res://assets/shaders/enemy_flash.gdshader"
const DEFAULT_HEIGHT := 110.0
const RIM_SCREEN_PX := 1.5
## Taban düşman kontur rengi (shader varsayılanıyla aynı; zeminden >= 3:1 testlidir).
const RIM_COLOR := Color(0.74, 0.64, 0.47)  # ekranda hedef kontur kalınlığı
const RIM_ELITE_SCREEN_PX := 2.5
const SHADOW_W := 0.8  # gölge genişliği / sprite genişliği
const SHADOW_H := 0.2  # gölge yüksekliği / gölge genişliği
const SHADOW_FLY_SCALE := 0.15  # yükseldikçe en çok %15 küçülür
const SHADOW_FLY_ALPHA := 0.30  # ve en çok %30 soluklaşır
const CHARGE_PREP := 0.35  # elit karga şarj hazırlığı (E4b): ai_timer < 0,35
const LORD_PREP := 0.6  # Lord çağırma ön hazırlığı (E8): ai_timer < 0,6
const ENRAGE_PULSE := 0.9  # E9 dizisi süresi (sn)
const SLAM_TIME := 0.12  # vuruş: sy 0,88 / sx 1,10
const ENRAGE_TINT := Color("#E0584F")
const DUST_GAP := 0.25  # elit/Lord adım tozu küresel üst sınırı: 4/sn
const SHAKE_RANGE := 400.0
const SHAKE_ELITE := 1.5
const SHAKE_LORD := 3.0

## Lord ÖFKE eşiğini geçtiği ilk karede (E9): kamera 16 px, vuruş donması 80 ms denetleyicide.
signal lord_enraged(pos: Vector2)
## Lord çağırma vuruşu (E8): ai_timer yeniden kurulduğu kare. Denetleyici halka + kamera 10 px verir.
signal lord_slammed(pos: Vector2)

var atlas: EnemyAtlas = null
var anim: EnemyAnim = EnemyAnim.new()
## v1.1 iş sayaçları (gate: last_anim_instances / last_frame_selects <= canlı, last_shadow_instances == canlı).
var last_anim_instances: int = 0
var last_frame_selects: int = 0
var last_shadow_instances: int = 0
var shadows: EnemyShadowLayer = null

var _sim: GameSim = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _sbuf: PackedFloat32Array = PackedFloat32Array()
var _scale_by_type: PackedFloat32Array = PackedFloat32Array()
var _quad_by_type: PackedVector2Array = PackedVector2Array()
var _tint_by_type: PackedColorArray = PackedColorArray()
var _cell_by_type: PackedInt32Array = PackedInt32Array()
var _frames_by_type: PackedInt32Array = PackedInt32Array()
var _rim_by_type: PackedFloat32Array = PackedFloat32Array()
var _elite_by_type: PackedFloat32Array = PackedFloat32Array()
var _sprite_w_by_type: PackedFloat32Array = PackedFloat32Array()
var _cap: int = EnemyPool.CAP
var _fx: FxRenderer = null
var _camera: CameraRig = null
var _ghosts: AshGhostRenderer = null
var _last_dust: float = -10.0


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = PlaceholderArt.quad_mesh(Vector2.ONE)  # birim dörtgen; boyut örnek dönüşümünde (tür başına)
	mm.instance_count = _cap
	mm.visible_instance_count = 0
	multimesh = mm
	texture = PlaceholderArt.enemy_texture()
	_buf.resize(_cap * STRIDE)
	_sbuf.resize(_cap * EnemyShadowLayer.STRIDE)
	apply_cull_fix()
	if ResourceLoader.exists(SHADER_PATH):
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER_PATH)
		material = mat


## Sim'e bağlan; atlası ve tür başına tabloları önceden kur (hot path'te sözlük yok).
func bind(sim: GameSim) -> void:
	_sim = sim
	_scale_by_type.clear()
	_quad_by_type.clear()
	_tint_by_type.clear()
	_cell_by_type.clear()
	_frames_by_type.clear()
	_rim_by_type.clear()
	_elite_by_type.clear()
	_sprite_w_by_type.clear()
	last_anim_instances = 0
	last_frame_selects = 0
	last_shadow_instances = 0
	_last_dust = -10.0
	if sim == null or sim.data == null:
		anim.bind(null, null)
		return
	var paths: Array[String] = []
	for type_id in sim.data.enemy_ids:
		var def: EnemyDef = sim.data.get_enemy(type_id)
		if def != null and not paths.has(def.sprite):
			paths.append(def.sprite)
	atlas = EnemyAtlas.new().build(paths)
	texture = atlas.texture
	if material is ShaderMaterial:
		var rects: Array = []
		for i in 16:
			rects.append(atlas.rects[i] if i < atlas.rects.size() else Vector4.ZERO)
		(material as ShaderMaterial).set_shader_parameter("cell_rect", rects)
		(material as ShaderMaterial).set_shader_parameter("atlas_tex", atlas.texture)
	for type_id in sim.data.enemy_ids:
		var def: EnemyDef = sim.data.get_enemy(type_id)
		var h := DEFAULT_HEIGHT
		var tint := Color.WHITE
		var cell := 0
		var frames := 1
		var sprite_h := float(EnemyAtlas.CELL) * 0.5
		var sprite_w := sprite_h
		var elite := 0.0
		if def != null:
			h = maxf(def.display_height, def.radius * 2.2)
			tint = def.tint
			elite = 1.0 if (def.ai == &"elite" or def.ai == &"lord") else 0.0
			var info: Dictionary = atlas.cells.get(def.sprite, {})
			cell = int(info.get("cell", 0))
			frames = int(info.get("frames", 1))
			var sz: Vector2 = info.get("size", Vector2(sprite_h, sprite_h))
			sprite_w = sz.x
			sprite_h = sz.y
		var world_per_texel := h / maxf(sprite_h, 1.0)
		_scale_by_type.append(world_per_texel)
		var tight := (
			Vector2(sprite_w, sprite_h) + Vector2(2 * EnemyAtlas.MARGIN, 2 * EnemyAtlas.MARGIN)
		)
		_quad_by_type.append(tight * world_per_texel)
		_sprite_w_by_type.append(sprite_w * world_per_texel)
		_tint_by_type.append(tint)
		_cell_by_type.append(cell)
		_frames_by_type.append(frames)
		_elite_by_type.append(elite)
		var want := RIM_ELITE_SCREEN_PX if elite > 0.0 else RIM_SCREEN_PX
		_rim_by_type.append(clampf(want / world_per_texel, 1.0, 14.0))
	anim.bind(sim.data, atlas)


## Elit/Lord adım tozu ve kamera titreşimi için efekt hedefleri (isteğe bağlı).
func set_effects(fx: FxRenderer, camera: CameraRig) -> void:
	_fx = fx
	_camera = camera


## Tür başına dörtgen boyutu (dünya px; sprite + kontur payı).
func quad_size(t: int) -> Vector2:
	return _quad_by_type[t] if t >= 0 and t < _quad_by_type.size() else Vector2(100.0, 100.0)


## Tür başına sprite genişliği (dünya px; paysız) — gölge genişliği buna göre.
func sprite_world_width(t: int) -> float:
	return _sprite_w_by_type[t] if t >= 0 and t < _sprite_w_by_type.size() else 100.0


## Kare başına bir kez: canlıları tara, hareketi dönüşüme yaz, gölgeyi aynı döngüde yaz, tek buffer ataması yap.
func refresh() -> void:
	if _sim == null:
		multimesh.visible_instance_count = 0
		last_anim_instances = 0
		last_frame_selects = 0
		last_shadow_instances = 0
		if shadows != null:
			shadows.write(_sbuf, 0)
		return
	var pool := _sim.enemies
	var alive := pool.alive
	var pos := pool.pos
	var tidx := pool.type_idx
	var flash := pool.flash
	var gens := pool.gen
	var ai_timer := pool.ai_timer
	var ai_aux := pool.ai_aux
	var ppos := _sim.player_pos
	var time := _sim.time
	var an := anim
	var ntypes := _scale_by_type.size()
	var n := 0
	var anim_n := 0
	var sel_n := 0
	if time < _last_dust:
		_last_dust = -10.0
	for i in EnemyPool.CAP:
		if alive[i] != 1:
			continue
		var t := tidx[i]
		var q := Vector2(100.0, 100.0)
		var c := Color.WHITE
		var cell := 0.0
		var rim := 0.0
		var elite := 0.0
		var sprite_w := 100.0
		var frames := 1
		if t >= 0 and t < ntypes:
			q = _quad_by_type[t]
			c = _tint_by_type[t]
			cell = float(_cell_by_type[t])
			frames = _frames_by_type[t]
			rim = _rim_by_type[t]
			elite = _elite_by_type[t]
			sprite_w = _sprite_w_by_type[t]
		else:
			t = -1
		var p := pos[i]
		if an.gen_seen[i] != gens[i]:
			an.sync_slot(i, gens[i], p)
		var p0 := an.phase0[i]
		var dirx := -1.0 if ppos.x < p.x else 1.0  # oyuncuya bak
		var kind := an.kind_of(t)
		var theta := 0.0
		var sxm := 1.0
		var sym := 1.0
		var sym_pose := 1.0
		var bob := 0.0
		var hover := 0.0
		var framed_walk := false
		if kind != EnemyAnim.Kind.NONE:
			anim_n += 1
			if kind == EnemyAnim.Kind.CRAWL and frames > 1:
				# kare modu: kare ayak/dikey hareketi taşır (bob/θ/squash 0); mesafe tabanlı faz, kayma yok
				framed_walk = true
				an.advance_walk(i, p, an.cycle_t[t])
				cell += float(WalkCycle.frame_at(an.walk[i], frames))
				sel_n += 1
			else:
				var pose := EnemyAnim.pose_of(
					kind, an.hz_t[t], an.bob_t[t], an.rot_t[t], an.sq_t[t], time, p0
				)
				theta = pose.x
				sxm = pose.y
				sym = pose.z
				bob = pose.w
				if kind == EnemyAnim.Kind.FLAP and frames > 1:
					cell += float(EnemyAnim.flap_frame(frames, time, p0))
					sel_n += 1
			theta += an.lean_t[t] * dirx
			hover = an.hover_t[t]
			var lo := an.alpha_lo_t[t]
			if lo < 1.0:
				c.a = lerpf(lo, an.alpha_hi_t[t], 0.5 + 0.5 * EnemyAnim.lut_sin(0.35 * time + p0))
		sym_pose = sym
		# vurulma (E5): dışa itme knock·flash², squash 1 ± k·flash (hacim korunur), karga dönmesi
		var ox := 0.0
		var oy := 0.0
		var f := flash[i]
		if f > 0.0 and t >= 0:
			var away := p - ppos
			var l2 := away.length_squared()
			if l2 > 1.0:
				var k := an.knock_t[t] * f * f / sqrt(l2)
				ox = away.x * k
				oy = away.y * k
			var hs := 1.0 + an.hit_sq_t[t] * f
			sxm *= hs
			sym /= hs
			theta += an.hit_rot_t[t] * f * (1.0 if away.x >= 0.0 else -1.0)
		if elite > 0.0 and t >= 0:
			var sp := an.special_of(t)
			if sp == EnemyAnim.Special.CHARGER:
				if ai_aux[i] > 0.0:
					sxm *= 1.25
				elif ai_timer[i] < CHARGE_PREP:
					sxm *= 0.9
					theta -= deg_to_rad(10.0) * dirx
					c = Color(minf(c.r * 1.3, 1.0), minf(c.g * 1.3, 1.0), minf(c.b * 1.3, 1.0), c.a)
			elif sp == EnemyAnim.Special.LORD:
				var prev := an.timer_seen[i]
				an.timer_seen[i] = ai_timer[i]
				if prev < INF and ai_timer[i] > prev + 0.5:  # ai_timer yeniden kuruldu: çağırma vuruşu
					an.slam_t0[i] = time
					lord_slammed.emit(p)
				var since := time - an.slam_t0[i]  # float32 depolama: küçük negatif sapma sayılır
				if since > -0.001 and since < SLAM_TIME:
					sym *= 0.88
					sxm *= 1.10
				elif ai_timer[i] < LORD_PREP:
					sym *= 1.10
					theta -= deg_to_rad(6.0) * dirx
				if ai_aux[i] > 0.0:
					sym *= _enrage_pulse(i, p, time)
					c = ENRAGE_TINT
			if kind == EnemyAnim.Kind.CRAWL or kind == EnemyAnim.Kind.STOMP:
				_elite_step(i, t, p, time, ppos, sp == EnemyAnim.Special.LORD)
		var foot := q.y * 0.5
		var cs := 1.0 - theta * theta * 0.5  # |θ| <= 15°: sin≈θ, cos≈1−θ²/2 (hata < %1)
		var qx := q.x * sxm * dirx
		var qy := q.y * sym
		var o := n * STRIDE
		_buf[o] = qx * cs
		_buf[o + 1] = -qy * theta
		_buf[o + 2] = 0.0
		# x kayması vuruş squash'ından bağımsız (itme yalnız `ox`; foot·θ terimi ~0,5 px, görünmez)
		_buf[o + 3] = p.x + foot * sym_pose * theta + ox
		_buf[o + 4] = qx * theta
		_buf[o + 5] = qy * cs
		_buf[o + 6] = 0.0
		_buf[o + 7] = p.y + foot - foot * sym * cs - bob + oy
		_buf[o + 8] = c.r
		_buf[o + 9] = c.g
		_buf[o + 10] = c.b
		_buf[o + 11] = c.a
		_buf[o + 12] = f
		_buf[o + 13] = cell
		_buf[o + 14] = rim
		_buf[o + 15] = elite
		# gölge (E0): aynı döngüde; uçan türde sabit zeminde, yükseldikçe küçülür/solar
		var sw := sprite_w * SHADOW_W
		var sa := EnemyShadowLayer.SHADOW_ALPHA
		var gy := p.y + foot
		if hover > 0.0 and not framed_walk:
			var h01 := clampf(0.5 + 0.5 * bob / maxf(an.bob_t[t], 1.0), 0.0, 1.0)
			sw *= 1.0 - SHADOW_FLY_SCALE * h01
			sa *= 1.0 - SHADOW_FLY_ALPHA * h01
			gy += hover
		var so := n * EnemyShadowLayer.STRIDE
		_sbuf[so] = sw
		_sbuf[so + 1] = 0.0
		_sbuf[so + 2] = 0.0
		_sbuf[so + 3] = p.x
		_sbuf[so + 4] = 0.0
		_sbuf[so + 5] = sw * SHADOW_H
		_sbuf[so + 6] = 0.0
		_sbuf[so + 7] = gy
		_sbuf[so + 8] = 0.0
		_sbuf[so + 9] = 0.0
		_sbuf[so + 10] = 0.0
		_sbuf[so + 11] = sa
		n += 1
	multimesh.buffer = _buf
	multimesh.visible_instance_count = n
	last_anim_instances = anim_n
	last_frame_selects = sel_n
	last_shadow_instances = n
	an.last_anim_instances = anim_n
	an.last_frame_selects = sel_n
	if shadows != null:
		shadows.write(_sbuf, n)


## Lord ÖFKE dizisi (E9): ilk görüldüğü karede `lord_enraged`; 900 ms'de iki nabız (sy ×1,15, 350 ms).
func _enrage_pulse(i: int, p: Vector2, time: float) -> float:
	if anim.enrage_t0[i] < 0.0:
		anim.enrage_t0[i] = time
		lord_enraged.emit(p)
	var u := maxf(time - anim.enrage_t0[i], 0.0)
	if u >= ENRAGE_PULSE:
		return 1.0
	var w := fposmod(u, 0.45) / 0.35  # iki nabız: 0-350 ms, 450-800 ms
	return 1.0 + 0.15 * sin(PI * w) if w <= 1.0 else 1.0


## Elit/Lord adım teması (faz sarması): toz (küresel <= 4/sn) ve yakında kamera titreşimi (yalnız ≤6 örnek).
func _elite_step(i: int, t: int, p: Vector2, time: float, ppos: Vector2, lord: bool) -> void:
	var f := anim.hz_t[t] * EnemyAnim.speed_mult(anim.phase0[i]) * time + anim.phase0[i]
	var step := floori(2.0 * f)
	if step == anim.step_seen[i]:
		return
	anim.step_seen[i] = step
	if _fx == null or time - _last_dust < DUST_GAP:
		return
	_last_dust = time
	var foot := Vector2(p.x, p.y + _quad_by_type[t].y * 0.5)
	_fx.add_particle(&"dust", foot, Vector2(0.0, -30.0), 0.5)
	if _camera != null and p.distance_to(ppos) < SHAKE_RANGE:
		_camera.shake(SHAKE_LORD if lord else SHAKE_ELITE)


## Kesme dikdörtgeni düzeltmesini (RenderFix) uygular; ayar değişince yeniden çağrılır.
func apply_cull_fix() -> void:
	RenderFix.apply(self)
	if shadows != null:
		shadows.apply_cull_fix()


func visible_count() -> int:
	return multimesh.visible_instance_count


## Ölüm hayaleti renderer'ını bağlar (EnemyAnim/AshGhostRenderer ilişkisi).
func set_ghosts(g: AshGhostRenderer) -> void:
	_ghosts = g
