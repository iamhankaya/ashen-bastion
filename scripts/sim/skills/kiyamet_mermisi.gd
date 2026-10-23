extends SkillBehavior
## Evrim (son_mermi_patlar 5 + hizli_doldurma): son kurşun devasa patlar (400 / 260) ve 2 mermi geri yazılır.
## Geri yazma doldurma döngüsü başına bir kez (Magazine.refund_used; reload_finished'te sıfırlanır).

var _ex_damage: float = 400.0
var _ex_radius: float = 260.0
var _refund: int = 2


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_ex_damage = float(lv.get("ex_damage", _ex_damage))
	_ex_radius = float(lv.get("ex_radius", _ex_radius))
	_refund = int(lv.get("refund", _refund))


func on_last_bullet(ctx: ShotContext) -> void:
	ctx.flags |= ProjectilePool.FLAG_EXPLODES
	ctx.ex_radius = maxf(ctx.ex_radius, _ex_radius)
	ctx.ex_dmg = maxf(ctx.ex_dmg, _ex_damage)
	ctx.tags.append("doomsday")
	var sim := api()
	if sim == null or sim.magazine.refund_used:
		return
	sim.magazine.refund_used = true
	sim.magazine.refund(_refund)
	sim.log_event(SimEvents.REFUND, {"n": _refund})
