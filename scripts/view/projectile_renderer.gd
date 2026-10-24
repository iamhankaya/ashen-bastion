class_name ProjectileRenderer
extends MultiMeshInstance2D
## Tüm mermiler için TEK MultiMeshInstance2D (havuz kompakt: 0..count-1). Kare başına tek buffer yazımı.
## Örnek düzeni: 8 dönüşüm + 4 renk = 12 float. Yön = hız vektörü; renk bayraklardan.

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
		return
	var pool := _sim.projectiles
	var count := mini(pool.count, _cap)
	var pos := pool.pos
	var vel := pool.vel
	var flags := pool.flags
	for i in count:
		var v := vel[i]
		var d := v.normalized() if v.length_squared() > 0.0001 else Vector2.RIGHT
		var f := flags[i]
		var c := color_for_flags(f)
		var s := scale_for(f, pool.rad[i])
		var p := pos[i]
		var o := i * STRIDE
		_buf[o] = d.x * s
		_buf[o + 1] = -d.y * s
		_buf[o + 2] = 0.0
		_buf[o + 3] = p.x
		_buf[o + 4] = d.y * s
		_buf[o + 5] = d.x * s
		_buf[o + 6] = 0.0
		_buf[o + 7] = p.y
		_buf[o + 8] = c.r
		_buf[o + 9] = c.g
		_buf[o + 10] = c.b
		_buf[o + 11] = c.a
	multimesh.buffer = _buf
	multimesh.visible_instance_count = count


func apply_cull_fix() -> void:
	RenderFix.apply(self)


func visible_count() -> int:
	return multimesh.visible_instance_count
