class_name OffscreenArrow
extends Control
## Ekran dışı eklenti oku: oyuncuya en yakın canlı eklenti ekran dışındaysa kenarda 84 px yuvarlak ok (güvenli alan içinde,
## aynı anda ≤1). İskelet (S3): gizli doğar; gizliyken bind/refresh no-op'tur. D2-3 doldurur.


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


@warning_ignore_start("unused_parameter")


func bind(sim: GameSim) -> void:
	if not visible:
		return
	Stub.todo(&"OffscreenArrow.bind")


func refresh(dt: float) -> void:
	if not visible:
		return
	Stub.todo(&"OffscreenArrow.refresh")


## {"visible": bool, "pos": Vector2, "angle": float}: hedef ekrandaysa gizli; değilse güvenli dikdörtgenin kenarında.
static func place(
	target: Vector2, cam_pos: Vector2, view: Vector2, safe: Rect2, margin: float
) -> Dictionary:
	Stub.todo(&"OffscreenArrow.place")
	return {"visible": false, "pos": Vector2.ZERO, "angle": 0.0}
