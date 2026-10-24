extends SkillBehavior
## Hava Bıçakları: şarjörsüz; soğuma bitince menzildeki (380) en yakın düşmana yönelik 0,70 rad'lık simetrik yelpazede
## `pellets` kesik (hilal, FLAG_WIND) atar; her biri `pierce` ek düşmanı deler.
## Beklenen davranış: docs/design/v2.0.2/behavior-contract.md; sayılar data/skills/hava_bicaklari.json.

const RANGE := 380.0
const SPREAD := 0.7
const BLADE_RADIUS := 10.0

var _cooldown: float = 3.4
var _pellets: int = 3
var _damage: float = 10.0
var _pierce: int = 1
var _cd: float = 0.0


func setup(api: GameSim, def: SkillDef, level: int) -> void:
	_bind(api)
	var lv := def.level_data(level) if def != null else {}
	_cooldown = float(lv.get("cooldown", _cooldown))
	_pellets = int(lv.get("pellets", _pellets))
	_damage = float(lv.get("damage", _damage))
	_pierce = int(lv.get("pierce", _pierce))


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
	var tpos := sim.enemies.pos[EnemyPool.index_of(target)]
	var origin := WindUtil.skill_origin(sim, tpos - sim.player_pos)
	var aim := (tpos - origin).angle()
	var dmg := _damage * sim.stats.bullet_dmg_mult
	for k in _pellets:
		var f := 0.0 if _pellets <= 1 else float(k) / float(_pellets - 1) - 0.5
		WindUtil.crescent(
			sim,
			origin,
			Vector2.from_angle(aim + f * SPREAD),
			dmg,
			RANGE,
			{"pierce": _pierce, "radius": BLADE_RADIUS}
		)
	sim.fx.volley_fired.emit(origin, _pellets)
	_cd = _cooldown / sim.stats.fire_rate_mult
