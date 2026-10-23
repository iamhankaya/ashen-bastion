class_name EnemyRenderer
extends MultiMeshInstance2D
## Tüm düşmanlar için TEK MultiMeshInstance2D. Kare başına tek `multimesh.buffer` yazımı;
## kalıcı PackedFloat32Array'a doğrudan indeks yazılır; visible_instance_count = canlı sayı.
## Örnek düzeni (2B + renk + özel veri): 8 dönüşüm + 4 renk + 4 custom = 16 float.
## Vurulma parlaması INSTANCE_CUSTOM.r'de (shader: assets/shaders/enemy_flash.gdshader).

const STRIDE := 16
const SHADER_PATH := "res://assets/shaders/enemy_flash.gdshader"
const BASE_SIZE := 100.0  # dörtgen ağın kenarı; tür boyu ölçekle verilir
const DEFAULT_HEIGHT := 110.0

var _sim: GameSim = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _scale_by_type: PackedFloat32Array = PackedFloat32Array()
var _tint_by_type: PackedColorArray = PackedColorArray()
var _cap: int = EnemyPool.CAP


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = PlaceholderArt.quad_mesh(Vector2(BASE_SIZE, BASE_SIZE))
	mm.instance_count = _cap
	mm.visible_instance_count = 0
	multimesh = mm
	texture = PlaceholderArt.enemy_texture()
	_buf.resize(_cap * STRIDE)
	apply_cull_fix()
	if ResourceLoader.exists(SHADER_PATH):
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER_PATH)
		material = mat


## Sim'e bağlan; tür başına ölçek ve renk tablolarını önceden kur (hot path'te sözlük yok).
func bind(sim: GameSim) -> void:
	_sim = sim
	_scale_by_type.clear()
	_tint_by_type.clear()
	if sim == null or sim.data == null:
		return
	for type_id in sim.data.enemy_ids:
		var def: EnemyDef = sim.data.get_enemy(type_id)
		var h := DEFAULT_HEIGHT
		var tint := Color.WHITE
		if def != null:
			h = maxf(def.display_height, def.radius * 2.2)
			tint = def.tint
		_scale_by_type.append(h / BASE_SIZE)
		_tint_by_type.append(tint)


## Kare başına bir kez: canlıları tara, tampona yaz, tek buffer ataması yap.
func refresh() -> void:
	if _sim == null:
		multimesh.visible_instance_count = 0
		return
	var pool := _sim.enemies
	var alive := pool.alive
	var pos := pool.pos
	var tidx := pool.type_idx
	var flash := pool.flash
	var player_x := _sim.player_pos.x
	var ntypes := _scale_by_type.size()
	var n := 0
	for i in EnemyPool.CAP:
		if alive[i] != 1:
			continue
		var t := tidx[i]
		var s := 1.0
		var c := Color.WHITE
		if t >= 0 and t < ntypes:
			s = _scale_by_type[t]
			c = _tint_by_type[t]
		var p := pos[i]
		var sx := -s if player_x < p.x else s  # oyuncuya bak
		var o := n * STRIDE
		_buf[o] = sx
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
		_buf[o + 11] = c.a
		_buf[o + 12] = flash[i]
		_buf[o + 13] = 0.0
		_buf[o + 14] = 0.0
		_buf[o + 15] = 0.0
		n += 1
	multimesh.buffer = _buf
	multimesh.visible_instance_count = n


## Kesme dikdörtgeni düzeltmesini (RenderFix) uygular; ayar değişince yeniden çağrılır.
func apply_cull_fix() -> void:
	RenderFix.apply(self)


func visible_count() -> int:
	return multimesh.visible_instance_count
