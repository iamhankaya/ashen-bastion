class_name FxRenderer
extends Node2D
## Dünya uzayı efektleri (yalnız görsel; sim'i okur, hiçbir sim durumunu değiştirmez): patlama halkası + parlama,
## keskin nişan çizgisi, XP toplama kıvılcımı, ölüm tozu; v1.1: genel halka, boş kovan, parçacık (artı/kor/toz) ve zemin
## kömürü. Hepsi sabit boyutlu halka tamponlarda (sıcak yolda tahsis yok); ek (additive) karışımla çizilir, kömür hariç
## (normal karışımlı CharLayer düğümü; denetleyici onu zemin ile gölgeler arasına taşır). SimBus + SimFx sinyallerine bağlanır.

const MAX_EXPLOSIONS := 24
const MAX_BEAMS := 4
const MAX_PUFFS := 64
const MAX_SPARKS := 16
const EXPLOSION_TIME := 0.38
const BEAM_TIME := 0.18
const PUFF_TIME := 0.45
const SPARK_TIME := 0.28
const SHAKE_MIN_RADIUS := 150.0
const MAX_RINGS := 12
const MAX_SHELLS := 16
const MAX_PARTICLES := 96
const MAX_CHARS := 8
const SHELL_TIME := 0.35
const CHAR_TIME := 4.0
const PARTICLE_PLUS := &"plus"
const PARTICLE_EMBER := &"ember"
const PARTICLE_DUST := &"dust"
const SHELL_COLOR := Color(0.82, 0.71, 0.49, 0.9)
const EMBER_COLOR := Color(0.91, 0.635, 0.29)
const PLUS_COLOR := Color(0.878, 0.345, 0.31)
const DUST_COLOR := Color(0.55, 0.32, 0.22)

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
# v1.1 halka tamponlar
var _ring_pos := PackedVector2Array()
var _ring_r := PackedFloat32Array()
var _ring_dur := PackedFloat32Array()
var _ring_left := PackedFloat32Array()
var _ring_w := PackedFloat32Array()
var _ring_col := PackedColorArray()
var _ring_head := 0
var _shell_pos := PackedVector2Array()
var _shell_dir := PackedVector2Array()
var _shell_dist := PackedFloat32Array()
var _shell_left := PackedFloat32Array()
var _shell_head := 0
var _part_kind := PackedByteArray()
var _part_pos := PackedVector2Array()
var _part_vel := PackedVector2Array()
var _part_life := PackedFloat32Array()
var _part_left := PackedFloat32Array()
var _part_head := 0
var _rng := RandomNumberGenerator.new()
## Zemin kömürü (normal karışım): FxRenderer'ın çocuğu; GameController zemin ile gölgeler arasına taşır.
var char_layer: CharLayer = null


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
	_ring_pos.resize(MAX_RINGS)
	_ring_r.resize(MAX_RINGS)
	_ring_dur.resize(MAX_RINGS)
	_ring_left.resize(MAX_RINGS)
	_ring_w.resize(MAX_RINGS)
	_ring_col.resize(MAX_RINGS)
	_shell_pos.resize(MAX_SHELLS)
	_shell_dir.resize(MAX_SHELLS)
	_shell_dist.resize(MAX_SHELLS)
	_shell_left.resize(MAX_SHELLS)
	_part_kind.resize(MAX_PARTICLES)
	_part_pos.resize(MAX_PARTICLES)
	_part_vel.resize(MAX_PARTICLES)
	_part_life.resize(MAX_PARTICLES)
	_part_left.resize(MAX_PARTICLES)
	_rng.seed = 11
	char_layer = CharLayer.new()
	char_layer.name = "CharLayer"
	add_child(char_layer)


## Zemin kömürü: yarıçap 0,7R elips, α 0,35, 4 sn'de solar, en çok 8. Normal karışım (additive siyah görünmez).
class CharLayer:
	extends Node2D
	var pos := PackedVector2Array()
	var radius := PackedFloat32Array()
	var left := PackedFloat32Array()
	var head := 0

	func _init() -> void:
		pos.resize(FxRenderer.MAX_CHARS)
		radius.resize(FxRenderer.MAX_CHARS)
		left.resize(FxRenderer.MAX_CHARS)

	func count() -> int:
		var n := 0
		for k in FxRenderer.MAX_CHARS:
			if left[k] > 0.0:
				n += 1
		return n

	func _draw() -> void:
		var soft := PlaceholderArt.soft_circle(128)
		for k in FxRenderer.MAX_CHARS:
			if left[k] <= 0.0:
				continue
			var a := 0.35 * clampf(left[k] / FxRenderer.CHAR_TIME * 2.0, 0.0, 1.0)
			var r := radius[k] * 0.7
			draw_texture_rect(
				soft,
				Rect2(pos[k] - Vector2(r, r * 0.6), Vector2(r * 2.0, r * 1.2)),
				false,
				Color(0.03, 0.02, 0.025, a)
			)


func bind(sim: GameSim, camera: CameraRig = null) -> void:
	if _sim != null:
		if _sim.bus.explosion.is_connected(_on_explosion):
			_sim.bus.explosion.disconnect(_on_explosion)
			_sim.bus.enemy_killed.disconnect(_on_killed)
			_sim.bus.gem_collected.disconnect(_on_gem)
			_sim.bus.bomb_exploded.disconnect(_on_bomb_exploded)
			_sim.fx.beam_fired.disconnect(_on_beam)
	_sim = sim
	_camera = camera
	_ex_left.fill(0.0)
	_beam_left.fill(0.0)
	_puff_left.fill(0.0)
	_spark_left.fill(0.0)
	_ring_left.fill(0.0)
	_shell_left.fill(0.0)
	_part_left.fill(0.0)
	char_layer.left.fill(0.0)
	char_layer.queue_redraw()
	_active = 0
	queue_redraw()
	if sim == null:
		return
	sim.bus.explosion.connect(_on_explosion)
	sim.bus.enemy_killed.connect(_on_killed)
	sim.bus.gem_collected.connect(_on_gem)
	sim.bus.bomb_exploded.connect(_on_bomb_exploded)
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


# v1.1 ek API (hepsi sabit boyutlu halka tampon).


## Genel halka (MAX_RINGS 12): pos merkezli, 0'dan r_max'a dur sn'de büyür (cubic-out), solar.
func add_ring(pos: Vector2, r_max: float, dur: float, color: Color, width: float) -> void:
	_ring_pos[_ring_head] = pos
	_ring_r[_ring_head] = r_max
	_ring_dur[_ring_head] = maxf(dur, 0.01)
	_ring_left[_ring_head] = maxf(dur, 0.01)
	_ring_w[_ring_head] = width
	_ring_col[_ring_head] = color
	_ring_head = (_ring_head + 1) % MAX_RINGS


## Boş kovan (16): 350 ms yay; dir yatay yönü verir (yan-geri 30–50 px, 6 px yükselip düşer).
func add_shell(pos: Vector2, dir: Vector2) -> void:
	var d := Vector2(signf(dir.x) if absf(dir.x) > 0.01 else 1.0, 0.0)
	_shell_pos[_shell_head] = pos
	_shell_dir[_shell_head] = d
	_shell_dist[_shell_head] = _rng.randf_range(30.0, 50.0)
	_shell_left[_shell_head] = SHELL_TIME
	_shell_head = (_shell_head + 1) % MAX_SHELLS


## Parçacık (96): kind = &"plus"|&"ember"|&"dust". Bilinmeyen tür yok sayılır.
func add_particle(kind: StringName, pos: Vector2, vel: Vector2, life: float) -> void:
	var k := 0
	match kind:
		PARTICLE_PLUS:
			k = 1
		PARTICLE_EMBER:
			k = 2
		PARTICLE_DUST:
			k = 3
		_:
			return
	_part_kind[_part_head] = k
	_part_pos[_part_head] = pos
	_part_vel[_part_head] = vel
	_part_life[_part_head] = maxf(life, 0.01)
	_part_left[_part_head] = maxf(life, 0.01)
	_part_head = (_part_head + 1) % MAX_PARTICLES


## Zemin kömürü (≤8): normal karışımlı CharLayer'a yazılır.
func add_char(pos: Vector2, radius: float) -> void:
	var c := char_layer
	c.pos[c.head] = pos
	c.radius[c.head] = radius
	c.left[c.head] = CHAR_TIME
	c.head = (c.head + 1) % MAX_CHARS
	c.queue_redraw()


func ring_count() -> int:
	return _count_positive(_ring_left)


func shell_count() -> int:
	return _count_positive(_shell_left)


func particle_count() -> int:
	return _count_positive(_part_left)


func char_count() -> int:
	return char_layer.count()


static func _count_positive(a: PackedFloat32Array) -> int:
	var n := 0
	for x in a:
		if x > 0.0:
			n += 1
	return n


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
	n += _update_v11(dt)
	if n > 0 or _active > 0:
		queue_redraw()
	_active = n


## v1.1 tamponları: süreleri azalt, parçacıkları hareket ettir. Döner: etkin öğe sayısı.
func _update_v11(dt: float) -> int:
	var n := 0
	for i in MAX_RINGS:
		if _ring_left[i] > 0.0:
			_ring_left[i] = maxf(0.0, _ring_left[i] - dt)
			n += 1
	for i in MAX_SHELLS:
		if _shell_left[i] > 0.0:
			_shell_left[i] = maxf(0.0, _shell_left[i] - dt)
			n += 1
	for i in MAX_PARTICLES:
		if _part_left[i] <= 0.0:
			continue
		_part_left[i] = maxf(0.0, _part_left[i] - dt)
		var v := _part_vel[i]
		if _part_kind[i] == 2:  # kor yükselir ve savrulur
			v.y -= 60.0 * dt
		v *= maxf(0.0, 1.0 - 1.5 * dt)
		_part_vel[i] = v
		_part_pos[i] += v * dt
		n += 1
	var c := char_layer
	var char_active := false
	for i in MAX_CHARS:
		if c.left[i] > 0.0:
			c.left[i] = maxf(0.0, c.left[i] - dt)
			char_active = true
	if char_active or c.count() > 0:
		c.queue_redraw()
	return n


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
	_draw_v11()
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


func _draw_v11() -> void:
	var soft := PlaceholderArt.soft_circle(64)
	for i in MAX_RINGS:
		var left := _ring_left[i]
		if left <= 0.0:
			continue
		var k := 1.0 - left / _ring_dur[i]
		var r := _ring_r[i] * (1.0 - pow(1.0 - k, 3.0))
		var col := _ring_col[i]
		col.a *= (1.0 - k)
		draw_arc(
			_ring_pos[i],
			maxf(r, 1.0),
			0.0,
			TAU,
			48,
			col,
			maxf(_ring_w[i] * (1.0 - 0.6 * k), 1.0),
			true
		)
	for i in MAX_SHELLS:
		var left := _shell_left[i]
		if left <= 0.0:
			continue
		var u := 1.0 - left / SHELL_TIME
		var p := _shell_pos[i] + _shell_dir[i] * _shell_dist[i] * u
		p.y += -6.0 * sin(PI * u) + 10.0 * u * u  # 6 px yükselip düşer
		var ang := u * 9.0 * signf(_shell_dir[i].x)
		var half := Vector2(2.0, 1.0)
		var xf := Transform2D(ang, p)
		draw_set_transform_matrix(xf)
		draw_rect(Rect2(-half, half * 2.0), SHELL_COLOR * Color(1, 1, 1, 1.0 - u * u))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	for i in MAX_PARTICLES:
		var left := _part_left[i]
		if left <= 0.0:
			continue
		var u := 1.0 - left / _part_life[i]
		var p := _part_pos[i]
		match _part_kind[i]:
			1:  # artı: iyileşme/toplama işareti
				var col := PLUS_COLOR
				col.a = 1.0 - u
				draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), col, 3.0)
				draw_line(p + Vector2(0, -5), p + Vector2(0, 5), col, 3.0)
			2:  # kor
				var col2 := EMBER_COLOR
				col2.a = 0.9 * (1.0 - u)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col2)
			3:  # toz: büyüyen yumuşak leke
				var r := 10.0 + 22.0 * u
				draw_texture_rect(
					soft,
					Rect2(p - Vector2(r, r * 0.6), Vector2(r, r * 0.6) * 2.0),
					false,
					Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, 0.22 * (1.0 - u))
				)


func _on_bomb_exploded(pos: Vector2, radius: float) -> void:
	add_char(pos, radius)
	add_ring(pos, radius, 0.45, Color(0.878, 0.345, 0.31, 0.9), 6.0)


func _on_explosion(pos: Vector2, radius: float) -> void:
	add_explosion(pos, radius)


func _on_killed(type_id: StringName, pos: Vector2) -> void:
	add_puff(pos)
	# elit/Lord ölümü (E6): iki küçük ek puf
	if _sim != null and _sim.data != null:
		var def := _sim.data.get_enemy(type_id)
		if def != null and (def.ai == &"elite" or def.ai == &"lord"):
			add_puff(pos + Vector2(-34.0, 8.0))
			add_puff(pos + Vector2(36.0, -10.0))


func _on_gem(_value: int) -> void:
	add_spark()


func _on_beam(a: Vector2, b: Vector2) -> void:
	add_beam(a, b)
