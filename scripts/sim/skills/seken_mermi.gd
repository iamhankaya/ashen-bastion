extends SkillBehavior
## Her N. şarjör kurşunu seker: bounces eklenir, hasar çarpılır, RICOCHET bayrağı.

var _every_n: int = 3
var _bounces: int = 0
var _damage_mult: float = 1.0


func setup(_api: GameSim, def: SkillDef, level: int) -> void:
	var lv := def.level_data(level)
	_every_n = maxi(1, int(lv.get("every_n", 3)))
	_bounces = int(lv.get("bounces", 0))
	_damage_mult = float(lv.get("damage_mult", 1.0))


func modify_shot(ctx: ShotContext) -> void:
	if ctx.index_in_mag % _every_n != 0:
		return
	ctx.bounces += _bounces
	ctx.damage *= _damage_mult
	ctx.flags |= ProjectilePool.FLAG_RICOCHET
	ctx.tags.append("ricochet")
