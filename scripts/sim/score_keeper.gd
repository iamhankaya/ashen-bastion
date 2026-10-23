class_name ScoreKeeper
extends RefCounted
## Skor bileşenleri, SERİ durumu, bonuslar. UI bilmez. Tüm kurallar tam sayı ADIM (SERİ penceresi 180 adım).
## İskelet (S2): alanlar, total ve parts gerçek; kurallar D3-1'de dolar. `armed` iskelette hep false: v1 davranışı
## korunur (boşta Stub.todo kaydı oluşmaz). D3-1 `_init`te `armed = true` yapar ve bu korumaları kaldırır.

## GameSim bus'a çevirir: score_changed(total, mult, gain).
signal gained(gain: int, source: StringName)
signal streak_changed(mult: int, left: float)

const WINDOW_STEPS := 180

var kills_part: int = 0
var streak_part: int = 0
var evolution_part: int = 0
var survival_part: int = 0
var lord_part: int = 0
var streak_count: int = 0
var mult: int = 1
var best_mult: int = 1
var last_kill_step: int = 0
var armed: bool = false

var _table: ScoreTable = null


func _init(table: ScoreTable) -> void:
	_table = table


@warning_ignore_start("unused_parameter")


## Çarpanlı kazancı döndürür.
func on_kill(type_id: StringName, step: int) -> int:
	if not armed:
		return 0
	Stub.todo(&"ScoreKeeper.on_kill")
	return 0


func on_evolution() -> int:
	if not armed:
		return 0
	Stub.todo(&"ScoreKeeper.on_evolution")
	return 0


func on_lord() -> int:
	if not armed:
		return 0
	Stub.todo(&"ScoreKeeper.on_lord")
	return 0


## Temas hasarı: sayaç 0, çarpan 1.
func break_streak(step: int) -> void:
	if not armed:
		return
	Stub.todo(&"ScoreKeeper.break_streak")


## Pencere dolumu + survival_part (her adım _phase_status başında).
func tick(step: int) -> void:
	if not armed:
		return
	Stub.todo(&"ScoreKeeper.tick")


func total() -> int:
	return kills_part + streak_part + evolution_part + survival_part + lord_part


## Pencerede kalan süre (sn, 0..3).
func streak_left(step: int) -> float:
	if not armed:
		return 0.0
	Stub.todo(&"ScoreKeeper.streak_left")
	return 0.0


## {"kills","streak","evolution","survival","lord"}
func parts() -> Dictionary:
	return {
		"kills": kills_part,
		"streak": streak_part,
		"evolution": evolution_part,
		"survival": survival_part,
		"lord": lord_part,
	}
