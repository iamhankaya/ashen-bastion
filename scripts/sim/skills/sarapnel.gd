extends SkillBehavior
## Öldürmede şansla etrafa şarapnel parçaları saçar (menzil 260). Şarapnelle öldürülen düşman zincirleme saçmaz.

const RANGE := 260.0

var _chance: float = 0.25
var _pellets: int = 3
var _damage: float = 18.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_chance = float(lv.get("chance", _chance))
	_pellets = int(lv.get("pellets", _pellets))
	_damage = float(lv.get("damage", _damage))


func on_kill(_enemy_id: int, pos: Vector2) -> void:
	var sim := api()
	if sim == null or (sim.kill_source_flags & ProjectilePool.FLAG_SHRAPNEL) != 0:
		return
	if sim.rng_combat.randf() >= _chance:
		return
	SkillUtil.radial(
		sim,
		pos,
		TAU * sim.rng_combat.randf(),
		_pellets,
		_damage * sim.stats.bullet_dmg_mult,
		RANGE,
		{"flags": ProjectilePool.FLAG_SHRAPNEL}
	)
