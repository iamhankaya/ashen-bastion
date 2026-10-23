extends SkillBehavior
## Şarjörsüz: soğuma bitince en yakın düşmana yay atışla dinamit fırlatır; 0,8 sn fitil sonunda patlar.
## Dinamit düşmana çarpmaz (FLAG_LOB), ömrü bitince patlar (FLAG_EXPLODE_ON_EXPIRE).

const FUSE := 0.8
const RANGE := 560.0
const SCATTER := 70.0

var _cooldown: float = 3.5
var _count: int = 1
var _damage: float = 60.0
var _radius: float = 130.0
var _cd: float = 0.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_cooldown = float(lv.get("cooldown", _cooldown))
	_count = int(lv.get("count", _count))
	_damage = float(lv.get("damage", _damage))
	_radius = float(lv.get("radius", _radius))


func tick(dt: float) -> void:
	_cd -= dt
	if _cd > 0.0:
		return
	var sim := api()
	if sim == null:
		return
	var target := Targeting.pick(0, sim.player_pos, RANGE, sim.enemies, sim.grid, -1)
	if target < 0:
		_cd = 0.0
		return
	var tp := sim.enemies.pos[EnemyPool.index_of(target)]
	for k in _count:
		var land := tp
		if k > 0:
			land += (
				Vector2.from_angle(TAU * sim.rng_combat.randf())
				* (SCATTER * sim.rng_combat.randf())
			)
		(
			sim
			. spawn_projectile(
				sim.player_pos,
				(land - sim.player_pos) / FUSE,
				_damage,
				{
					"life": FUSE,
					"flags": ProjectilePool.FLAG_LOB | ProjectilePool.FLAG_EXPLODE_ON_EXPIRE,
					"ex_radius": _radius,
					"ex_dmg": _damage,
				}
			)
		)
	_cd = _cooldown / sim.stats.fire_rate_mult
