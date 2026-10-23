class_name StatBlock
extends RefCounted
## Pasiflerden toplanan çarpanlar. Çarpan türü pasifler `1 + x` ile uygulanır, farklı pasifler toplanır.
## v1.1: süreli etki çarpanları (BuffManager) ETKİN alanlara katılır. `bullet_dmg_mult/explosion_dmg_mult/
## fire_rate_mult` = pasif TABAN × etki; böylece mevcut tüm tüketiciler değişmeden etkin değeri görür.

var bullet_dmg_mult: float = 1.0
var fire_rate_mult: float = 1.0
var reload_time_mult: float = 1.0
var mag_add: int = 0
var area_mult: float = 1.0
var explosion_dmg_mult: float = 1.0
var move_speed_mult: float = 1.0
var max_hp_add: float = 0.0
var regen: float = 0.0
var pickup_mult: float = 1.0
var range_mult: float = 1.0
## Süreli etki çarpanları (Öfke Barutu: hasar, Kızgın Namlu: atış hızı); etki yokken 1.
var buff_dmg_mult: float = 1.0
var buff_rate_mult: float = 1.0

# Pasiflerden gelen taban değerler (etki katılmadan).
var _base_bullet_dmg_mult: float = 1.0
var _base_fire_rate_mult: float = 1.0
var _base_explosion_dmg_mult: float = 1.0


func rebuild(loadout: Loadout, data: GameData) -> void:
	var s := {}
	for st in loadout.passives():
		var lv := st.def.level_data(st.level)
		for k in lv.keys():
			s[k] = float(s.get(k, 0.0)) + float(lv[k])
	_base_bullet_dmg_mult = 1.0 + float(s.get("bullet_dmg_mult", 0.0))
	_base_fire_rate_mult = 1.0 + float(s.get("fire_rate_mult", 0.0))
	reload_time_mult = 1.0 + float(s.get("reload_time_mult", 0.0))
	mag_add = int(s.get("mag_add", 0.0))
	area_mult = 1.0 + float(s.get("area_mult", 0.0))
	_base_explosion_dmg_mult = 1.0 + float(s.get("explosion_dmg_mult", 0.0))
	move_speed_mult = 1.0 + float(s.get("move_speed_mult", 0.0))
	max_hp_add = float(s.get("max_hp_add", 0.0))
	regen = float(s.get("regen", 0.0))
	pickup_mult = 1.0 + float(s.get("pickup_mult", 0.0))
	range_mult = 1.0 + float(s.get("range_mult", 0.0))
	_apply_buffs()


## Süreli etki çarpanlarını ayarlar (hasar hem mermiye hem patlamaya; hız atış hızına) ve etkin alanları yeniler.
func set_buffs(dmg: float, rate: float) -> void:
	buff_dmg_mult = dmg
	buff_rate_mult = rate
	_apply_buffs()


func _apply_buffs() -> void:
	bullet_dmg_mult = _base_bullet_dmg_mult * buff_dmg_mult
	explosion_dmg_mult = _base_explosion_dmg_mult * buff_dmg_mult
	fire_rate_mult = _base_fire_rate_mult * buff_rate_mult
