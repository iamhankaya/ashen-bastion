class_name FloatText
extends Control
## Kayan metin (toplama başlığı): 700 ms, 60 px yükselir, havuz 3. Metin `pickups.json.toast` + `UiKit.upper_tr`.
## İskelet (S3): gizli doğar; gizliyken refresh no-op'tur. D2-3 doldurur.


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


@warning_ignore_start("unused_parameter")


func show_text(text: String, world_to_screen_pos: Vector2) -> void:
	Stub.todo(&"FloatText.show_text")


func refresh(dt: float) -> void:
	if not visible:
		return
	Stub.todo(&"FloatText.refresh")
