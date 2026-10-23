class_name InputGate
extends RefCounted
## Dokunma girdisinin TEK karar noktası (saf sınıf; Node/Input/Time bilmez).
## Kurallar (plan "Arayüzler > Sabitler ve ölçü"): ilk parmak joystick, ikinci parmak yok sayılır;
## ölü bölge 24 px (≈0,12); maks. yarıçap 195 px; parmak kalkınca topuz 120 ms'de söner;
## devam/seviye atlama sonrası 600 ms girdi kilidi. Zaman dışarıdan `tick(dt)` ile gelir.
## Hareket vektörünü yalnız `move()` üretir (|v| <= 1).

## Joystick sabitlerinin TEK ayar noktası (ara denetim #2: cihazda 180–210 px / ≈24 px denenir).
## Taban çapı (JoystickView) ve ölü bölge oranı bunlardan türer.
const MAX_RADIUS := 195.0
const DEAD_ZONE_PX := 24.0
const DEAD_ZONE := DEAD_ZONE_PX / MAX_RADIUS
const FADE_TIME := 0.12
const LOCK_TIME := 0.6
const NO_FINGER := -1

## Joystick'i süren parmak (NO_FINGER = yok).
var finger: int = NO_FINGER
## Parmağın ilk değdiği nokta (joystick tabanı, viewport koordinatı).
var origin: Vector2 = Vector2.ZERO
## Parmağın son konumu.
var current: Vector2 = Vector2.ZERO

var _fade_left: float = 0.0
var _lock_left: float = 0.0


## Ham ofsetten hareket vektörü: yarıçapla normalize, ölü bölge altı sıfır, üstü 0..1'e yeniden ölçeklenir.
static func stick_vector(
	offset: Vector2, max_radius: float = MAX_RADIUS, dead_zone: float = DEAD_ZONE
) -> Vector2:
	if max_radius <= 0.0:
		return Vector2.ZERO
	var mag := minf(offset.length() / max_radius, 1.0)
	if mag <= dead_zone:
		return Vector2.ZERO
	var scaled := (mag - dead_zone) / (1.0 - dead_zone)
	return offset.normalized() * minf(scaled, 1.0)


## Topuzun tabana göre ofseti (yarıçapla sınırlı).
static func clamp_offset(offset: Vector2, max_radius: float = MAX_RADIUS) -> Vector2:
	return offset.limit_length(max_radius)


## InputEventScreenTouch karşılığı.
func touch(index: int, pressed: bool, pos: Vector2) -> void:
	if pressed:
		if finger != NO_FINGER or is_locked():
			return  # ikinci parmak ya da kilit: yok sayılır
		_begin(index, pos)
	elif index == finger:
		_release()


## InputEventScreenDrag karşılığı.
func drag(index: int, pos: Vector2) -> void:
	if index == finger:
		current = pos
	elif finger == NO_FINGER and not is_locked():
		# Kilit sırasında basılı kalan parmak, kilit bitince kaldırmadan sürmeye başlayabilir.
		_begin(index, pos)


## Zaman ilerlet (saniye): sönme ve kilit sayaçları.
func tick(dt: float) -> void:
	if _lock_left > 0.0:
		_lock_left = maxf(0.0, _lock_left - dt)
	if finger == NO_FINGER and _fade_left > 0.0:
		_fade_left = maxf(0.0, _fade_left - dt)


## Devam/seviye atlama sonrası girdi kilidi; basılı parmak bırakılmış sayılır.
func lock(duration: float = LOCK_TIME) -> void:
	_lock_left = maxf(_lock_left, duration)
	if finger != NO_FINGER:
		finger = NO_FINGER
		_fade_left = 0.0


## Her şeyi sıfırlar (yeni oyun / ekran değişimi).
func reset() -> void:
	finger = NO_FINGER
	origin = Vector2.ZERO
	current = Vector2.ZERO
	_fade_left = 0.0
	_lock_left = 0.0


func is_locked() -> bool:
	return _lock_left > 0.0


func is_active() -> bool:
	return finger != NO_FINGER


## TEK hareket kaynağı: |v| <= 1; parmak yoksa ya da kilitliyse sıfır.
func move() -> Vector2:
	if finger == NO_FINGER or is_locked():
		return Vector2.ZERO
	return stick_vector(current - origin)


## Topuzun tabana göre çizim ofseti (parmak kalkınca son konumda kalır, söner).
func knob_offset() -> Vector2:
	return clamp_offset(current - origin)


## Joystick görünürlüğü 0..1: basılıyken 1, kalkınca FADE_TIME içinde 0'a iner.
func visibility() -> float:
	if finger != NO_FINGER:
		return 1.0
	if FADE_TIME <= 0.0:
		return 0.0
	return clampf(_fade_left / FADE_TIME, 0.0, 1.0)


func _begin(index: int, pos: Vector2) -> void:
	finger = index
	origin = pos
	current = pos
	_fade_left = FADE_TIME


func _release() -> void:
	finger = NO_FINGER
	_fade_left = FADE_TIME
