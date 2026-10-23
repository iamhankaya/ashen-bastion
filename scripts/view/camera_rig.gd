class_name CameraRig
extends Camera2D
## Oyuncuyu izleyen kamera. Sim'e dokunmaz; konumu görünüm tarafında hesaplar (interpolasyon yok, v1).
## Kısa sarsıntı (patlama) yalnız görsel ofsettir.

const SHAKE_DECAY := 6.0

var _shake: float = 0.0
var _shake_t: float = 0.0


func _init() -> void:
	position_smoothing_enabled = false
	ignore_rotation = true


func follow(target: Vector2, dt: float) -> void:
	position = target
	if _shake > 0.01:
		_shake_t += dt
		offset = Vector2(sin(_shake_t * 61.0), cos(_shake_t * 47.0)) * _shake
		_shake = maxf(0.0, _shake - _shake * SHAKE_DECAY * dt)
	else:
		_shake = 0.0
		offset = Vector2.ZERO


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Kameranın dünya biriminde gördüğü alan.
func view_size() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(1080, 2400)
	return vp.get_visible_rect().size / zoom
