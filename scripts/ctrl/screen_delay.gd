class_name ScreenDelay
extends RefCounted
## Ekran geçişi gecikmesi (ölüm 1,3 sn, kazanma 1,8 sn, seviye ön vurgusu 0,18 sn). Saf: Node bilmez.
## Gecikme tek tetiklenir: süre bitince ya da skip() ile bir kez true döner; ikinci tetik no-op.

var active: bool = false
## Gecikme bitince gidilecek ekran (PauseLogic.Screen).
var target: int = 0
var left: float = 0.0


## Gecikmeyi başlatır. Zaten aktifse yok sayılır (yarış: zamanlayıcı sürekli yeniden başlatılamaz).
func start(p_target: int, seconds: float) -> void:
	if active:
		return
	active = true
	target = p_target
	left = maxf(seconds, 0.0)


## Süre bitince true (bir kez).
func tick(dt: float) -> bool:
	if not active:
		return false
	left -= dt
	if left > 0.0:
		return false
	_finish()
	return true


## Aktifse hemen tetikler (true); değilse no-op (false). Dokunma, geri tuşu ve arka plan bunu çağırır.
func skip() -> bool:
	if not active:
		return false
	_finish()
	return true


func _finish() -> void:
	active = false
	left = 0.0
