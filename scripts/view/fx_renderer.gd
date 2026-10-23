class_name FxRenderer
extends Node2D
## Dünya uzayı efektleri (yalnız görsel; sim'i okur, hiçbir sim durumunu değiştirmez): patlama halkası + parlama,
## keskin nişan çizgisi, XP toplama kıvılcımı, ölüm tozu. Hepsi sabit boyutlu halka tamponlarda (sıcak yolda tahsis yok);
## ek (additive) karışımla çizilir. SimBus + SimFx sinyallerine bağlanır.

const MAX_EXPLOSIONS := 24
const MAX_BEAMS := 4
const MAX_PUFFS := 64
const MAX_SPARKS := 16
const EXPLOSION_TIME := 0.38
const BEAM_TIME := 0.18
const PUFF_TIME := 0.45
const SPARK_TIME := 0.28
const SHAKE_MIN_RADIUS := 150.0

var _sim: GameSim = null
var _camera: CameraRig = null
# Halka tamponlar: konum, yarıçap/uzunluk, yaş (kalan süre).
var _ex_pos := PackedVector2Array()
var _ex_radius := PackedFloat32Array()
var _ex_left := PackedFloat32Array()
var _ex_head := 0
var _beam_a := PackedVector2Array()
var _beam_b := PackedVector2Array()
var _beam_left := PackedFloat32Array()
var _beam_head := 0
var _puff_pos := PackedVector2Array()
var _puff_left := PackedFloat32Array()
var _puff_head := 0
var _spark_left := PackedFloat32Array()
var _spark_head := 0
var _active: int = 0


func _init() -> void:
	z_index = 5
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_ex_pos.resize(MAX_EXPLOSIONS)
	_ex_radius.resize(MAX_EXPLOSIONS)
	_ex_left.resize(MAX_EXPLOSIONS)
	_beam_a.resize(MAX_BEAMS)
	_beam_b.resize(MAX_BEAMS)
	_beam_left.resize(MAX_BEAMS)
	_puff_pos.resize(MAX_PUFFS)
	_puff_left.resize(MAX_PUFFS)
	_spark_left.resize(MAX_SPARKS)


func bind(sim: GameSim, camera: CameraRig = null) -> void:
	if _sim != null:
		if _sim.bus.explosion.is_connected(_on_explosion):
			_sim.bus.explosion.disconnect(_on_explosion)
			_sim.bus.enemy_killed.disconnect(_on_killed)
			_sim.bus.gem_collected.disconnect(_on_gem)
			_sim.fx.beam_fired.disconnect(_on_beam)
	_sim = sim
	_camera = camera
	_ex_left.fill(0.0)
	_beam_left.fill(0.0)
	_puff_left.fill(0.0)
	_spark_left.fill(0.0)
	_active = 0
	queue_redraw()
	if sim == null:
		return
	sim.bus.explosion.connect(_on_explosion)
	sim.bus.enemy_killed.connect(_on_killed)
	sim.bus.gem_collected.connect(_on_gem)
	sim.fx.beam_fired.connect(_on_beam)


## Efekt var mı (testler/yeniden çizim).
func active_count() -> int:
	return _active


func add_explosion(pos: Vector2, radius: float) -> void:
	_ex_pos[_ex_head] = pos
	_ex_radius[_ex_head] = radius
	_ex_left[_ex_head] = EXPLOSION_TIME
	_ex_head = (_ex_head + 1) % MAX_EXPLOSIONS
	if _camera != null and radius >= SHAKE_MIN_RADIUS:
		_camera.shake(minf(radius * 0.05, 18.0))


func add_beam(a: Vector2, b: Vector2) -> void:
	_beam_a[_beam_head] = a
	_beam_b[_beam_head] = b
	_beam_left[_beam_head] = BEAM_TIME
	_beam_head = (_beam_head + 1) % MAX_BEAMS


func add_puff(pos: Vector2) -> void:
	_puff_pos[_puff_head] = pos
	_puff_left[_puff_head] = PUFF_TIME
	_puff_head = (_puff_head + 1) % MAX_PUFFS


func add_spark() -> void:
	_spark_left[_spark_head] = SPARK_TIME
	_spark_head = (_spark_head + 1) % MAX_SPARKS


# v1.1 ek API (hepsi sabit boyutlu halka tampon). İskelet (S3): gövdeler D1-3'te dolar.

## Genel halka (MAX_RINGS 12): pos merkezli, 0'dan r_max'a dur sn'de büyür.
@warning_ignore("unused_parameter")
func add_ring(pos: Vector2, r_max: float, dur: float, color: Color, width: float) -> void:
	Stub.todo(&"FxRenderer.add_ring")


## Kovan (16): pos'tan dir yönüne atılır.
@warning_ignore("unused_parameter")
func add_shell(pos: Vector2, dir: Vector2) -> void:
	Stub.todo(&"FxRenderer.add_shell")


## Parçacık (96): kind = &"plus"|&"ember"|&"dust".
@warning_ignore("unused_parameter")
func add_particle(kind: StringName, pos: Vector2, vel: Vector2, life: float) -> void:
	Stub.todo(&"FxRenderer.add_particle")


## Zemin kömürü (≤8).
@warning_ignore("unused_parameter")
func add_char(pos: Vector2, radius: float) -> void:
	Stub.todo(&"FxRenderer.add_char")


## Her kare: sürelerini azalt, etkinse yeniden çiz.
func update_fx(dt: float) -> void:
	var n := 0
	for i in MAX_EXPLOSIONS:
		if _ex_left[i] > 0.0:
			_ex_left[i] = maxf(0.0, _ex_left[i] - dt)
			n += 1
	for i in MAX_BEAMS:
		if _beam_left[i] > 0.0:
			_beam_left[i] = maxf(0.0, _beam_left[i] - dt)
			n += 1
	for i in MAX_PUFFS:
		if _puff_left[i] > 0.0:
			_puff_left[i] = maxf(0.0, _puff_left[i] - dt)
			n += 1
	for i in MAX_SPARKS:
		if _spark_left[i] > 0.0:
			_spark_left[i] = maxf(0.0, _spark_left[i] - dt)
			n += 1
	if n > 0 or _active > 0:
		queue_redraw()
	_active = n


func _draw() -> void:
	var soft := PlaceholderArt.soft_circle(128)
	for i in MAX_EXPLOSIONS:
		var left := _ex_left[i]
		if left <= 0.0:
			continue
		var k := 1.0 - left / EXPLOSION_TIME  # 0 -> 1
		var r := _ex_radius[i] * (0.35 + 0.65 * sqrt(k))
		var a := (1.0 - k) * (1.0 - k)
		var p := _ex_pos[i]
		draw_texture_rect(
			soft,
			Rect2(p - Vector2(r, r) * 1.15, Vector2(r, r) * 2.3),
			false,
			Color(1.0, 0.55, 0.2, 0.55 * a)
		)
		draw_arc(p, r, 0.0, TAU, 48, Color(1.0, 0.82, 0.5, 0.9 * a), 5.0 * (1.0 - k) + 1.5, true)
		draw_texture_rect(
			soft,
			Rect2(p - Vector2(r, r) * 0.45, Vector2(r, r) * 0.9),
			false,
			Color(1.0, 0.95, 0.8, 0.8 * a)
		)
	for i in MAX_BEAMS:
		var left := _beam_left[i]
		if left <= 0.0:
			continue
		var a := left / BEAM_TIME
		draw_line(_beam_a[i], _beam_b[i], Color(1.0, 0.7, 0.35, 0.35 * a), 22.0 * a + 4.0, true)
		draw_line(_beam_a[i], _beam_b[i], Color(1.0, 0.97, 0.88, 0.95 * a), 5.0 * a + 1.5, true)
	for i in MAX_PUFFS:
		var left := _puff_left[i]
		if left <= 0.0:
			continue
		var k := 1.0 - left / PUFF_TIME
		var r := 22.0 + 30.0 * k
		draw_texture_rect(
			soft,
			Rect2(_puff_pos[i] + Vector2(0, -26.0 * k) - Vector2(r, r), Vector2(r, r) * 2.0),
			false,
			Color(0.55, 0.32, 0.22, 0.22 * (1.0 - k))
		)
	if _sim != null:
		for i in MAX_SPARKS:
			var left := _spark_left[i]
			if left <= 0.0:
				continue
			var k := 1.0 - left / SPARK_TIME
			var c := _sim.player_pos
			draw_arc(
				c,
				34.0 + 46.0 * k,
				0.0,
				TAU,
				28,
				Color(0.66, 0.55, 0.95, 0.7 * (1.0 - k)),
				3.0,
				true
			)


func _on_explosion(pos: Vector2, radius: float) -> void:
	add_explosion(pos, radius)


func _on_killed(_type_id: StringName, pos: Vector2) -> void:
	add_puff(pos)


func _on_gem(_value: int) -> void:
	add_spark()


func _on_beam(a: Vector2, b: Vector2) -> void:
	add_beam(a, b)
