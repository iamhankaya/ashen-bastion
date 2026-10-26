class_name GemRenderer
extends MultiMeshInstance2D
## Tüm XP taşları için TEK MultiMeshInstance2D (havuz kompakt: 0..count-1). Kare başına tek buffer yazımı.
## Örnek düzeni: 8 dönüşüm + 4 renk + 4 özel veri (tip, evre, boy px) = 16 float. v2.0.3: değere göre 3 ruh küresi
## (GemTiers); doku tek atlas (3 kutu), elit/boss süzülmesi gölgelendiricide (sim konumu değişmez).

const STRIDE := 16
const SHADER := preload("res://assets/shaders/gem_orb.gdshader")
const TILE_PX := 128

var _sim: GameSim = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _cap: int = GemPool.CAP


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = PlaceholderArt.quad_mesh(Vector2.ONE)
	mm.instance_count = _cap
	mm.visible_instance_count = 0
	multimesh = mm
	texture = atlas_texture()
	material = ShaderMaterial.new()
	material.shader = SHADER
	apply_motion_setting()
	_buf.resize(_cap * STRIDE)
	apply_cull_fix()


func bind(sim: GameSim) -> void:
	_sim = sim


## GemTiers.TEXTURES -> yan yana 3 kutulu atlas; bir doku yüklenemezse yer tutucu taşa düşer.
static func atlas_texture() -> Texture2D:
	var atlas := Image.create_empty(TILE_PX * GemTiers.COUNT, TILE_PX, false, Image.FORMAT_RGBA8)
	for t in GemTiers.COUNT:
		var tex := load(GemTiers.TEXTURES[t]) as Texture2D
		if tex == null:
			return PlaceholderArt.gem_texture()
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(img, Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i(t * TILE_PX, 0))
	return ImageTexture.create_from_image(atlas)


## hareket_azalt AÇIKken küre süzülmesi durur.
func apply_motion_setting() -> void:
	(material as ShaderMaterial).set_shader_parameter("bob_scale", 0.0 if Settings.hareket_azalt else 1.0)


## Değer → ölçek (1 → 1.0, büyüdükçe log ile, en çok 2.2).
static func scale_for_value(value: int) -> float:
	if value <= 1:
		return 1.0
	return minf(1.0 + log(float(value)) * 0.35, 2.2)


func refresh() -> void:
	apply_motion_setting()
	if _sim == null:
		multimesh.visible_instance_count = 0
		return
	var pool := _sim.gems
	var count := mini(pool.count, _cap)
	var pos := pool.pos
	var val := pool.value
	for i in count:
		var tier := GemTiers.tier_of(val[i])
		var s := float(GemTiers.ORB_PX[tier])
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
		_buf[o + 8] = 1.0
		_buf[o + 9] = 1.0
		_buf[o + 10] = 1.0
		_buf[o + 11] = 1.0
		_buf[o + 12] = float(tier)
		_buf[o + 13] = fposmod(float(i) * 0.381966, 1.0)
		_buf[o + 14] = s
		_buf[o + 15] = 0.0
	multimesh.buffer = _buf
	multimesh.visible_instance_count = count


## Kesme dikdörtgeni düzeltmesini (RenderFix) uygular; ayar değişince yeniden çağrılır.
func apply_cull_fix() -> void:
	RenderFix.apply(self)


func visible_count() -> int:
	return multimesh.visible_instance_count
