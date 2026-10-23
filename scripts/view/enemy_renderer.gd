class_name EnemyRenderer
extends MultiMeshInstance2D
## Tüm düşmanlar için TEK MultiMeshInstance2D. Kare başına tek `multimesh.buffer` yazımı;
## kalıcı PackedFloat32Array'a doğrudan indeks yazılır; visible_instance_count = canlı sayı.
## Örnek düzeni (2B + renk + özel veri): 8 dönüşüm + 4 renk + 4 custom = 16 float.
## Vurulma parlaması INSTANCE_CUSTOM.r'de (shader: assets/shaders/enemy_flash.gdshader).

const STRIDE := 16
const SHADER_PATH := "res://assets/shaders/enemy_flash.gdshader"
const DEFAULT_HEIGHT := 110.0
const RIM_SCREEN_PX := 2.2
## Taban düşman kontur rengi (shader varsayılanıyla aynı; zeminden >= 3:1 testlidir).
const RIM_COLOR := Color(0.74, 0.64, 0.47)  # ekranda hedef kontur kalınlığı
const RIM_ELITE_SCREEN_PX := 3.6
const ANIM_FPS := 9.0  # çok kareli sprite (kargalar) kanat hızı

var atlas: EnemyAtlas = null

var _sim: GameSim = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _scale_by_type: PackedFloat32Array = PackedFloat32Array()
var _quad_by_type: PackedVector2Array = PackedVector2Array()
var _tint_by_type: PackedColorArray = PackedColorArray()
var _cell_by_type: PackedInt32Array = PackedInt32Array()
var _frames_by_type: PackedInt32Array = PackedInt32Array()
var _rim_by_type: PackedFloat32Array = PackedFloat32Array()
var _elite_by_type: PackedFloat32Array = PackedFloat32Array()
var _cap: int = EnemyPool.CAP


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
	if sim == null or sim.data == null:
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
		_tint_by_type.append(tint)
		_cell_by_type.append(cell)
		_frames_by_type.append(frames)
		_elite_by_type.append(elite)
		var want := RIM_ELITE_SCREEN_PX if elite > 0.0 else RIM_SCREEN_PX
		_rim_by_type.append(clampf(want / world_per_texel, 2.0, 14.0))


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
	var anim_t := _sim.time * ANIM_FPS
	var ntypes := _scale_by_type.size()
	var n := 0
	for i in EnemyPool.CAP:
		if alive[i] != 1:
			continue
		var t := tidx[i]
		var q := Vector2(100.0, 100.0)
		var c := Color.WHITE
		var cell := 0.0
		var rim := 0.0
		var elite := 0.0
		if t >= 0 and t < ntypes:
			q = _quad_by_type[t]
			c = _tint_by_type[t]
			cell = float(_cell_by_type[t])
			var fr := _frames_by_type[t]
			if fr > 1:
				cell += float((int(anim_t) + i) % fr)
			rim = _rim_by_type[t]
			elite = _elite_by_type[t]
		var p := pos[i]
		var sx := -q.x if player_x < p.x else q.x  # oyuncuya bak
		var o := n * STRIDE
		_buf[o] = sx
		_buf[o + 1] = 0.0
		_buf[o + 2] = 0.0
		_buf[o + 3] = p.x
		_buf[o + 4] = 0.0
		_buf[o + 5] = q.y
		_buf[o + 6] = 0.0
		_buf[o + 7] = p.y
		_buf[o + 8] = c.r
		_buf[o + 9] = c.g
		_buf[o + 10] = c.b
		_buf[o + 11] = c.a
		_buf[o + 12] = flash[i]
		_buf[o + 13] = cell
		_buf[o + 14] = rim
		_buf[o + 15] = elite
		n += 1
	multimesh.buffer = _buf
	multimesh.visible_instance_count = n


## Kesme dikdörtgeni düzeltmesini (RenderFix) uygular; ayar değişince yeniden çağrılır.
func apply_cull_fix() -> void:
	RenderFix.apply(self)


func visible_count() -> int:
	return multimesh.visible_instance_count
