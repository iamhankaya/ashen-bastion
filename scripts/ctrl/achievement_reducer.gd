class_name AchievementReducer
extends RefCounted
## Başarım metriği kod eklentisi taban sınıfı (sözleşme-B iskeleti; keşif ve tracker bağlantısı R8). Yalnız yerleşik toplamla
## (sum|max|count) ifade edilemeyen metrikler için: yeni alt sınıf DOSYASI eklenir, mevcut dosya değişmez. Taban: hiçbir şey yapmaz.


## Sim olayı geldiğinde (SimEvents türü). `state` reducer'a ait koşu içi durumdur.
func on_event(_ev: StringName, _payload: Dictionary, _state: Dictionary) -> void:
	pass


## Durumlu koşullar için her tick ya da aralıkla.
func poll(_sim: GameSim, _state: Dictionary) -> void:
	pass


## Koşu sonu değeri.
func finish(_result: Dictionary, _state: Dictionary) -> int:
	return 0


func reset(_state: Dictionary) -> void:
	pass
