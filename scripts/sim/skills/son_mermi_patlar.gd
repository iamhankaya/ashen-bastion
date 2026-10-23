extends SkillBehavior
## Şarjörün son kurşunu isabette patlar.

var _ex_damage: float = 0.0
var _ex_radius: float = 0.0


func setup(_api: GameSim, def: SkillDef, level: int) -> void:
	var lv := def.level_data(level)
	_ex_damage = float(lv.get("ex_damage", 0.0))
	_ex_radius = float(lv.get("ex_radius", 0.0))


func on_last_bullet(ctx: ShotContext) -> void:
	ctx.flags |= ProjectilePool.FLAG_EXPLODES
	ctx.ex_radius = maxf(ctx.ex_radius, _ex_radius)
	ctx.ex_dmg = maxf(ctx.ex_dmg, _ex_damage)
	ctx.tags.append("last_bullet_explodes")
