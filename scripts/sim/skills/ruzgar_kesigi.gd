extends SkillBehavior
## Rüzgar Kesiği (Zyfen temel saldırısı): şarjörden çıkan her kurşun hilal biçimli, düşmanları delip geçen bir kesik olur.
## Sim temel silah akışını yürütür (cift_tabanca gibi seviye değerlerini verir); bu davranış yalnız mermiyi değiştirir.
## modify_shot yalnız artırır/bayrak ekler (diğer beceriler ekleme sırasından bağımsız birleşir), kısma on_hit'tedir.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/ruzgar_kesigi.json.


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	var lv := def.level_data(level)
	api.gun_damage = float(lv.get("damage", api.gun_damage))
	api.gun_interval = float(lv.get("interval", api.gun_interval))


func modify_shot(ctx: ShotContext) -> void:
	ctx.pierce = maxi(ctx.pierce, ProjectilePool.PIERCE_ALL)
	ctx.flags |= ProjectilePool.FLAG_WIND
	ctx.radius = maxf(ctx.radius, WindUtil.CRESCENT_RADIUS)
