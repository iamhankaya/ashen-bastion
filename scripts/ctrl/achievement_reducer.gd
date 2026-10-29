class_name AchievementReducer
extends RefCounted
## Başarım metriği kod eklentisi taban sınıfı (R8). Yalnız yerleşik toplamla (sum|max|count) ifade edilemeyen metrikler için:
## `scripts/ctrl/achievement_reducers/` altına yeni alt sınıf DOSYASI eklenir ve metrik JSON'unda `reducer` olarak adlandırılır;
## mevcut dosya değişmez. Tracker her metrik için tek örnek ve bir `state` sözlüğü tutar: `value` (koşu değeri), `store`, `char_id`.
## Olay yolunda tahsis yok: `payload` tracker'ın yeniden kullandığı sözlüktür (etiket alanı + tamsayı alanları), saklanmaz.
## Taban: hiçbir şey yapmaz.


## Dinlenen bir SimBus olayı geldiğinde (metrikteki `events`); `ev` sinyal adı. `state["value"]`'yu günceller.
func on_event(_ev: StringName, _payload: Dictionary, _state: Dictionary) -> void:
	pass


## Durumlu koşullar için her poll'da (metrikte `poll: true`).
func poll(_sim: GameSim, _state: Dictionary) -> void:
	pass


## Koşu sonunda (metrikte `finish: true`). `result` {time, level, score, won, counts_chars5}. Dönüş < 0: bu koşuda değişiklik yok.
func finish(_result: Dictionary, _state: Dictionary) -> int:
	return 0


## Güncel değer (kademe denetimi bunu okur); varsayılan `state["value"]`.
func value(state: Dictionary) -> int:
	return int(state.get("value", 0))


func reset(_state: Dictionary) -> void:
	pass
