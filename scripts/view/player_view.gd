class_name PlayerView
extends Node2D
## Parçalı geçici şekil rig (plan "Parçalı karakter rig'i"):
## Player (bu düğüm, y_sort) → FarArm (z −1) / Body (MeshInstance2D, z 0) / NearArm (z +1) / ReloadRing / Shadow.
## Kol hedefe döner (`sim.gun_aim[gun]`); cos(rotation) < 0 ise scale.y = −1. Namlu ateşi
## `PlayerRig.muzzle_world(...)` ile çizilir (sim ile TEK kaynak). Düğüm konumu = sim.player_pos (gövde merkezi, PlayerRig ile aynı).
## Pivot/omuz/namlu headless'ta görsel doğrulanamaz; kullanıcıda ekran görüntüsüyle doğrulanır.

const SWAY_SHADER := "res://assets/shaders/player_sway.gdshader"
const RIM_SHADER := "res://assets/shaders/rim_sprite.gdshader"
const DEFAULT_HEIGHT := 112.0
const FAR_ARM_TINT := Color(0.8, 0.8, 0.8, 1.0)
const BOB_PX := 4.0
const SQUASH := 0.04
const BOB_HZ := 2.2
const RECOIL_TIME := 0.06
const RECOIL_ROT := 0.12
const RECOIL_PX := 6.0
const FLASH_TIME := 0.06
const RING_RADIUS := 26.0
const PAD := 12  # rim için doku etrafı saydam dolgu (doku pikseli)
const RIM_COLOR := Color(0.86, 0.80, 0.66)
const RIM_SCREEN_PX := 3.0

var far_arm: Sprite2D
var body: MeshInstance2D
var near_arm: Sprite2D
var reload_ring: ReloadRing
var shadow: Shadow
var muzzle_flash: MuzzleFlash
var glow: Glow

var _sim: GameSim = null
var _rig: Dictionary = {}
var _height: float = DEFAULT_HEIGHT
var _arm_len: float = 70.0
var _facing_left: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _walk_t: float = 0.0
var _sway: float = 0.0
var _recoil := PackedFloat32Array([0.0, 0.0])
var _pad_world: Vector2 = Vector2.ZERO
var _arm_orig: Vector2 = Vector2(120, 48)
var _real: bool = false


## Dünya-uzayı doldurma halkası (amber, oyuncunun başı üstünde).
class ReloadRing:
	extends Node2D
	var progress: float = 0.0
	var radius: float = 26.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.05, 0.035, 0.06, 0.7), 8.0, true)
		if progress > 0.0:
			var a0 := -PI * 0.5
			draw_arc(Vector2.ZERO, radius, a0, a0 + TAU * progress, 40, Color("#e8a24a"), 6.0, true)


## Oyuncunun altında sıcak amber ışık havuzu (zeminden ayrışma + atmosfer).
class Glow:
	extends Node2D
	var radius: float = 150.0

	func _draw() -> void:
		var tex := PlaceholderArt.soft_circle(128)
		draw_texture_rect(
			tex,
			Rect2(Vector2(-radius, -radius * 0.55), Vector2(radius * 2.0, radius * 1.1)),
			false,
			Color(1.0, 0.62, 0.28, 0.34)
		)


## Ayak altı gölge elipsi.
class Shadow:
	extends Node2D
	var size: Vector2 = Vector2(60, 18)

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, size.y / size.x))
		draw_circle(Vector2.ZERO, size.x * 0.5, Color(0, 0, 0, 0.38))


## Namlu parlaması: yerel noktalar ve kalan süreler.
class MuzzleFlash:
	extends Node2D
	var points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	var left := PackedFloat32Array([0.0, 0.0])

	func _draw() -> void:
		for g in 2:
			if left[g] <= 0.0:
				continue
			var k := left[g] / 0.06
			draw_circle(points[g], 14.0 * k + 4.0, Color(1.0, 0.75, 0.35, 0.55 * k))
			draw_circle(points[g], 7.0 * k + 2.0, Color(1.0, 0.95, 0.8, 0.95 * k))


func _init() -> void:
	y_sort_enabled = true
	shadow = Shadow.new()
	shadow.name = "Shadow"
	shadow.z_index = -2
	far_arm = _make_arm("FarArm", -1)
	far_arm.modulate = FAR_ARM_TINT
	glow = Glow.new()
	glow.name = "Glow"
	glow.z_index = -3
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	body = MeshInstance2D.new()
	body.name = "Body"
	body.texture = PlaceholderArt.body_texture()
	near_arm = _make_arm("NearArm", 1)
	reload_ring = ReloadRing.new()
	reload_ring.name = "ReloadRing"
	reload_ring.z_index = 3
	reload_ring.visible = false
	muzzle_flash = MuzzleFlash.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.z_index = 2
	add_child(glow)
	add_child(far_arm)
	add_child(body)
	add_child(near_arm)
	add_child(reload_ring)
	add_child(shadow)
	add_child(muzzle_flash)
	_apply_rig({})


func bind(sim: GameSim) -> void:
	if _sim != null and _sim.bus.shot_fired.is_connected(_on_shot_fired):
		_sim.bus.shot_fired.disconnect(_on_shot_fired)
	_sim = sim
	var rig: Dictionary = {}
	if sim != null and sim.character != null:
		rig = sim.character.rig
	_apply_rig(rig)
	if sim != null:
		sim.bus.shot_fired.connect(_on_shot_fired)
		position = sim.player_pos
		_last_pos = sim.player_pos


## Gövde boyutu (en × boy) karakter verisinden.
static func body_size(rig: Dictionary) -> Vector2:
	var h := float(rig.get("display_height", DEFAULT_HEIGHT))
	return Vector2(h * PlayerRig.BODY_ASPECT, h)


## Omuz noktası (Player yerel; gövde merkezi orijinde) — PlayerRig ile aynı geometri (tek kaynak).
static func shoulder_local(rig: Dictionary, gun: int, facing_left: bool) -> Vector2:
	return PlayerRig.shoulder_world(gun, Vector2.ZERO, facing_left, rig)


## Kol dönüşü için dikey ayna: cos(rotation) < 0 ise -1 (kol görseli sağa bakar).
static func arm_flip(rotation_rad: float) -> float:
	return -1.0 if cos(rotation_rad) < 0.0 else 1.0


## Her kare: sim'i oku, rig'i yerleştir.
func update_view(dt: float) -> void:
	if _sim == null:
		return
	var pos := _sim.player_pos
	var moved := pos - _last_pos
	_last_pos = pos
	position = pos
	_facing_left = _sim.player_facing_left
	var speed := moved.length() / maxf(dt, 0.0001)
	var moving := speed > 5.0
	if moving:
		_walk_t += dt
	else:
		_walk_t = 0.0
	# gövde: yön, bob ±4 px, squash %4
	var size := body_size(_rig)
	var bob := absf(sin(_walk_t * TAU * BOB_HZ)) if moving else 0.0
	var fx := -1.0 if _facing_left else 1.0
	var sy := 1.0 - SQUASH * bob
	var sx := 1.0 + SQUASH * bob
	body.position = Vector2(-size.x * 0.5 * sx * fx, -size.y * 0.5 * sy - bob * BOB_PX)
	body.scale = Vector2(fx * sx, sy)
	# etek salınımı: hareketin tersine, gecikmeli
	var lag := 0.12
	var sway_cfg: Variant = _rig.get("sway", {})
	if sway_cfg is Dictionary:
		lag = float(sway_cfg.get("lag", 0.12))
	var target := clampf(-moved.x / maxf(dt, 0.0001) / 300.0, -1.0, 1.0)
	_sway = lerpf(_sway, target, clampf(dt / maxf(lag, 0.001), 0.0, 1.0))
	if body.material is ShaderMaterial:
		(body.material as ShaderMaterial).set_shader_parameter("sway", _sway * fx)
	# kollar
	var aims := _aims()
	_place_arm(near_arm, 0, aims[0], dt)
	_place_arm(far_arm, 1, aims[1], dt)
	# doldurma halkası
	var mag := _sim.magazine
	reload_ring.visible = mag.reloading
	if mag.reloading:
		var total := maxf(mag.reload_total, 0.0001)
		reload_ring.progress = clampf(1.0 - mag.reload_left / total, 0.0, 1.0)
		reload_ring.position = Vector2(0, -size.y * 0.5 - RING_RADIUS - 14.0)
		reload_ring.queue_redraw()
	# namlu parlaması
	var any := false
	for g in 2:
		if muzzle_flash.left[g] > 0.0:
			muzzle_flash.left[g] = maxf(0.0, muzzle_flash.left[g] - dt)
			any = true
	if any:
		muzzle_flash.queue_redraw()


func _aims() -> PackedFloat32Array:
	var base := PI if _facing_left else 0.0
	var out := PackedFloat32Array([base, base])
	var v := _sim.gun_aim
	if v.size() >= 2:
		out[0] = v[0]
		out[1] = v[1]
	return out


func _place_arm(arm: Sprite2D, gun: int, aim: float, dt: float) -> void:
	var flip := arm_flip(aim)
	var kx := _arm_len / maxf(_arm_orig.x, 1.0)
	var ky := _arm_len * PlayerRig.ARM_ASPECT / maxf(_arm_orig.y, 1.0)
	var rec := 0.0
	if _recoil[gun] > 0.0:
		_recoil[gun] = maxf(0.0, _recoil[gun] - dt)
		rec = _recoil[gun] / RECOIL_TIME
	arm.rotation = aim - RECOIL_ROT * rec * flip
	arm.scale = Vector2(kx, ky * flip)
	arm.position = (
		shoulder_local(_rig, gun, _facing_left) - Vector2.from_angle(aim) * RECOIL_PX * rec
	)


func _apply_rig(rig: Dictionary) -> void:
	_rig = rig
	_height = float(rig.get("display_height", DEFAULT_HEIGHT))
	_arm_len = float(rig.get("arm_scale", 0.62)) * _height
	var size := body_size(rig)
	# Görseller: gerçek dosya varsa dolgulu (rim için) doku, yoksa geçici şekil.
	var body_tex := ArtLoader.padded(str(rig.get("body", "")), PAD)
	var arm_tex := ArtLoader.padded(str(rig.get("arm", "")), PAD)
	_real = body_tex != null and arm_tex != null
	var pad_frac := Vector2.ZERO
	_pad_world = Vector2.ZERO
	if _real:
		body.texture = body_tex
		var ts := body_tex.get_size()
		pad_frac = Vector2(PAD, PAD) / ts
		_pad_world = Vector2(PAD, PAD) / (ts - Vector2(PAD, PAD) * 2.0) * size
		for arm in [near_arm, far_arm]:
			arm.texture = arm_tex
		_arm_orig = arm_tex.get_size() - Vector2(PAD, PAD) * 2.0
	else:
		body.texture = PlaceholderArt.body_texture()
		for arm in [near_arm, far_arm]:
			arm.texture = PlaceholderArt.arm_texture()
		_arm_orig = PlaceholderArt.arm_texture().get_size()
	body.mesh = PlaceholderArt.grid_mesh(size + _pad_world * 2.0, 16, 24, -_pad_world)
	if ResourceLoader.exists(SWAY_SHADER):
		var mat := ShaderMaterial.new()
		mat.shader = load(SWAY_SHADER)
		var sway: Variant = rig.get("sway", {})
		if sway is Dictionary:
			mat.set_shader_parameter("amp", float(sway.get("amp", 6.0)))
			mat.set_shader_parameter("hem_from_y", float(sway.get("hem_from_y", 0.6)))
			var sr: Variant = sway.get("scarf_rect", [])
			if sr is Array and sr.size() >= 4:
				mat.set_shader_parameter(
					"scarf_rect", Vector4(float(sr[0]), float(sr[1]), float(sr[2]), float(sr[3]))
				)
		mat.set_shader_parameter("body_tex", body.texture)
		mat.set_shader_parameter("pad_frac", pad_frac)
		var texel_world := (
			size.y / maxf(body.texture.get_size().y - 2.0 * (PAD if _real else 0), 1.0)
		)
		mat.set_shader_parameter("rim_px", clampf(RIM_SCREEN_PX / texel_world, 1.0, 12.0))
		mat.set_shader_parameter("rim_color", Vector3(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b))
		body.material = mat
	var pivot := Vector2(0.11, 0.47)
	var pv: Variant = rig.get("arm_pivot", [])
	if pv is Array and pv.size() >= 2:
		pivot = Vector2(float(pv[0]), float(pv[1]))
	var pad_px := Vector2(PAD, PAD) if _real else Vector2.ZERO
	for arm in [near_arm, far_arm]:
		arm.offset = -(pad_px + pivot * _arm_orig)
		if _real and ResourceLoader.exists(RIM_SHADER):
			var am := ShaderMaterial.new()
			am.shader = load(RIM_SHADER)
			am.set_shader_parameter("sprite_tex", arm_tex)
			var kx := _arm_len / maxf(_arm_orig.x, 1.0)
			am.set_shader_parameter("rim_px", clampf(RIM_SCREEN_PX / kx, 1.0, 12.0))
			am.set_shader_parameter("rim_color", Vector3(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b))
			var tint := FAR_ARM_TINT if arm == far_arm else Color.WHITE
			am.set_shader_parameter("tint", Vector4(tint.r, tint.g, tint.b, 1.0))
			arm.material = am
			arm.modulate = Color.WHITE
		elif arm == far_arm:
			arm.modulate = FAR_ARM_TINT
	shadow.size = Vector2(size.x * 0.9, size.x * 0.28)
	shadow.position = Vector2(0, size.y * 0.5)
	glow.position = Vector2(0, size.y * 0.42)
	glow.radius = size.y * 0.8
	glow.queue_redraw()
	reload_ring.radius = RING_RADIUS


func _make_arm(node_name: String, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = PlaceholderArt.arm_texture()
	s.centered = false
	s.z_index = z
	return s


func _on_shot_fired(gun: int, _origin: Vector2, _dir: Vector2) -> void:
	if gun < 0 or gun > 1 or _sim == null:
		return
	_recoil[gun] = RECOIL_TIME
	var aims := _aims()
	var mp := PlayerRig.muzzle_world(gun, _sim.player_pos, aims[gun], _facing_left, _rig)
	muzzle_flash.points[gun] = mp - _sim.player_pos
	muzzle_flash.left[gun] = FLASH_TIME
	muzzle_flash.queue_redraw()
