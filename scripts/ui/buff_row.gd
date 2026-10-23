class_name BuffRow
extends Control
## Süreli etki rozetleri (sol alt; en çok 3: Hasar, Hız, Sınırsız): rozet x = 231 + n·120, 108 px daire, yay + ikon + kalan sn.
## İskelet (S3): gizli doğar; gizliyken bind/refresh no-op'tur, görünürken Stub.todo kaydı oluşturur. D2-3 doldurur.


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


@warning_ignore_start("unused_parameter")


func bind(sim: GameSim) -> void:
	if not visible:
		return
	Stub.todo(&"BuffRow.bind")


func refresh(dt: float) -> void:
	if not visible:
		return
	Stub.todo(&"BuffRow.refresh")


## n. rozetin sol x'i: 231 + n × 120.
static func badge_x(n: int) -> float:
	Stub.todo(&"BuffRow.badge_x")
	return 0.0


## ceil(left_steps / 60) metni.
static func seconds_text(left_steps: int) -> String:
	Stub.todo(&"BuffRow.seconds_text")
	return ""


## Son 3 sn: rozet yanıp söner.
static func blinking(left_s: float) -> bool:
	Stub.todo(&"BuffRow.blinking")
	return false
