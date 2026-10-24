class_name ArmRig
extends RefCounted
## PlayerView'dan çıkarılan kol bloğu (v2.0.2 U2, davranış değişmez): iki kol Sprite2D'si, kol dokusu ölçüsü/uzunluğu,
## dönüş/ölçek/konum yerleşimi ve kenar ışığı malzemesi. Kolsuz rigde (Zyfen) kollar gizlenir ve hiç yerleştirilmez.
## Kol Rig'in çocuğudur (PlayerView ekler); dünya açısını korumak için dönüşü Rig dönüşünden çıkarır.

const ARM_FLIP_BAND := 0.5  # sin(30°): kol aynasında arm_rot işaretinin yumuşak geçiş bandı
const FAR_ARM_TINT := Color(0.8, 0.8, 0.8, 1.0)
const RIM_COLOR := Color(0.80, 0.72, 0.56)
const RIM_SCREEN_PX := 2.1
const RIM_SHADER := "res://assets/shaders/rim_sprite.gdshader"

var far_arm: Sprite2D
var near_arm: Sprite2D
## Kol dokusunun dolgusuz piksel boyutu ve gösterilen uzunluk (dünya px).
var orig: Vector2 = Vector2(120, 48)
var arm_len: float = 70.0
var _enabled: bool = true


func _init() -> void:
	far_arm = _make_arm("FarArm", -1)
	far_arm.modulate = FAR_ARM_TINT
	near_arm = _make_arm("NearArm", 1)


## Kol dokusu / pivotu / uzunluğu / kenar ışığı. `arm_tex` null ya da `armless` ise geçici şekil (kolsuzda kollar gizli).
func apply(rig: Dictionary, height: float, arm_tex: Texture2D, real: bool, pad: int) -> void:
	_enabled = not PlayerRig.is_armless(rig)
	far_arm.visible = _enabled
	near_arm.visible = _enabled
	arm_len = float(rig.get("arm_scale", 0.62)) * height
	if not _enabled:
		return
	var tex: Texture2D = arm_tex if real else PlaceholderArt.arm_texture()
	orig = tex.get_size() - Vector2(pad, pad) * 2.0 if real else tex.get_size()
	for arm in [near_arm, far_arm]:
		arm.texture = tex
	var pivot := Vector2(0.11, 0.47)
	var pv: Variant = rig.get("arm_pivot", [])
	if pv is Array and pv.size() >= 2:
		pivot = Vector2(float(pv[0]), float(pv[1]))
	var pad_px := Vector2(pad, pad) if real else Vector2.ZERO
	for arm in [near_arm, far_arm]:
		arm.offset = -(pad_px + pivot * orig)
		if real and ResourceLoader.exists(RIM_SHADER):
			var am := ShaderMaterial.new()
			am.shader = load(RIM_SHADER)
			am.set_shader_parameter("sprite_tex", arm_tex)
			var kx := arm_len / maxf(orig.x, 1.0)
			am.set_shader_parameter("rim_px", clampf(RIM_SCREEN_PX / kx, 1.0, 12.0))
			am.set_shader_parameter("rim_color", Vector3(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b))
			var tint := FAR_ARM_TINT if arm == far_arm else Color.WHITE
			am.set_shader_parameter("tint", Vector4(tint.r, tint.g, tint.b, 1.0))
			arm.material = am
			arm.modulate = Color.WHITE
		elif arm == far_arm:
			arm.modulate = FAR_ARM_TINT


func enabled() -> bool:
	return _enabled


func arm_of(gun: int) -> Sprite2D:
	return near_arm if gun == 0 else far_arm


## Kol dönüşü için dikey ayna: cos(rotation) < 0 ise -1 (kol görseli sağa bakar).
static func arm_flip(rotation_rad: float) -> float:
	return -1.0 if cos(rotation_rad) < 0.0 else 1.0


## Kolu yerleştirir. `aim`: gösterilen dünya açısı; `rig_rot`: Rig dönüşü; `shoulder`: Player yerel görünüm omzu;
## `half_h`: duruş kutusu yarı boyu; `sy`: gövde squash; `arm_rot/back/len`: PlayerAnim çıktıları (kol başına).
func place(
	arm: Sprite2D,
	aim: float,
	rig_rot: float,
	shoulder: Vector2,
	half_h: float,
	sy: float,
	arm_rot: float,
	back: float,
	len_scale: float
) -> void:
	var flip := arm_flip(aim)
	var kx := arm_len / maxf(orig.x, 1.0)
	var ky := arm_len * PlayerRig.ARM_ASPECT / maxf(orig.y, 1.0)
	var local_aim := aim - rig_rot
	# arm_rot "yukarı" işareti aim dikeyi geçerken flip ile 2×arm_rot sıçrardı: ±30° bandında yumuşak geçiş
	var soft := clampf(cos(aim) / ARM_FLIP_BAND, -1.0, 1.0)
	arm.rotation = local_aim - arm_rot * soft
	arm.scale = Vector2(kx * len_scale, ky * flip)
	var in_rig := Vector2(shoulder.x, (shoulder.y - half_h) * sy)
	arm.position = in_rig - Vector2.from_angle(local_aim) * back


func _make_arm(node_name: String, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = PlaceholderArt.arm_texture()
	s.centered = false
	s.z_index = z
	return s
