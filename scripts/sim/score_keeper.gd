class_name ScoreKeeper
extends RefCounted
## Skor bileşenleri, SERİ durumu, bonuslar. UI bilmez. Tüm kurallar tam sayı ADIM (SERİ penceresi 180 adım).
## Sıra sözleşmesi: öldürme kazancı yeni çarpanla hesaplanır (10. öldürme x2); temas hasarı seriyi hasar anında bozar,
## aynı adımda hasardan ÖNCE işlenen öldürmeler eski çarpanla puanlanır (faz sırası GameSim'dedir).

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
## false: tüm kurallar no-op (testler için kapatılabilir). Normal oyunda hep true.
var armed: bool = true
## Son seri sıfırlanmasının nedeni (&"window" | &"damage"); SimEvents.STREAK_RESET için.
var last_reset_reason: StringName = &""

var _table: ScoreTable = null


func _init(table: ScoreTable) -> void:
	_table = table


## Çarpanlı kazancı döndürür.
func on_kill(type_id: StringName, step: int) -> int:
	if not armed:
		return 0
	_expire(step)
	streak_count += 1
	var new_mult := _table.mult_for(streak_count)
	var base := _table.points(type_id)
	var gain := base * new_mult
	kills_part += base
	streak_part += base * (new_mult - 1)
	last_kill_step = step
	if new_mult != mult:
		mult = new_mult
		best_mult = maxi(best_mult, mult)
		streak_changed.emit(mult, float(_table.window_steps) / float(ScoreTable.STEPS_PER_SEC))
	if gain > 0:
		gained.emit(gain, &"kill")
	return gain


func on_evolution() -> int:
	if not armed:
		return 0
	var gain := _table.evolution_bonus
	evolution_part += gain
	if gain > 0:
		gained.emit(gain, &"evolution")
	return gain


func on_lord() -> int:
	if not armed:
		return 0
	var gain := _table.lord_bonus
	lord_part += gain
	if gain > 0:
		gained.emit(gain, &"lord")
	return gain


## Temas hasarı: sayaç 0, çarpan 1.
@warning_ignore("unused_parameter")
func break_streak(step: int) -> void:
	if not armed:
		return
	_reset(&"damage")


## Pencere dolumu + survival_part (her adım _phase_status başında). Hayatta kalma kazanç yayınlamaz.
func tick(step: int) -> void:
	if not armed:
		return
	survival_part = step * _table.survival_per_sec / ScoreTable.STEPS_PER_SEC
	_expire(step)


func total() -> int:
	return kills_part + streak_part + evolution_part + survival_part + lord_part


## Pencerede kalan süre (sn, 0..3).
func streak_left(step: int) -> float:
	if not armed or streak_count == 0:
		return 0.0
	var left := _table.window_steps - (step - last_kill_step)
	return float(clampi(left, 0, _table.window_steps)) / float(ScoreTable.STEPS_PER_SEC)


## {"kills","streak","evolution","survival","lord"}
func parts() -> Dictionary:
	return {
		"kills": kills_part,
		"streak": streak_part,
		"evolution": evolution_part,
		"survival": survival_part,
		"lord": lord_part,
	}


func _expire(step: int) -> void:
	if streak_count > 0 and step - last_kill_step > _table.window_steps:
		_reset(&"window")


func _reset(reason: StringName) -> void:
	if streak_count == 0:
		return
	streak_count = 0
	mult = 1
	last_reset_reason = reason
	streak_changed.emit(1, 0.0)
