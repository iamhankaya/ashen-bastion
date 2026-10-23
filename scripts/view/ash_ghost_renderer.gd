class_name AshGhostRenderer
extends MultiMeshInstance2D
## Ölüm "hayalet" MultiMesh'i (havuz 64, halka tampon) + kül shader'ı (assets/shaders/ash_ghost.gdshader). `enemy_killed`
## olayını dinler; sim'i yalnız okur. Hayalet = ölen türün ilk hücresi (olay `id` taşımaz: kabul edilen sadeleştirme), ölüm
## konumunda, oyuncuya bakan yönde; ölüm türüne göre çöker/düşer/yükselir ve kül olarak dağılır. Zaman = görünüm süresi
## (`update_ghosts(dt)`; duraklatmada dt = 0, Lord yavaş çekiminde ×0,4). Tampon düzeni EnemyRenderer ile aynıdır (16 float).

const CAP := 64
## Bu kadar canlı düşmandan sonra 150 ms düz solma (LOD).
const LOD_ALIVE := 150
const LOD_LIFE := 0.15
const STRIDE := 16
const SHADER_PATH := "res://assets/shaders/ash_ghost.gdshader"
const DEFAULT_LIFE := 0.42
## Ölüm türü başına (çözülme başlangıcı, sy, sx, düşüş/yükselme px, dönme°). DataV11.ANIM_DEATHS sırası.
const DEATH_STYLE: Array[Vector4] = [
	Vector4(0.52, 0.55, 1.12, 0.0),  # collapse: 220 ms çöküş + 200 ms kül
	Vector4(0.40, 1.0, 1.0, 40.0),  # fall: 40 px düşüş + 80° dönme
	Vector4(0.15, 1.15, 1.0, -22.0),  # ash_up: yukarı akan kül
	Vector4(0.12, 1.10, 1.0, -30.0),  # ash_big
	Vector4(0.10, 1.08, 1.0, -10.0),  # lord
]
const FALL_ROT_DEG := 80.0

var _sim: GameSim = null
var _er: EnemyRenderer = null
var _buf := PackedFloat32Array()
var _g_type := PackedInt32Array()
var _g_pos := PackedVector2Array()
var _g_dir := PackedFloat32Array()
var _g_age := PackedFloat32Array()
var _g_life := PackedFloat32Array()
var _g_death := PackedInt32Array()
var _g_seed := PackedFloat32Array()
var _head := 0
var _life_by_type := PackedFloat32Array()
var _death_by_type := PackedInt32Array()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = PlaceholderArt.quad_mesh(Vector2.ONE)
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	multimesh = mm
	texture = PlaceholderArt.enemy_texture()
	_buf.resize(CAP * STRIDE)
	_g_type.resize(CAP)
	_g_pos.resize(CAP)
	_g_dir.resize(CAP)
	_g_age.resize(CAP)
	_g_life.resize(CAP)
	_g_life.fill(0.0)
	_g_age.fill(1.0)
	_g_death.resize(CAP)
	_g_seed.resize(CAP)
	_rng.seed = 5
	RenderFix.apply(self)
	if ResourceLoader.exists(SHADER_PATH):
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER_PATH)
		material = mat


## Sim'e ve düşman renderer'ına (atlas + tür tabloları) bağlanır; sim null ise bağı keser ve temizler.
func bind(sim: GameSim, enemy_renderer: EnemyRenderer) -> void:
	if _sim != null and _sim.bus.enemy_killed.is_connected(_on_enemy_killed):
		_sim.bus.enemy_killed.disconnect(_on_enemy_killed)
	_sim = sim
	_er = enemy_renderer
	_g_life.fill(0.0)
	_g_age.fill(1.0)
	_head = 0
	multimesh.visible_instance_count = 0
	_life_by_type.clear()
	_death_by_type.clear()
	if sim == null:
		return
	sim.bus.enemy_killed.connect(_on_enemy_killed)
	for type_id in sim.data.enemy_ids:
		var def: EnemyDef = sim.data.get_enemy(type_id)
		var a: Dictionary = def.anim if def != null else {}
		_life_by_type.append(float(a.get("death_ms", DEFAULT_LIFE * 1000.0)) / 1000.0)
		_death_by_type.append(maxi(DataV11.ANIM_DEATHS.find(str(a.get("death", "collapse"))), 0))
	if enemy_renderer != null and enemy_renderer.atlas != null:
		texture = enemy_renderer.atlas.texture
		if material is ShaderMaterial:
			var rects: Array = []
			for i in 16:
				var r := enemy_renderer.atlas.rects
				rects.append(r[i] if i < r.size() else Vector4.ZERO)
			(material as ShaderMaterial).set_shader_parameter("cell_rect", rects)
			(material as ShaderMaterial).set_shader_parameter(
				"atlas_tex", enemy_renderer.atlas.texture
			)


func apply_cull_fix() -> void:
	RenderFix.apply(self)


## Tür başına hayalet ömrü (sn; `anim.death_ms`).
func life_of(type_id: StringName) -> float:
	var t := _sim.data.enemy_ids.find(type_id) if _sim != null else -1
	return _life_by_type[t] if t >= 0 and t < _life_by_type.size() else DEFAULT_LIFE


## Yaşayan (süresi dolmamış) hayalet sayısı.
func ghost_count() -> int:
	var n := 0
	for i in CAP:
		if _g_age[i] < _g_life[i]:
			n += 1
	return n


## Her kare (görünüm süresiyle): yaşlandır, tamponu yaz.
func update_ghosts(dt: float) -> void:
	if _sim == null or _er == null:
		multimesh.visible_instance_count = 0
		return
	var n := 0
	for i in CAP:
		if _g_age[i] >= _g_life[i]:
			continue
		_g_age[i] += maxf(dt, 0.0)
		if _g_age[i] >= _g_life[i]:
			continue
		var u := _g_age[i] / _g_life[i]
		var t := _g_type[i]
		var q := _er.quad_size(t)
		var style := DEATH_STYLE[_g_death[i]]
		var flat := _g_seed[i] < 0.0
		var sy := 1.0
		var sx := 1.0
		var drop := 0.0
		var theta := 0.0
		if not flat:
			match _g_death[i]:
				0:
					var e := minf(u / maxf(style.x, 0.01), 1.0)
					sy = lerpf(1.0, style.y, e)
					sx = lerpf(1.0, style.z, e)
				1:
					drop = style.w * u * u
					theta = deg_to_rad(FALL_ROT_DEG) * u * -_g_dir[i]
				_:
					sy = lerpf(1.0, style.y, u)
					drop = style.w * u
		var foot := q.y * 0.5
		var p := _g_pos[i]
		var cs := cos(theta)
		var sn := sin(theta)
		var qx := q.x * sx * _g_dir[i]
		var qy := q.y * sy
		var o := n * STRIDE
		_buf[o] = qx * cs
		_buf[o + 1] = -qy * sn
		_buf[o + 2] = 0.0
		_buf[o + 3] = p.x + foot * sy * sn
		_buf[o + 4] = qx * sn
		_buf[o + 5] = qy * cs
		_buf[o + 6] = 0.0
		_buf[o + 7] = p.y + foot - foot * sy * cs + drop
		var tint := _er._tint_by_type[t] if t >= 0 and t < _er._tint_by_type.size() else Color.WHITE
		_buf[o + 8] = tint.r
		_buf[o + 9] = tint.g
		_buf[o + 10] = tint.b
		_buf[o + 11] = 0.0 if flat else style.x
		_buf[o + 12] = u
		_buf[o + 13] = float(_er.cell_of(t))
		_buf[o + 14] = _er.rim_of(t)
		_buf[o + 15] = _g_seed[i]
		n += 1
	multimesh.buffer = _buf
	multimesh.visible_instance_count = n


func _on_enemy_killed(type_id: StringName, pos: Vector2) -> void:
	if _sim == null:
		return
	var t := _sim.data.enemy_ids.find(type_id)
	if t < 0:
		return
	var i := _head
	_head = (_head + 1) % CAP  # taşarsa en eski değişir
	var lod := _sim.enemies.count > LOD_ALIVE
	_g_type[i] = t
	_g_pos[i] = pos
	_g_dir[i] = -1.0 if _sim.player_pos.x < pos.x else 1.0
	_g_age[i] = 0.0
	_g_life[i] = LOD_LIFE if lod else _life_by_type[t]
	_g_death[i] = _death_by_type[t]
	_g_seed[i] = -1.0 if lod else _rng.randf()
