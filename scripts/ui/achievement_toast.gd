class_name AchievementToast
extends Control
## Koşu içi başarım bildirim kutusu (780×120, y 820 + üst güvenli pay). `mouse_filter = IGNORE` (alt düğümler dahil):
## dokunuşu yutmaz. Kural yok; zamanlama `ToastQueue`'dadır. İSKELET (S3): gövdeler B3'te (Stub.todo).

const SIZE_PX := Vector2(780.0, 120.0)
const X := 150.0
const Y := 820.0


## Kutunun referans (1080×2400) dikdörtgeni; safe_top = güvenli alan üst payı.
static func rect(safe_top: float) -> Rect2:
	return Rect2(X, Y + safe_top, SIZE_PX.x, SIZE_PX.y)


func show_def(_def: AchievementDef) -> void:
	Stub.todo(&"AchievementToast.show_def")


## Kuyruğun anlık durumunu (kimlik değişimi hariç) çizime uygular: konum kayması + alfa.
func apply_state(_q: ToastQueue) -> void:
	Stub.todo(&"AchievementToast.apply_state")
