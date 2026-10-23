extends SkillBehavior
## Şarjörsüz saçma atışı: soğuma bitince menzildeki en yakın düşmana 50°'lik yelpazede saçma atar (menzil 380).

const RANGE := 380.0
const SPREAD := 0.8727  # 50°

var _cooldown: float = 4.0
var _pellets: int = 5
var _damage: float = 9.0
var _cd: float = 0.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_cooldown = float(lv.get("cooldown", _cooldown))
	_pellets = int(lv.get("pellets", _pellets))
	_damage = float(lv.get("damage", _damage))


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
	var aim := (sim.enemies.pos[EnemyPool.index_of(target)] - sim.player_pos).angle()
	SkillUtil.fan(
		sim, sim.player_pos, aim, SPREAD, _pellets, _damage * sim.stats.bullet_dmg_mult, RANGE
	)
	_cd = _cooldown / sim.stats.fire_rate_mult
