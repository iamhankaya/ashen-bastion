class_name ScoreBlock
extends Control
## HUD skor sütunu (sağ 36, üst 284): "SKOR" etiketi, değer (Cinzel 60), SERİ çipi ve kazanç başlığı. Oyun kuralı yok; sim'i okur.
## İskelet (S3): gizli doğar; gizliyken bind/refresh no-op'tur (v1 HUD davranışı korunur), görünürken Stub.todo kaydı
## oluşturur. D3-3 gövdeleri doldurur ve `bind` içinde görünür yapar.


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


@warning_ignore_start("unused_parameter")


func bind(sim: GameSim) -> void:
	if not visible:
		return
	Stub.todo(&"ScoreBlock.bind")


func refresh(dt: float) -> void:
	if not visible:
		return
	Stub.todo(&"ScoreBlock.refresh")


## Gösterilen değer hedefe 180 ms'de yaklaşır.
static func eased(shown: float, target: int, dt: float) -> float:
	Stub.todo(&"ScoreBlock.eased")
	return float(target)


## gain >= 50 ve son pop'tan >= 0,3 sn.
static func should_pop(gain: int, since_last_pop: float) -> bool:
	Stub.todo(&"ScoreBlock.should_pop")
	return false


## gain >= 400.
static func is_big_gain(gain: int) -> bool:
	Stub.todo(&"ScoreBlock.is_big_gain")
	return false


## 0 gizli (x1), 1 x2, 2 x3-x4, 3 x5.
static func tier_of(mult: int) -> int:
	Stub.todo(&"ScoreBlock.tier_of")
	return 0


## UiKit.format_thousands; en çok 99.999.999.
static func format_score(n: int) -> String:
	Stub.todo(&"ScoreBlock.format_score")
	return ""
