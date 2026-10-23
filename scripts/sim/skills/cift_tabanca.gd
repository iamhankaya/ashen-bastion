extends SkillBehavior
## Temel silah: şarjörden çıkış ve atış aralığını sim yürütür; bu davranış seviye değerlerini sim'e verir.
## Aralık TABANCA BAŞINA; iki tabanca yarım aralık faz farkıyla sırayla ateş eder.


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	var lv := def.level_data(level)
	api.gun_damage = float(lv.get("damage", api.gun_damage))
	api.gun_interval = float(lv.get("interval", api.gun_interval))
