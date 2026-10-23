class_name HighscoreScreen
extends Control
## En İyi Skorlar ekranı (DESIGN §3.5): en çok 10 satır, boş durum, GERİ ve OYNA. Kural yok; Highscores girişlerini gösterir.
## İskelet (S3): gizli doğar. D3-5 doldurur.

signal back_requested
signal play_requested


func _init() -> void:
	visible = false


@warning_ignore_start("unused_parameter")


## highlight_index: vurgulanacak satır (-1 = yok; denetleyici v1.1'de hep -1 verir).
func show_scores(entries: Array[Dictionary], highlight_index: int = -1) -> void:
	Stub.todo(&"HighscoreScreen.show_scores")


## Güvenli alan payı: Vector4(sol, üst, sağ, alt); null = UiKit.current_safe_extra.
func apply_safe_area(extra: Variant = null) -> void:
	Stub.todo(&"HighscoreScreen.apply_safe_area")
