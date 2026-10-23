extends SkillBehavior
## Şarjör ritmi: doldurma başlarken oyuncunun etrafına radyal kurşun salvosu.

const RANGE := 460.0

var _count: int = 8
var _damage: float = 10.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_count = int(lv.get("count", _count))
	_damage = float(lv.get("damage", _damage))


func on_reload_start() -> void:
	var sim := api()
	if sim == null:
		return
	SkillUtil.radial(
		sim,
		sim.player_pos,
		TAU * sim.rng_combat.randf(),
		_count,
		_damage * sim.stats.bullet_dmg_mult,
		RANGE,
		{"flags": ProjectilePool.FLAG_RADIAL}
	)
