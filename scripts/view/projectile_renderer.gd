class_name ProjectileRenderer
extends MultiMeshInstance2D
## Tüm mermiler için TEK MultiMeshInstance2D (havuz kompakt: 0..count-1). Kare başına tek buffer yazımı.
## Örnek düzeni: 8 dönüşüm + 4 renk = 12 float. Yön = hız vektörü; renk bayraklardan.
## Rüzgar mermileri (FLAG_WIND) doku türüne göre (ZyfenFx.projectile_kind) kendi çocuk MultiMesh katmanında çizilir; dokular
## sağa bakar ve mermi yönüne döndürülür. Doku yoksa mermi ana (kod dokulu) katmanda kalır. v2 (katmanlı): gövdenin
## arkasında iz şeridi (kesik_iz/ay_oragi_iz), önünde vurgular (parilti, mizrak_uc, kesik_kirilma) ve çıkışta gok_isik
## sütunu ayrı katmanlarda çizilir; hepsi mermi durumunun ve sim zamanının saf fonksiyonudur (sim'e yazılmaz).

const STRIDE := 12
const LENGTH := 44.0
const THICKNESS := 16.0
const COLOR_BASIC := Color(1.0, 0.93, 0.78, 1.0)
const COLOR_EXPLODES := Color("#e8a24a")
const COLOR_RICOCHET := Color("#d2b47e")
const COLOR_RADIAL := Color("#cfc4ae")
## Rüzgar kesiği (hilal): soluk gök mavisi; ölçek çarpışma yarıçapından (yarıçap DEFAULT_RADIUS iken 1).
const COLOR_WIND := Color(0.72, 0.9, 1.0, 0.85)

## Animasyon sabitleri (görünüm; ekran görüntüsüyle ayarlanır).
const BLADE_SPIN := 19.0  ## Hava Bıçağı kendi ekseninde dönüş hızı (rad/sn)
const PULSE_FAST := 16.0  ## Kesik titreşimi
const PULSE_MOON := 6.0  ## Ay Orağı nabzı
const SPARKLE_RATE := 8.0  ## parilti yanıp sönme hızı
## İz uzunluğu (gövde genişliğine oranı) ve gövdeye göre kaydırma (gövde genişliği payı).
const TRAIL_KESIK := 2.0
const TRAIL_BLADE := 1.35
const TRAIL_MOON := 2.2
const TRAIL_GAP := 0.1
## iz/ışık dokularının görünür içeriğinin sağ ucu (doku genişliği oranı): uç mermiye değsin.
const TRAIL_END_KESIK := 0.90
const TRAIL_END_MOON := 0.83
## Ay Orağı yıldız parıltısının doku içindeki yeri (genişlik/yükseklik oranı; kaynak kare).
const MOON_STAR := Vector2(0.84, 0.34)
## Mızrak ucu şok konisi: gövde genişliğine oran, gövde merkezinden öteleme, isabette büyüme ve sönme süresi.
const SPEAR_CONE := 0.55
const SPEAR_CONE_AT := 0.36
const SPEAR_HIT_BOOST := 0.75
const SPEAR_HIT_TIME := 0.16
const SPEAR_HIT_REACH := 110.0
## Göğün Mızrağı çıkış ışık sütunu: süre ve genişlik (px; doku 1:2, yükseklik 2 katı), çıkış noktasından yukarı kayma.
const BEAM_TIME := 0.35
const BEAM_WIDTH := 150.0
const BEAM_LIFT := 40.0
const SPEAR_LIFE := WindUtil.SPEAR_RANGE / WindUtil.SPEAR_SPEED
## Kesik kırılma patlaması: süre, boyut (px), eşzamanlı en çok.
const BURST_TIME := 0.28
const BURST_SIZE := 150.0
const MAX_BURSTS := 8
const MAX_PARENTS := 16
const MAX_HITS := 8

var _sim: GameSim = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _cap: int = ProjectilePool.CAP
var _main_count: int = 0
## Doku türü -> {"node": MultiMeshInstance2D, "buf": PackedFloat32Array, "n": int}
var _layers: Dictionary = {}
## Gövde katmanlarındaki örnek sayısı (iz/vurgu katmanları hariç): görünür mermi sayısı.
var _body_count: int = 0
# Kırılma patlamaları (halka tampon): konum, başlangıç zamanı (sim), açı.
var _burst_pos := PackedVector2Array()
var _burst_t0 := PackedFloat32Array()
var _burst_rot := PackedFloat32Array()
var _burst_head := 0
# Önceki karedeki bölünen ebeveynler (konum, hız): kaybolan ebeveyn = bölünme anı.
var _parent_pos := PackedVector2Array()
var _parent_vel := PackedVector2Array()
var _parent_n := 0
var _next_pos := PackedVector2Array()
var _next_vel := PackedVector2Array()
# Son isabetler (konum, zaman): mızrak ucu isabette büyür.
var _hit_pos := PackedVector2Array()
var _hit_t := PackedFloat32Array()
var _hit_head := 0


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = PlaceholderArt.quad_mesh(Vector2(LENGTH, THICKNESS))
	mm.instance_count = _cap
	mm.visible_instance_count = 0
	multimesh = mm
	texture = PlaceholderArt.bullet_texture()
	_buf.resize(_cap * STRIDE)
	apply_cull_fix()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_burst_pos.resize(MAX_BURSTS)
	_burst_t0.resize(MAX_BURSTS)
	_burst_rot.resize(MAX_BURSTS)
	_burst_t0.fill(-100.0)
	_parent_pos.resize(MAX_PARENTS)
	_parent_vel.resize(MAX_PARENTS)
	_next_pos.resize(MAX_PARENTS)
	_next_vel.resize(MAX_PARENTS)
	_hit_pos.resize(MAX_HITS)
	_hit_t.resize(MAX_HITS)
	_hit_t.fill(-100.0)
	for kind: StringName in ZyfenFx.PROJECTILE_LAYERS:
		_add_layer(kind)


func _add_layer(kind: StringName) -> void:
	var tex := ZyfenFx.texture(kind)
	if tex == null:
		return
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_2D
	m.use_colors = true
	# Birim genişlikli kare; örnek ölçeği = görünür genişlik (px) / doku dolgu oranı.
	m.mesh = PlaceholderArt.quad_mesh(
		Vector2(1.0, float(tex.get_height()) / float(tex.get_width()))
	)
	m.instance_count = _cap
	m.visible_instance_count = 0
	var node := MultiMeshInstance2D.new()
	node.name = String(kind)
	node.multimesh = m
	node.texture = tex
	node.material = _layer_material(kind)
	RenderFix.apply(node)
	add_child(node)
	var buf := PackedFloat32Array()
	buf.resize(_cap * STRIDE)
	_layers[kind] = {"node": node, "buf": buf, "n": 0}


## Harmanlama: alfa; parlak/ince olanlar additive (ekran görüntüsüyle seçildi, bkz. ZyfenFx.ADDITIVE_PROJECTILES).
func _layer_material(kind: StringName) -> Material:
	if kind == ZyfenFx.MIZRAK or kind == ZyfenFx.GOK_MIZRAGI:
		var shader := ZyfenFx.shader("wind_spear")
		if shader != null:
			var sm := ShaderMaterial.new()
			sm.shader = shader
			ZyfenFx.apply_grade(sm)
			return sm
	var mat := CanvasItemMaterial.new()
	if ZyfenFx.ADDITIVE_PROJECTILES.has(kind):
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func bind(sim: GameSim) -> void:
	if _sim != null and _sim.bus.enemy_hit.is_connected(_on_enemy_hit):
		_sim.bus.enemy_hit.disconnect(_on_enemy_hit)
	_sim = sim
	_parent_n = 0
	_burst_t0.fill(-100.0)
	_hit_t.fill(-100.0)
	if sim != null:
		sim.bus.enemy_hit.connect(_on_enemy_hit)


func _on_enemy_hit(pos: Vector2) -> void:
	_hit_pos[_hit_head] = pos
	_hit_t[_hit_head] = _sim.time
	_hit_head = (_hit_head + 1) % MAX_HITS


## Bayrak rengi (saf; test edilebilir).
static func color_for_flags(flags: int) -> Color:
	if flags & ProjectilePool.FLAG_WIND:
		return COLOR_WIND
	if flags & (ProjectilePool.FLAG_EXPLODES | ProjectilePool.FLAG_EXPLODE_ON_EXPIRE):
		return COLOR_EXPLODES
	if flags & (ProjectilePool.FLAG_RICOCHET | ProjectilePool.FLAG_EXPLODE_ON_BOUNCE):
		return COLOR_RICOCHET
	if flags & ProjectilePool.FLAG_RADIAL:
		return COLOR_RADIAL
	return COLOR_BASIC


## Çizim ölçeği: patlayıcılar 1,4; rüzgar kesiği çarpışma yarıçapıyla orantılı (görsel = çarpışma); diğerleri 1.
static func scale_for(flags: int, rad: float) -> float:
	if flags & ProjectilePool.FLAG_WIND:
		return maxf(rad, 1.0) / ProjectilePool.DEFAULT_RADIUS
	if flags & (ProjectilePool.FLAG_EXPLODES | ProjectilePool.FLAG_EXPLODE_ON_EXPIRE):
		return 1.4
	return 1.0


func refresh() -> void:
	if _sim == null:
		multimesh.visible_instance_count = 0
		_main_count = 0
		_body_count = 0
		for k: StringName in _layers:
			((_layers[k]["node"] as MultiMeshInstance2D).multimesh as MultiMesh).visible_instance_count = 0
			_layers[k]["n"] = 0
		return
	var pool := _sim.projectiles
	var count := mini(pool.count, _cap)
	var pos := pool.pos
	var vel := pool.vel
	var flags := pool.flags
	var gok := _sim.loadout.state_of(&"gogun_mizragi") != null
	var t := _sim.time
	for k: StringName in _layers:
		_layers[k]["n"] = 0
	var m := 0
	var bodies := 0
	var parents_n := 0
	for i in count:
		var v := vel[i]
		var d := v.normalized() if v.length_squared() > 0.0001 else Vector2.RIGHT
		var f := flags[i]
		if f & ProjectilePool.FLAG_WIND:
			if (f & ProjectilePool.FLAG_SPLITTER) != 0 and parents_n < MAX_PARENTS:
				_next_pos[parents_n] = pos[i]
				_next_vel[parents_n] = v
				parents_n += 1
			var kind := ZyfenFx.projectile_kind(f, pool.rad[i], v.length(), gok)
			if _layers.has(kind):
				_draw_wind(kind, pool, i, d, t)
				bodies += 1
				continue
		var c := color_for_flags(f)
		_put(_buf, m, d, scale_for(f, pool.rad[i]), pos[i], c)
		m += 1
	_track_splits(parents_n, t)
	_draw_bursts(t)
	_main_count = m
	_body_count = bodies + m
	multimesh.buffer = _buf
	multimesh.visible_instance_count = m
	for k: StringName in _layers:
		var layer: Dictionary = _layers[k]
		var lm := (layer["node"] as MultiMeshInstance2D).multimesh as MultiMesh
		lm.buffer = layer["buf"]
		lm.visible_instance_count = layer["n"]
		var mat := (layer["node"] as MultiMeshInstance2D).material
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("t", t)


## Rüzgar mermisinin gövdesi + katmanları (iz, vurgu). `d` yön, `t` sim zamanı. Faz yön açısından türer (mermi indeksi
## sıkıştırmayla değişir, faz sıçramasın).
func _draw_wind(kind: StringName, pool: ProjectilePool, i: int, d: Vector2, t: float) -> void:
	var p := pool.pos[i]
	var ang := d.angle()
	var ph := fposmod(ang * 4.0 + 1.3, TAU)
	var w: float = float(ZyfenFx.PROJECTILE_KINDS[kind]) * pool.rad[i] / ZyfenFx.TEX_FILL
	var perp := Vector2(-d.y, d.x)
	match kind:
		ZyfenFx.KESIK:
			var b := 0.86 + 0.14 * sin(t * PULSE_FAST + ph)
			_trail(ZyfenFx.KESIK_IZ, p, d, w, TRAIL_KESIK, TRAIL_END_KESIK, 0.8, t, ph)
			_push(kind, p, ang, w, w, Color(b, b, b, 1.0))
		ZyfenFx.KESIK_PARCA:
			var b2 := 0.86 + 0.14 * sin(t * PULSE_FAST + ph)
			_trail(ZyfenFx.KESIK_IZ, p, d, w, TRAIL_BLADE, TRAIL_END_KESIK, 0.6, t, ph)
			_push(kind, p, ang, w, w, Color(b2, b2, b2, 1.0))
		ZyfenFx.HAVA_BICAGI:
			_trail(ZyfenFx.KESIK_IZ, p, d, w, TRAIL_BLADE, TRAIL_END_KESIK, 0.6, t, ph)
			_push(kind, p, ang + t * BLADE_SPIN + ph, w, w, Color.WHITE)
		ZyfenFx.AY_ORAGI:
			var pulse := sin(t * PULSE_MOON + ph)
			var b3 := 0.84 + 0.16 * (0.5 + 0.5 * pulse)
			var ws := w * (1.0 + 0.035 * pulse)
			_trail(ZyfenFx.AY_ORAGI_IZ, p, d, w, TRAIL_MOON, TRAIL_END_MOON, 0.85, t, ph)
			_push(kind, p, ang, ws, ws, Color(b3, b3, b3, 1.0))
			var tex := ZyfenFx.texture(kind)
			var hh := w * (float(tex.get_height()) / float(tex.get_width()) if tex != null else 0.5)
			var star := p + d * ((MOON_STAR.x - 0.5) * w) + perp * ((MOON_STAR.y - 0.5) * hh)
			_sparkle(star, w * 0.22, t, ph)
		ZyfenFx.MIZRAK:
			_push(kind, p, ang, w, w, Color.WHITE)
			_spear_tip(p, d, w, ang, t, ph)
		ZyfenFx.GOK_MIZRAGI:
			var pulse2 := 0.5 + 0.5 * sin(t * 7.0 + ph)
			var b4 := 0.82 + 0.18 * pulse2
			var vel := pool.vel[i]
			var age := clampf(SPEAR_LIFE - pool.life[i], 0.0, 10.0)
			if age < BEAM_TIME:
				var k := 1.0 - age / BEAM_TIME
				var origin := p - vel * age
				var grow := 1.0 + 0.3 * (1.0 - k)
				_push(
					ZyfenFx.GOK_ISIK,
					origin + Vector2(0.0, -BEAM_LIFT),
					0.0,
					BEAM_WIDTH * grow,
					BEAM_WIDTH * grow,
					Color(1, 1, 1, k * k)
				)
			_push(kind, p, ang, w * (1.0 + 0.03 * pulse2), w, Color(b4, b4, b4, 1.0))
			_sparkle(p + d * (0.39 * w), w * 0.2, t, ph)


## İz şeridi: sağ ucu (içerik) gövdenin arkasına değer; uzunluk `len_k` x gövde genişliği, hafif titrer.
func _trail(
	id: StringName,
	p: Vector2,
	d: Vector2,
	body_w: float,
	len_k: float,
	end: float,
	alpha: float,
	t: float,
	ph: float
) -> void:
	var wt := body_w * len_k * (1.0 + 0.08 * sin(t * 21.0 + ph))
	var c := p - d * (TRAIL_GAP * body_w + (end - 0.5) * wt)
	_push(id, c, d.angle(), wt, wt, Color(1, 1, 1, alpha * (0.85 + 0.15 * sin(t * 13.0 + ph))))


## Yanıp sönen dört köşeli yıldız.
func _sparkle(at: Vector2, size: float, t: float, ph: float) -> void:
	var blink := absf(sin(t * SPARKLE_RATE + ph))
	var s := size * (0.3 + 0.7 * blink * blink)
	_push(ZyfenFx.PARILTI, at, t * 1.5 + ph, s, s, Color(1, 1, 1, 0.45 + 0.55 * blink))


## Mızrak ucundaki şok konisi: titrer, yakın isabette bir an büyür.
func _spear_tip(p: Vector2, d: Vector2, body_w: float, ang: float, t: float, ph: float) -> void:
	var boost := 0.0
	for h in MAX_HITS:
		var age := t - _hit_t[h]
		if (
			age >= -0.001
			and age < SPEAR_HIT_TIME
			and _hit_pos[h].distance_squared_to(p) < SPEAR_HIT_REACH * SPEAR_HIT_REACH
		):
			boost = maxf(boost, clampf(1.0 - age / SPEAR_HIT_TIME, 0.0, 1.0))
	var s := body_w * SPEAR_CONE * (1.0 + 0.07 * sin(t * 31.0 + ph) + SPEAR_HIT_BOOST * boost)
	_push(
		ZyfenFx.MIZRAK_UC,
		p + d * (SPEAR_CONE_AT * body_w),
		ang,
		s,
		s,
		Color(1, 1, 1, 0.8 + 0.2 * boost)
	)


## Katman `id` için bir örnek yazar (doku yoksa sessizce atlar). `sx` genişlik px (doku genişliği), `sy` aynı birimde dikey ölçek.
func _push(id: StringName, p: Vector2, ang: float, sx: float, sy: float, c: Color) -> void:
	if not _layers.has(id):
		return
	var layer: Dictionary = _layers[id]
	var n: int = layer["n"]
	if n >= _cap:
		return
	_put_xf(layer["buf"], n, p, ang, sx, sy, ZyfenFx.grade(c))
	layer["n"] = n + 1


## Bölünen ebeveyn kaybolduysa (isabet ya da menzil sonu) son konumunda kırılma patlaması başlatır.
func _track_splits(parents_n: int, t: float) -> void:
	for k in _parent_n:
		# Kare başına birkaç sim adımı atılabilir: eşleşme yarıçapı hızla orantılı.
		var reach := _parent_vel[k].length() * GameSim.STEP * 3.0 + 24.0
		var found := false
		for j in parents_n:
			if _next_pos[j].distance_squared_to(_parent_pos[k]) < reach * reach:
				found = true
				break
		if not found:
			_burst_pos[_burst_head] = _parent_pos[k]
			_burst_t0[_burst_head] = t
			_burst_rot[_burst_head] = fposmod(_parent_pos[k].x * 0.013, TAU)
			_burst_head = (_burst_head + 1) % MAX_BURSTS
	_parent_n = parents_n
	for j in parents_n:
		_parent_pos[j] = _next_pos[j]
		_parent_vel[j] = _next_vel[j]


func _draw_bursts(t: float) -> void:
	for b in MAX_BURSTS:
		var age := t - _burst_t0[b]
		if age < -0.001 or age >= BURST_TIME:
			continue
		var k := age / BURST_TIME
		var s := BURST_SIZE * (0.55 + 0.75 * (1.0 - (1.0 - k) * (1.0 - k)))
		_push(ZyfenFx.KESIK_KIRILMA, _burst_pos[b], _burst_rot[b], s, s, Color(1, 1, 1, 1.0 - k))


## Örnek `idx` için dönüş (yön d) x ölçek s, konum p, renk c yazar.
static func _put(
	buf: PackedFloat32Array, idx: int, d: Vector2, s: float, p: Vector2, c: Color
) -> void:
	_put_xf(buf, idx, p, d.angle(), s, s, c)


## Genel biçim: `ang` rad döndürme, x ekseni `sx`, y ekseni `sy` ölçekli (mesh dokunun en-boy oranını taşır).
static func _put_xf(
	buf: PackedFloat32Array, idx: int, p: Vector2, ang: float, sx: float, sy: float, c: Color
) -> void:
	var o := idx * STRIDE
	var cs := cos(ang)
	var sn := sin(ang)
	buf[o] = cs * sx
	buf[o + 1] = -sn * sy
	buf[o + 2] = 0.0
	buf[o + 3] = p.x
	buf[o + 4] = sn * sx
	buf[o + 5] = cs * sy
	buf[o + 6] = 0.0
	buf[o + 7] = p.y
	buf[o + 8] = c.r
	buf[o + 9] = c.g
	buf[o + 10] = c.b
	buf[o + 11] = c.a


func apply_cull_fix() -> void:
	RenderFix.apply(self)


## Görünür mermi gövdesi sayısı (ana katman + gövde dokuları; iz/vurgu katmanları sayılmaz) = canlı mermi sayısı.
func visible_count() -> int:
	return _body_count
