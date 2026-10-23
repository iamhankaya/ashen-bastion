extends SkillBehavior
## Evrim (yelpaze_atis 5 + agir_kursun): 13 saçma, 2 delme, 160 px geri itme, soğuma 2,0 sn.

const RANGE := 380.0
const SPREAD := 1.2217  # 70°

var _cooldown: float = 2.0
var _pellets: int = 13
var _damage: float = 20.0
var _pierce: int = 2
var _push: float = 160.0
var _cd: float = 0.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_cooldown = float(lv.get("cooldown", _cooldown))
	_pellets = int(lv.get("pellets", _pellets))
	_damage = float(lv.get("damage", _damage))
	_pierce = int(lv.get("pierce", _pierce))
	_push = float(lv.get("push", _push))


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
		sim,
		sim.player_pos,
		aim,
		SPREAD,
		_pellets,
		_damage * sim.stats.bullet_dmg_mult,
		RANGE,
		{"pierce": _pierce, "push": _push}
	)
	_cd = _cooldown / sim.stats.fire_rate_mult
