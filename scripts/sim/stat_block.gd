class_name StatBlock
extends RefCounted
## Pasiflerden toplanan çarpanlar. Çarpan türü pasifler `1 + x` ile uygulanır, farklı pasifler toplanır.

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


func rebuild(loadout: Loadout, data: GameData) -> void:
	Stub.todo(&"StatBlock.rebuild")
