class_name EnemyShadowLayer
extends MultiMeshInstance2D
## Düşman yer gölgesi (soft elips) MultiMesh'i. Mantık yok; EnemyRenderer aynı refresh() döngüsünde tamponu yazar.
## Örnek düzeni: 8 dönüşüm + 4 renk = 12 float (siyah, α = gölge opaklığı). Tek çizim; katman sırasında zeminle
## taşlar arasındadır (GameController._v11_build_world).

const STRIDE := 12
const SHADOW_ALPHA := 0.38


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = PlaceholderArt.quad_mesh(Vector2.ONE)
	mm.instance_count = EnemyPool.CAP
	mm.visible_instance_count = 0
	multimesh = mm
	texture = PlaceholderArt.soft_circle(128)
	RenderFix.apply(self)


## buf: n örnek × (8 float dönüşüm + 4 renk). Boyutu `EnemyPool.CAP × STRIDE` değilse yok sayılır (n = 0).
func write(buf: PackedFloat32Array, n: int) -> void:
	if n <= 0 or buf.size() != multimesh.instance_count * STRIDE:
		multimesh.visible_instance_count = 0
		return
	multimesh.buffer = buf
	multimesh.visible_instance_count = mini(n, multimesh.instance_count)


func apply_cull_fix() -> void:
	RenderFix.apply(self)
