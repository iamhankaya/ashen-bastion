class_name GemRenderer
extends MultiMeshInstance2D
## Tüm XP taşları için TEK MultiMeshInstance2D (havuz kompakt: 0..count-1). Kare başına tek buffer yazımı.
## Örnek düzeni: 8 dönüşüm + 4 renk = 12 float. Büyük değerli (birleşmiş) taş daha iri ve parlak.

const STRIDE := 12
const SIZE := 30.0
const COLOR_XP := Color("#7c5cc4")
const COLOR_XP_BRIGHT := Color("#a98bef")

var _sim: GameSim = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _cap: int = GemPool.CAP


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = PlaceholderArt.quad_mesh(Vector2(SIZE, SIZE))
	mm.instance_count = _cap
	mm.visible_instance_count = 0
	multimesh = mm
	texture = PlaceholderArt.gem_texture()
	_buf.resize(_cap * STRIDE)
	apply_cull_fix()


func bind(sim: GameSim) -> void:
	_sim = sim


## Değer → ölçek (1 → 1.0, büyüdükçe log ile, en çok 2.2).
static func scale_for_value(value: int) -> float:
	if value <= 1:
		return 1.0
	return minf(1.0 + log(float(value)) * 0.35, 2.2)


func refresh() -> void:
	if _sim == null:
		multimesh.visible_instance_count = 0
		return
	var pool := _sim.gems
	var count := mini(pool.count, _cap)
	var pos := pool.pos
	var val := pool.value
	for i in count:
		var s := scale_for_value(val[i])
		var c := COLOR_XP if val[i] <= 1 else COLOR_XP_BRIGHT
		var p := pos[i]
		var o := i * STRIDE
		_buf[o] = s
		_buf[o + 1] = 0.0
		_buf[o + 2] = 0.0
		_buf[o + 3] = p.x
		_buf[o + 4] = 0.0
		_buf[o + 5] = s
		_buf[o + 6] = 0.0
		_buf[o + 7] = p.y
		_buf[o + 8] = c.r
		_buf[o + 9] = c.g
		_buf[o + 10] = c.b
		_buf[o + 11] = 1.0
	multimesh.buffer = _buf
	multimesh.visible_instance_count = count


## Kesme dikdörtgeni düzeltmesini (RenderFix) uygular; ayar değişince yeniden çağrılır.
func apply_cull_fix() -> void:
	RenderFix.apply(self)


func visible_count() -> int:
	return multimesh.visible_instance_count
