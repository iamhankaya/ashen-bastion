class_name ToastQueue
extends RefCounted
## Başarım bildirimi kuyruğu/zamanlaması (saf; çizmez, gerçek zaman yok). Aynı anda en çok 1 görünür, bekleyen en çok
## MAX_QUEUE; taşan düşer (`overflow`; kayıt yine yazılır, yalnız bildirim düşer). Tasarım §5.2:
## giriş 220 ms (24 px yukarıdan kayma + solma, cubic-out) · bekleme 2 100 ms · çıkış 180 ms = 2 500 ms, aralık 150 ms.

enum Phase { IDLE, IN, HOLD, OUT, GAP }

const MAX_QUEUE := 3
const IN_SEC := 0.22
const HOLD_SEC := 2.1
const OUT_SEC := 0.18
const GAP_SEC := 0.15
const SLIDE_PX := 24.0

## Kuyruk doluyken reddedilen bildirim sayısı.
var overflow: int = 0

var _waiting: Array[StringName] = []
var _current: StringName = &""
var _phase: int = Phase.IDLE
var _t: float = 0.0  # aktif aşamada geçen süre


## Boştaysa hemen görünür (IN); değilse bekleyenlere eklenir. Bekleyen MAX_QUEUE ise false ve overflow++.
func push(id: StringName) -> bool:
	if _phase == Phase.IDLE:
		_begin(id)
		return true
	if _waiting.size() >= MAX_QUEUE:
		overflow += 1
		return false
	_waiting.append(id)
	return true


## dt = 0 duraklamada durur (controller PLAYING dışında 0 verir). Büyük dt birden çok aşamayı geçebilir.
func tick(dt: float) -> void:
	if dt <= 0.0 or _phase == Phase.IDLE:
		return
	_t += dt
	while _phase != Phase.IDLE and _t >= _phase_len():
		_t -= _phase_len()
		_advance()


## Görünür bildirim kimliği (IN/HOLD/OUT); aksi halde &"".
func current() -> StringName:
	return _current if _phase in [Phase.IN, Phase.HOLD, Phase.OUT] else &""


func phase() -> int:
	return _phase


func waiting_count() -> int:
	return _waiting.size()


## (y kayması px: giriş 24→0, sonra 0; alfa: giriş 0→1 cubic-out, bekleme 1, çıkış 1→0). Görünür değilken (0, 0).
func offset_alpha() -> Vector2:
	match _phase:
		Phase.IN:
			var p := clampf(_t / IN_SEC, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - p, 3.0)
			return Vector2(SLIDE_PX * (1.0 - e), e)
		Phase.HOLD:
			return Vector2(0.0, 1.0)
		Phase.OUT:
			return Vector2(0.0, 1.0 - clampf(_t / OUT_SEC, 0.0, 1.0))
	return Vector2.ZERO


func clear() -> void:
	_waiting.clear()
	_current = &""
	_phase = Phase.IDLE
	_t = 0.0
	overflow = 0


func _begin(id: StringName) -> void:
	_current = id
	_phase = Phase.IN
	_t = 0.0


## Aşama geçişinde artan süre (`_t`) korunur: tek büyük tick birden çok aşamayı doğru geçer.
func _begin_carry(id: StringName) -> void:
	_current = id
	_phase = Phase.IN


func _phase_len() -> float:
	match _phase:
		Phase.IN:
			return IN_SEC
		Phase.HOLD:
			return HOLD_SEC
		Phase.OUT:
			return OUT_SEC
		Phase.GAP:
			return GAP_SEC
	return 0.0


func _advance() -> void:
	match _phase:
		Phase.IN:
			_phase = Phase.HOLD
		Phase.HOLD:
			_phase = Phase.OUT
		Phase.OUT:
			_current = &""
			_phase = Phase.GAP
		Phase.GAP:
			if _waiting.is_empty():
				_phase = Phase.IDLE
			else:
				_begin_carry(_waiting.pop_front())
