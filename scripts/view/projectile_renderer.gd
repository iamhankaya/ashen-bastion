class_name ProjectileRenderer
extends MultiMeshInstance2D
## Tüm mermiler için TEK MultiMeshInstance2D (havuz kompakt: 0..count-1). Kare başına tek buffer yazımı.
## Örnek düzeni: 8 dönüşüm + 4 renk = 12 float. Yön = hız vektörü; renk bayraklardan.
## Rüzgar mermileri (FLAG_WIND) doku türüne göre (ZyfenFx.projectile_kind) kendi çocuk MultiMesh katmanında çizilir; dokular
## sağa bakar ve mermi yönüne döndürülür. Doku yoksa mermi ana (kod dokulu) katmanda kalır.

const STRIDE := 12
const LENGTH := 44.0
const THICKNESS := 16.0
const COLOR_BASIC := Color(1.0, 0.93, 0.78, 1.0)
const COLOR_EXPLODES := Color("#e8a24a")
const COLOR_RICOCHET := Color("#d2b47e")
const COLOR_RADIAL := Color("#cfc4ae")
## Rüzgar kesiği (hilal): soluk gök mavisi; ölçek çarpışma yarıçapından (yarıçap DEFAULT_RADIUS iken 1).
const COLOR_WIND := Color(0.72, 0.9, 1.0, 0.85)

var _sim: GameSim = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _cap: int = ProjectilePool.CAP
var _main_count: int = 0
## Doku türü -> {"node": MultiMeshInstance2D, "buf": PackedFloat32Array, "n": int}
var _layers: Dictionary = {}


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
	for kind: StringName in ZyfenFx.PROJECTILE_KINDS:
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
func _layer_material(kind: StringName) -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	if ZyfenFx.ADDITIVE_PROJECTILES.has(kind):
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func bind(sim: GameSim) -> void:
	_sim = sim


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
	for k: StringName in _layers:
		_layers[k]["n"] = 0
	var m := 0
	for i in count:
		var v := vel[i]
		var d := v.normalized() if v.length_squared() > 0.0001 else Vector2.RIGHT
		var f := flags[i]
		if f & ProjectilePool.FLAG_WIND:
			var kind := ZyfenFx.projectile_kind(f, pool.rad[i], v.length(), gok)
			if _layers.has(kind):
				var layer: Dictionary = _layers[kind]
				var s: float = (
					float(ZyfenFx.PROJECTILE_KINDS[kind]) * pool.rad[i] / ZyfenFx.TEX_FILL
				)
				_put(layer["buf"], layer["n"], d, s, pos[i], Color.WHITE)
				layer["n"] += 1
				continue
		var c := color_for_flags(f)
		_put(_buf, m, d, scale_for(f, pool.rad[i]), pos[i], c)
		m += 1
	_main_count = m
	multimesh.buffer = _buf
	multimesh.visible_instance_count = m
	for k: StringName in _layers:
		var layer: Dictionary = _layers[k]
		var lm := (layer["node"] as MultiMeshInstance2D).multimesh as MultiMesh
		lm.buffer = layer["buf"]
		lm.visible_instance_count = layer["n"]


## Örnek `idx` için dönüş (yön d) x ölçek s, konum p, renk c yazar.
static func _put(
	buf: PackedFloat32Array, idx: int, d: Vector2, s: float, p: Vector2, c: Color
) -> void:
	var o := idx * STRIDE
	buf[o] = d.x * s
	buf[o + 1] = -d.y * s
	buf[o + 2] = 0.0
	buf[o + 3] = p.x
	buf[o + 4] = d.y * s
	buf[o + 5] = d.x * s
	buf[o + 6] = 0.0
	buf[o + 7] = p.y
	buf[o + 8] = c.r
	buf[o + 9] = c.g
	buf[o + 10] = c.b
	buf[o + 11] = c.a


func apply_cull_fix() -> void:
	RenderFix.apply(self)


## Görünür toplam örnek (ana katman + doku katmanları) = canlı mermi sayısı.
func visible_count() -> int:
	var n := _main_count
	for k: StringName in _layers:
		n += int(_layers[k]["n"])
	return n
